# frozen_string_literal: true

require 'json'
require 'psych'

module NetomoxExp
  module Netoviz2
    # Diagram profile files (YAML, written by a person) of a network, converted to JSON-compatible data.
    # The files are `<profiles_dir>/<network>/<name>.yaml` (or .yml). Only the conversion is done here:
    # the meaning of the profiles is checked by netoviz2.
    class ProfileFiles
      # Max size of a profile file (a bigger file is reported as an error)
      MAX_FILE_SIZE = 1024 * 1024
      # Profile file name (without extension): the names are used in URL queries and never as paths
      NAME_PATTERN = /\A[A-Za-z0-9_][A-Za-z0-9_.-]*\z/
      EXTENSIONS = %w[.yaml .yml].freeze
      # Max depth of a document (the response wraps it in 4 more levels: the JSON limit of the response is 100)
      MAX_DEPTH = 64

      # Error of a profile file
      class FileError < StandardError; end

      # @param [String] profiles_dir Directory of the profiles (MDDO_PROFILES_DIR)
      def initialize(profiles_dir)
        @profiles_dir = profiles_dir
      end

      # @param [String] network Network name
      # @return [Array<Hash>] profile files in the order of the names:
      #   `{ name:, etag:, documents: [...] }` or `{ name:, etag:, documents: [], error: '...' }` (invalid file)
      def list(network)
        dir = network_dir(network)
        return [] unless dir && File.directory?(dir) && !File.symlink?(dir)

        profile_paths(dir).map { |name, path| read_file(name, path) }
      end

      private

      # @return [String, nil] directory of the network (nil if the name is not a name of a directory)
      def network_dir(network)
        return nil if network.nil? || network.empty? || network.include?("\0") || network.include?('/')
        return nil if ['.', '..'].include?(network)

        File.join(@profiles_dir, network)
      end

      # @return [Array<Array(String, String)>] [name, path] of the files, sorted by the name
      #   (if both `a.yaml` and `a.yml` exist, `a.yaml` is used)
      def profile_paths(dir)
        by_name = {}
        Dir.children(dir).sort.each do |entry|
          name = profile_name(entry)
          path = File.join(dir, entry)
          next unless name && File.file?(path) && !File.symlink?(path)

          by_name[name] ||= path # `.yaml` is sorted before `.yml`
        end
        by_name.sort_by { |name, _path| name }
      end

      # @return [String, nil] name of the profile (nil if the entry is not a profile file name)
      def profile_name(entry)
        ext = File.extname(entry)
        name = File.basename(entry, ext)
        name if EXTENSIONS.include?(ext) && NAME_PATTERN.match?(name)
      end

      def read_file(name, path)
        stat = File.stat(path)
        etag = "#{(stat.mtime.to_i * 1_000_000_000) + stat.mtime.nsec}-#{stat.size}"
        { name:, etag:, documents: documents_of(path, stat.size) }
      rescue FileError, Psych::Exception, SystemCallError, EncodingError => e
        { name:, etag: etag || '', documents: [], error: e.message }
      end

      # @return [Array<Object>] documents (YAML `---` separated; empty documents are removed)
      # @raise [FileError, Psych::Exception] if the file is too large or cannot be converted to JSON
      def documents_of(path, size)
        raise FileError, "file is too large (#{size} bytes, max #{MAX_FILE_SIZE})" if size > MAX_FILE_SIZE

        stream = Psych.parse_stream(File.read(path, encoding: 'UTF-8'), filename: File.basename(path))
        stream.children.each_with_index.filter_map do |node, i|
          document = document_value(node)
          document unless document.nil?
        rescue FileError, Psych::Exception => e
          raise FileError, "document ##{i + 1}: #{e.message}"
        end
      end

      # @return [Object] value of the document (JSON-compatible)
      # @raise [FileError, Psych::Exception] if the document cannot be expressed in JSON
      def document_value(document_node)
        check_nodes(document_node)
        value = safe_value(document_node)
        check_json_compatible(value)
        JSON.generate(value, max_nesting: MAX_DEPTH) # NaN, invalid strings, nesting
        value
      rescue JSON::JSONError => e
        raise FileError, "cannot be converted to JSON: #{e.message}"
      end

      # Anchors, aliases and tags are not used (JSON cannot express them). It also limits the depth, before the
      # conversion which recurses (it is not done iteratively, to be safe for deep documents)
      def check_nodes(document_node)
        stack = [[document_node, 0]]
        until stack.empty?
          node, depth = stack.pop
          raise FileError, "nesting is too deep (max #{MAX_DEPTH})" if depth > MAX_DEPTH

          check_node(node)
          node.children&.each { |child| stack.push([child, depth + 1]) }
        end
      end

      def check_node(node)
        raise FileError, 'aliases are not allowed' if node.is_a?(Psych::Nodes::Alias)
        return unless node.respond_to?(:anchor)

        raise FileError, "anchor '&#{node.anchor}' is not allowed" if node.anchor
        raise FileError, "tag '#{node.tag}' is not allowed" if node.tag
      end

      # Convert a document without aliases and without the classes other than the JSON ones (safe)
      def safe_value(document_node)
        stream = Psych::Nodes::Stream.new
        stream.children << document_node
        Psych.safe_load(stream.to_yaml, aliases: false)
      end

      # JSON object keys are strings (YAML allows other keys, e.g. numbers)
      def check_json_compatible(value, path = 'document')
        case value
        when Hash
          value.each do |key, child|
            raise FileError, "#{path}: key #{key.inspect} is not a string" unless key.is_a?(String)

            check_json_compatible(child, "#{path}.#{key}")
          end
        when Array
          value.each_with_index { |child, i| check_json_compatible(child, "#{path}[#{i}]") }
        end
      end
    end
  end
end
