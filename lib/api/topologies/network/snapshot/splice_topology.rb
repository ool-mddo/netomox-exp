# frozen_string_literal: true

require 'grape'
require 'lib/splice_topology/topology_splicer'

module NetomoxExp
  module ApiRoute
    # namespace /splice_topology
    class SpliceTopology < Grape::API
      resource 'splice_topology' do
        desc 'Post external bgp topology data and splice it to (internal) topology data'
        params do
          requires :ext_topology_data, type: Hash, desc: 'External topology data to splice'
        end
        post do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          ext_topology = params[:ext_topology_data]
          int_topology = read_topology_file(network, snapshot)
          splicer = TopologySplicer.new(int_topology, ext_topology)
          splicer.splice!

          # response (spliced topology data: RFC8345 Hash)
          splicer.to_data
        end
      end
    end
  end
end
