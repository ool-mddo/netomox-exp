# frozen_string_literal: true

require 'app'

RSpec.describe 'usecases API' do
  include ApiHelper

  before { prepare_dirs }

  it 'GET /usecases/:uc/:nw/:ss/topology returns the blueprint topology' do
    get '/usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology'
    expect(last_response.status).to eq 200
    expected = JSON.parse(File.read(FixtureHelper.path('usecases', 'refocus_topology', 'mddo-fw',
                                                       'original_asis_blueprint', 'topology.json')))
    expect(json_body).to eq expected
  end

  it 'GET blueprint topology returns 404 if it does not exist' do
    get '/usecases/refocus_topology/mddo-fw/no_such_snapshot/topology'
    expect(last_response.status).to eq 404
  end

  it 'GET /usecases/:uc/:nw/params returns params.yaml as json' do
    get '/usecases/refocus_topology/mddo-fw/params'
    expect(last_response.status).to eq 200
    expect(json_body.keys).to include('cluster_firewall_pairs', 'containerlab_nodes')
    expect(json_body['containerlab_nodes']['site-a-fw-1']['kind']).to eq 'linux'
  end

  it 'GET params/l3_preallocated_resources returns 400 if it is not defined in the params' do
    get '/usecases/refocus_topology/mddo-fw/params/l3_preallocated_resources'
    expect(last_response.status).to eq 400
  end

  it 'GET /usecases/:uc/:nw/flows/:file returns csv as json' do
    flows_dir = File.join(ApiHelper::USECASES_DIR, 'refocus_topology', 'mddo-fw', 'flows')
    FileUtils.mkdir_p(flows_dir)
    File.write(File.join(flows_dir, 'f.csv'), "source,dest,rate\n10.0.1.0/24,10.0.2.0/24,5\n")
    get '/usecases/refocus_topology/mddo-fw/flows/f'
    expect(last_response.status).to eq 200
    expect(json_body).to eq [{ 'source' => '10.0.1.0/24', 'dest' => '10.0.2.0/24', 'rate' => '5' }]
  end

  it 'GET unknown params returns 404' do
    get '/usecases/refocus_topology/mddo-fw/no_such_params'
    expect(last_response.status).to eq 404
  end
end
