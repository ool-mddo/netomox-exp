# netomox-exp

Backend api to operate topology data. (original: https://github.com/corestate55/netomox-examples)

## Directories

```text
+ netomox-exp/         # https://github.com/ool-mddo/netomox-exp (THIS repository)
  + doc/               # class documents (generated w/yard)
  + figs/              # design diagrams
  + lib/               # REST API body
  + model_defs/        # scripts to generate topology data (prototype)
  + yang/              # yang schema to validate topology data (TODO)
```

## Setup

### Requirements

- Ruby >3.1.0 (development under ruby/3.1.0 and bundler/2.3.5)

### Optional: Install ruby gems

netomox-exp uses [netomox](https://github.com/ool-mddo/netomox) gem that pushed on github packages.
So, it need authentication to exec `bundle install`.
One of method to set authentication credential of bundler is using `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` environment variable like below:

- `USERNAME` : your github username
- `TOKEN` : your github personal access token (need `read:packages` scope)

```shell
# authentication credential of github packages
export BUNDLE_RUBYGEMS__PKG__GITHUB__COM="USERNAME:TOKEN"

# If you install gems into project local
# bundle config set --local path 'vendor/bundle'
bundle install
```

see also: [Working with the RubyGems registry - GitHub Docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-rubygems-registry)

## Environment variables

Data directory:

* `MDDO_QUERIES_DIR`: query result directory (default: `./queries`)
* `MDDO_TOPOLOGIES_DIR`: topology data directory (for netoviz; default: `./topologies`)

Log level variable:

- `NETOMOX_LOG_LEVEL` (default `info`)
- `NETOMOX_EXP_LOG_LEVEL` (default `info`)
- select a value from `fatal`, `error`, `warn`, `info` and `debug`

## Run REST API server

```shell
bundle exec rackup -s webrick -o 0.0.0.0 -p 9292
```

For development: `rerun` watches file update and reload the server.

* `--force-polling` in container with volume mount

```shell
rerun [--force-polling] bundle exec rackup -s webrick -o 0.0.0.0 -p 9292
```

## REST API (`topologies` space)

### Operate netoviz

Save netoviz index

* POST `/topologies/index`
  * `index_data`: netoviz index data

```shell
# netoviz_index.json
# -> { "index_data": <netoviz index data> }
curl -X POST -H "Content-Type: application/json" -d @netoviz_index.json \
  http://localhost:9292/topologies/index
```

### Operate topology data

Delete all topology (and other network-related) data in a network

* DELETE `/topologies/<network>`

```shell
curl -X DELETE http://localhost:9292/topologies/pushed_configs
```

Fetch topology diff between two snapshots in a network

* GET `/topologies/<network>/snapshot_diff/<source_snapshot>/<destination_snapshot>`

```shell
curl http://localhost:9292/topologies/pushed_configs/snapshot_diff/mddo_network/mddo_network_linkdown_01
```

Save (register) topology data

* POST `/topologies/<network>/<snapshot>/topology`
  * `topology_data`: RFC8345 topology data

```shell
# topology.json
# -> { "topology_data": <RFC8345 topology data> }
curl -X POST -H "Content-Type: application/json" -d @topology.json \
  http://localhost:9292/topologies/pushed_configs/mddo_network/topology
```

Fetch topology data

* GET `/topologies/<network>/<snapshot>/topology`

```shell
curl http://localhost:9292/topologies/pushed_configs/mddo_network/topology
```

Fetch topology data (Upper layer3)

* GET `/topologies/<network>/<snapshot>/topology/upper_layer3`

```shell
curl http://localhost:9292/topologies/mddo-ospf/original_asis/topology/upper_layer3
```

### Operate namespace convert table

Delete namespace convert table of a network

* DELETE `/topologies/<network>/ns_convert_table`

```shell
curl -X DELETE http://localhost:9292/topologies/mddo-ospf
```

Create (initialize) or update namespace convert table of a network

* POST `/topologies/<network>/ns_convert_table`
  * `origin_snapshot`: snapshot name to create convert table (MUST be "original" env snapshot)
  * `convert_table`: convert table data to update (upload)

```shell
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"origin_snapshot": "original_asis"}' \
  http://localhost:9292/topologies/mddo-ospf/ns_convert_table
```

Fetch namespace convert table of a network

* GET `/topologies/<network>/ns_convert_table`

```shell
curl http://localhost:9292/topologies/mddo-ospf/ns_convert_table
```

Convert hostname using convert table

* POST `/topologies/<netowrk>/ns_convert_table/query`
  * `host_name` : host name to convert
  * `if_name` : [optional] interface name to convert 

```shell
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"host_name": "Seg_192.168.0.0/30", "if_name": "regiona-rt1_ge-0/0/0.0"}' \
  http://localhost:9292/topologies/mddo-ospf/ns_convert_table/query
```

### Convert topology namespace

Fetch namespace converted topology data

* GET `/topologies/<neetwork>/<snapshot>/converte_topology`
  * NOTE: initialize namespace convert table of the network before convert topology

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/original_asis/converted_topology
```

### Filter/Convert layer data of a topology data

NOTE: Namespace is converted (Initialize convert table at first before call below APIs)

Convert specified layer topology to layer1_topology.json for batfish

* GET `/topologies/<network>/<snapshot>/topology/<layer>/batfish_layer1_topology`

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/batfish_layer1_topology
```

Convert specified layer topology to clab-topo.yaml for container-lab

* GET `/topologies/<network>/<snapshot>/topology/<layer>/containerlab_topology`
  * NOTE: This API returns json data. Convert it to yaml for containerlab.
  * option for containerlab
    * `env_name`: containerlab environment name (default: "emulated")
  * options for router node (cRPD)
    * `image`: image name
    * `bind_license`: [optional] docker volume mount string to bind license file into a container
    * `license`: [optional] file path of license file
```shell
curl -s "http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/containerlab_topology?image=crpd:22.1R1.10&bind_license=license.key:/tmp/license.key:ro" \
  | ruby -r json -r yaml -e "puts YAML.dump_stream(JSON.parse(STDIN.read))"
```

Fetch a network, all networks by a network type (RFC8345-based json)

* GET `/topologies/<network>/<snapshot>/topology/<layer>`
* GET `/topologies/<network>/<snapshot>/topology/layer_type_<layer_type>`

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/ospf_area0
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer_type_ospf
```

Fetch all nodes and its attributes with namespace-converted names in a layer of the topology data
[NOTE]: NOT RFC8345 format, it returns simplified and including additional node-table info

* GET `/topologies/<network>/<snapshot>/topology/<layer>/nodes` (single layer)
* GET `/topologies/<network>/<snapshot>/topology/layer_type_<layer_type>/nodes` (multiple layers)
* option (node filter)
  * `node_type`: [optional] select specified type nodes (segment/node/endpoint)
  * `exc_node_type`: [optional] reject specified type nodes (segment/node/endpoint)
  * [NOTE] `node_type` and `exc_node_type` are mutually exclusive

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/ospf_area0/nodes
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer_type_ospf/nodes
```

Fetch all interfaces and its attributes with namespace-converted names in a layer of the topology data
[NOTE]: NOT RFC8345 format, it returns simplified and including additional node- and interface-table info

* GET `/topologies/<network>/<snapshot>/topology/<layer>/interfaces` (single layer)
* GET `/topologies/<network>/<snapshot>/topology/layer_type_<layer_type>/interfaces` (multiple layers)
* option (node filter)
  * `node_type`: [optional] select specified type nodes (segment/node/endpoint)
  * `exc_node_type`: [optional] reject specified type nodes (segment/node/endpoint)
  * [NOTE] `node_type` and `exc_node_type` are mutually exclusive

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/ospf_area0/interfaces
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer_type_ospf/interfaces
```

Fetch all nodes and interface parameters to generate CNF configurations

* GET `/topologies/<network>/<snapshot>/topology/<layer>/config_params`
  * `node_type`: [optional] select specified type nodes (segment/node/endpoint)
  * `exc_node_type`: [optional] reject specified type nodes (segment/node/endpoint)
  * [NOTE] `node_type` and `exc_node_type` are mutually exclusive

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/config_params
```

<details>
<summary>Response example:</summary>

```text
[
  {
    "name": "Seg_192.168.0.0/30",                 : node name (L3 model)
    "agent_name": "Seg-192.168.0.0-30",           : node name (L1 agent)
    "type": "segment",                            : node type from node attribute
    "if_list": [
      {
        "name": "regiona-rt1_eth1.0",             : interface name (L3 model)
        "agent_name": "Ethernet1",                : interface name (L1 agent)
        "ipv4": null,                             : IPv4 address from interface attribute
        "description": "to_regiona-rt1_eth1.0",   : Description from interface attribute
        "original_if": "regiona-rt1_ge-0/0/0.0"   : Description in original namespace (before namespace conversion)
      },
      {
        "name": "regiona-rt2_eth1.0",
        "agent_name": "Ethernet2",
        "ipv4": null,
        "description": "to_regiona-rt2_eth1.0",
        "original_if": "regiona-rt2_ge-0/0/0.0"
      }
    ]
  },
...
]
```

</details>

### Static Verification

Verify all layers or a layer according to its network-type.

* GET `/topologies/<network>/<snapshot>/topology/verify` : for all layers
* GET `/topologies/<network>/<snapshot>/topology/<layer>/verify` : for a layer
* option
  * `severity`: [optional] base severity (default: debug)

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/original_asis/topology/layer1/verify
```

## REST API (`usecases` space)

### Common

Fetch usecase params

* GET `/usecases/<usecase>/params`


### PNI usecase

Fetch flow data

* Get `/usecases/<usecase>/flow_data`

Generate external-AS topology data

* GET `/usecases/<usecase>/external_as_topology`
* option
  * `network`: Network name
  * `snapshot`: [optional] Snapshot name (default: 'original_asis')

```shell
curl -s http://localhost:9292/usecases/pni_te/external_as_topology?network=mddo-bgp
```

Generate iperf commands

* GET `/usecases/<usecase>/iperf_commands?network=mddo-bgp`
  * `network`: Network name
  * `snapshot`: Snapshot name

```shell
curl -s "http://localhost:9292/usecases/pni_te/iperf_commands?network=mddo-bgp&snapshot=emulated_asis"
```


## Development

### Optional: Build netomox container

netomox-exp uses [netomox](https://github.com/ool-mddo/netomox) gem that pushed on github packages.
So, it need authentication to exec `bundle install` when building its container image.
You have to pass authentication credential via `ghp_credential` environment variable like below:

- `USERNAME` : your github username
- `TOKEN` : your github personal access token (need `read:packages` scope)

```shell
ghp_credential="USERNAME:TOKEN" docker buildx build -t netomox-exp --secret id=ghp_credential .
```

### Generate YARD documents

YARD options are in `.yardopts` file.

```shell
bundle exec rake yard
```

Run yard document server (access `http://localhost:8808/` with browser)

```shell
bundle exec yard server
```

### Code analysis

```shell
bundle exec rake rubocop
# or
bundle exec rake rubocop:auto_correct
```
