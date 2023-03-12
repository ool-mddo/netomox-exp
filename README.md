# netomox-exp

Backend api to operate topology data. (original: https://github.com/corestate55/netomox-examples)

## Directories

```text
+ netomox-exp/         # https://github.com/ool-mddo/netomox-exp (THIS repository)
  + doc/               # class documents (generated w/yard)
  + exe/               # executable scripts
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

### Operate topology dat

Delete all topology data in a network

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

* POST `/topologies/<network>/<snapshot>`
  * `topology_data`: RFC8345 topology data

```shell
# topology.json
# -> { "topology_data": <RFC8345 topology data> }
curl -X POST -H "Content-Type: application/json" -d @topology.json \
  http://localhost:9292/topologies/pushed_configs/mddo_network
```

Fetch topology data

* GET `/topologies/<network>/<snapshot>`

```shell
curl http://localhost:9292/topologies/pushed_configs/mddo_network
```

## Tools

### Check/Make L1 interface description

Check existence of interface description and it format is correct.

- `-f`, `--format` : specify output format (json/yaml, default: yaml)
- `-l`, `--level` : filter output items by its type (level: info/warning/error, default: info)

```text
bundle exec ruby exe/mddo_toolbox.rb check_l1_descr [options] <topology-file>
```

Make layer1 interface description from its topology.

- `-o`, `--output` : specify output file to save generated descriptions (CSV),
  default (without this option) : output STDOUT

```text
bundle exec ruby exe/mddo_toolbox.rb make_l1_descr [options] <topology-file>
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
