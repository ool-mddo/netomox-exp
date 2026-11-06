# frozen_string_literal: true

require 'app'

RSpec.describe 'netoviz2 profiles API' do
  include ApiHelper

  let(:path) { '/topologies/nw/netoviz2/profiles' }
  let(:nw_dir) { File.join(ApiHelper::PROFILES_DIR, 'nw') }

  def write_profile(file, text, dir: nw_dir)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, file), text)
  end

  before { prepare_dirs }

  it 'returns an empty list when the network has no profiles' do
    get path
    expect(last_response.status).to eq 200
    expect(json_body).to eq('network' => 'nw', 'profiles' => [])
  end

  it 'returns the documents of the profile files as JSON, in the order of the names' do
    write_profile('b.yaml', <<~YAML)
      view: physical
      target: { layer: layer1 }
      ---
      view: logical
      rules:
        - { select: '*', order: 1 }
    YAML
    write_profile('a.yml', "# comment only\n")
    get path
    expect(last_response.status).to eq 200
    profiles = json_body['profiles']
    expect(profiles.map { |p| p['name'] }).to eq %w[a b]
    expect(profiles[0]).to include('documents' => [])
    expect(profiles[0]).not_to have_key('error')
    expect(profiles[1]['documents']).to eq [
      { 'view' => 'physical', 'target' => { 'layer' => 'layer1' } },
      { 'view' => 'logical', 'rules' => [{ 'select' => '*', 'order' => 1 }] }
    ]
    expect(profiles[1]['etag']).to match(/\A\d+-\d+\z/)
  end

  it 'keeps the types of YAML (a quoted string stays a string)' do
    write_profile('t.yaml', <<~YAML)
      view: v
      rules:
        - { select: '*', pair: { by: index, primary: '01' } }
        - { order: 2, tier: 2x }
    YAML
    get path
    rules = json_body['profiles'][0]['documents'][0]['rules']
    expect(rules[0]['pair']['primary']).to eq '01'
    expect(rules[1]).to eq('order' => 2, 'tier' => '2x')
  end

  it 'reports a broken file as an error of the file only (the status is 200 and other files are returned)' do
    write_profile('broken.yaml', "view: [\n")
    write_profile('ok.yaml', "view: ok\n")
    get path
    expect(last_response.status).to eq 200
    broken, ok = json_body['profiles']
    expect(broken).to include('name' => 'broken', 'documents' => [])
    expect(broken['error']).to include('did not find expected')
    expect(ok['documents']).to eq [{ 'view' => 'ok' }]
  end

  it 'rejects what JSON cannot express (aliases, objects, non-string keys, dates, symbols)' do
    {
      'alias' => "a: &x [1]\nb: *x\n",
      'object' => "a: !ruby/object:Object {}\n",
      'key' => "1: x\n",
      'date' => "a: 2024-01-01\n",
      'symbol' => ":a: 1\n"
    }.each { |name, text| write_profile("#{name}.yaml", text) }
    get path
    expect(last_response.status).to eq 200
    json_body['profiles'].each do |profile|
      expect(profile['error']).to be_a(String), "#{profile['name']} should be an error"
      expect(profile['documents']).to eq []
    end
    expect(json_body['profiles'].size).to eq 5
  end

  it 'reports a file which JSON cannot express as an error of the file only (the others are returned)' do
    {
      'nan' => "a: .nan\n",
      'inf' => "a: -.inf\n",
      'binary' => "a: !!binary /w==\n",
      'tag' => "a: !foo bar\n",
      'strtag' => "a: !!str 01\n",
      'anchor' => "a: &x 1\n",
      'deep' => "#{'[' * 1000}#{']' * 1000}\n",
      'toodeep' => "a: #{'[' * 70}#{']' * 70}\n"
    }.each { |name, text| write_profile("#{name}.yaml", text) }
    write_profile('zok.yaml', "view: ok\n")
    get path
    expect(last_response.status).to eq 200
    by_name = json_body['profiles'].to_h { |p| [p['name'], p] }
    (by_name.keys - ['zok']).each do |name|
      expect(by_name[name]['error']).to be_a(String), "#{name} should be an error"
      expect(by_name[name]['documents']).to eq []
    end
    expect(by_name['zok']['documents']).to eq [{ 'view' => 'ok' }]
    expect(by_name['tag']['error']).to include("tag '!foo'")
    expect(by_name['anchor']['error']).to include('anchor')
    expect(by_name['deep']['error']).to include('too deep')
  end

  it 'tells the file and the document of an error' do
    write_profile('e.yaml', "view: ok\n---\na: !foo b\n")
    write_profile('s.yaml', "view: [\n")
    get path
    errors = json_body['profiles'].to_h { |p| [p['name'], p['error']] }
    expect(errors['e']).to start_with('document #2:')
    expect(errors['s']).to include('s.yaml')
  end

  it 'accepts a document of the maximum depth' do
    write_profile('ok.yaml', "a: #{'[' * 60}#{']' * 60}\n")
    get path
    expect(json_body['profiles'][0]).not_to have_key('error')
  end

  it 'ignores a symbolic link of a file, and does not follow a symbolic link of the network directory' do
    write_profile('real.yaml', "view: real\n", dir: File.join(ApiHelper::PROFILES_DIR, 'real_nw'))
    FileUtils.mkdir_p(nw_dir)
    File.symlink(File.join(ApiHelper::PROFILES_DIR, 'real_nw', 'real.yaml'), File.join(nw_dir, 'link.yaml'))
    File.symlink(File.join(ApiHelper::PROFILES_DIR, 'real_nw'), File.join(ApiHelper::PROFILES_DIR, 'lnk'))
    get path
    expect(json_body['profiles']).to eq []
    get '/topologies/lnk/netoviz2/profiles'
    expect(json_body['profiles']).to eq []
  end

  it 'reports a file which is too large' do
    write_profile('big.yaml', "view: v\n# #{'x' * NetomoxExp::Netoviz2::ProfileFiles::MAX_FILE_SIZE}\n")
    get path
    expect(json_body['profiles'][0]['error']).to include('too large')
  end

  it 'returns only the profiles of the network, and only the files with a valid name and extension' do
    write_profile('ok.yaml', "view: ok\n")
    write_profile('other.yaml', "view: other\n", dir: File.join(ApiHelper::PROFILES_DIR, 'other'))
    write_profile('note.txt', "view: x\n")
    write_profile('.hidden.yaml', "view: x\n")
    write_profile('sp ace.yaml', "view: x\n")
    FileUtils.mkdir_p(File.join(nw_dir, 'dir.yaml'))
    get path
    expect(json_body['profiles'].map { |p| p['name'] }).to eq ['ok']
  end

  it 'uses a.yaml when both a.yaml and a.yml exist' do
    write_profile('a.yml', "view: yml\n")
    write_profile('a.yaml', "view: yaml\n")
    get path
    expect(json_body['profiles'].map { |p| p['documents'] }).to eq [[{ 'view' => 'yaml' }]]
  end

  it 'does not read outside of the profiles directory by the network name' do
    write_profile('secret.yaml', "view: secret\n", dir: File.join(ApiHelper::PROFILES_DIR, '..', 'outside'))
    write_profile('top.yaml', "view: secret\n", dir: ApiHelper::PROFILES_DIR)
    ['%2E%2E', '..%2Foutside', 'nw%2F..%2F..%2Foutside', '.'].each do |network|
      get "/topologies/#{network}/netoviz2/profiles"
      expect(last_response.body).not_to include('secret'), network
    end
    get '/topologies/%2E%2E/netoviz2/profiles' # reaches the code: the name is not a directory name
    expect(last_response.status).to eq 200
    expect(json_body['profiles']).to eq []
  end

  it 'does not take a network name which is not a directory name (unit)' do
    files = NetomoxExp::Netoviz2::ProfileFiles.new(ApiHelper::PROFILES_DIR)
    ['..', '.', '', 'a/b', "a\0"].each { |network| expect(files.list(network)).to eq [] }
  end

  it 'does not take netoviz2 as a snapshot name (the other API is not affected)' do
    get path
    expect(json_body).to have_key('profiles')
    get '/topologies/nw/ss/netoviz2/summary'
    expect(last_response.status).to eq 404 # no topology: the route is the one of the snapshot
  end
end
