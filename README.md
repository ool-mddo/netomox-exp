# netomox-exp

Backend api to operate topology data. (original: https://github.com/corestate55/netomox-examples)

## Directories

```text
+ netomox-exp/         # https://github.com/ool-mddo/netomox-exp (THIS repository)
  + doc/               # class documents (generated w/yard)
  + figs/              # design diagrams
  + model_defs/        # scripts to generate topology data
  + yang/              # yang schema to validate topology data (TODO)
```

## Setup

### Requirements

- Ruby >3.1.0 (development under ruby/3.1.0 and bundler/2.3.5)

### Optional: Install ruby gems

```shell
# If you install gems into project local
# bundle config set --local path 'vendor/bundle'
bundle install
```

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

## REST API

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

Convert specified layer topology to layer1_topology.json for batfish

* GET `/topologies/<network>/<snapshot>/topology/<layer>/batfish_layer1_topology`
  * NOTE: Namespace are converted (Initialize convert table at first)

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/batfish_layer1_topology
```

Convert specified layer topology to clab-topo.yaml for container-lab

* GET `/topologies/<network>/<snapshot>/topology/<layer>/containerlab_topology`
  * NOTE: Namespace are converted (Initialize convert table at first)
  * NOTE: It returns json data. Convert it to yaml using other tool

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/containerlab_topology \
  | ruby -r json -r yaml -e "puts YAML.dump_stream(JSON.parse(STDIN.read))"
```

Fetch all nodes and its attributes with namespace-converted names in a layer of the topology data

* GET `/topologies/<network>/<snapshot>/topology/<layer>/nodes`
  * NOTE: Namespace are converted (Initialize convert table at first)

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/nodes
```

Fetch all interfaces and its attributes with namespace-converted names in a layer of the topology data

* GET `/topologies/<network>/<snapshot>/topology/<layer>/interfaces`
  * NOTE: Namespace are converted (Initialize convert table at first)

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/interfaces
```

### L1 interface description check

Generate interface description from layer1

* GET `/topologies/<network>/<snapshot>/topology/<layer>/interface_description`

```shell
curl -s http://localhost:15000/topologies/mddo-ospf/original_asis/topology/layer1/interface_description
```

Fetch check results of interface description in layer1

* GET `/topologies/<network>/<snapshot>/topology/<layer>/interface_description/check`

```shell
curl -s http://localhost:15000/topologies/mddo-ospf/original_asis/topology/layer1/interface_description/check
```

## Development

### Optional: Build netomox container

```shell
docker build -t netomox-exp .
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
