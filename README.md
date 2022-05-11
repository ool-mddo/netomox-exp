# netomox-exp

A trial of network model construction. (original: https://github.com/corestate55/netomox-examples)

## Directories

```text
+ netomox-exp/         # https://github.com/ool-mddo/netomox-exp (THIS repository)
  + configs/           # configuration files (batfish snapshots)
  + doc/               # class documents (generated w/yard)
  + exe/               # executable scripts
  + figs/              # design diagrams
  + model_defs/        # scripts to generate topology data
  + models/            # normalized network data (batfish query outputs)
  + netoviz_models/    # topology data for netoviz (scripts in model_defs outputs)
  + yang               # yang schema to validate topology data (TODO)
```

## Setup

### Requirements

- Ruby >2.7 (development under ruby/3.1 and bundler/2.3.4)

### Optional: Install ruby gems

It can work attaching netomox-exp container on localhost that doesn't have ruby environment.
Local installation of gems is needed to exec tools or develop scripts in your localhost directly.

```shell
# If you install gems into project local
# bundle config set --local path 'vendor/bundle'
bundle install
```

### Install docker/docker-compose

For ubuntu linux

```shell
apt install docker.io docker-compose
```

Optional: Add `docker` group to your group to allow use docker without sudo.

## Set environment variables

see. [Rakefile](./Rakefile), [.env](./.env) and [docker-compose.yml](./docker-compose.yml)

* `BATFISH_WRAPPER_HOST`: specify batfish-wrapper service (hostname)
* `MDDO_CONFIGS_DIR`: batfish snapshot directory (default: `./configs`). Tasks in the Rakefile assumes that `MDDO_CONFIGS_DIR` directory has these two directory:
    * [batfish-test-topology](https://github.com/corestate55/batfish-test-topology) (small network data for testing and debugging)
    * [pushed_configs](https://github.com/ool-mddo/pushed_configs) (project network)
* `MDDO_MODELS_DIR`: query result directory (default: `./models`)
* `MDDO_NETOVIZ_MODEL_DIR`: topology data directory (for netoviz; defualt: `./netoviz_model`)

Optional environment variables:

- Log level variable
  - `NETOMOX_LOG_LEVEL` (default `info`)
  - `TOPOLOGY_BUILDER_LOG_LEVEL` (default `info`)
- select a value from `fatal`, `error`, `warn`, `info` and `debug`

## Generate topology json from normalized network data

### Run containers

Up services with docker-compose.

```shell
docker-compose up
```

Service:

- [batfish](https://github.com/batfish/batfish)
- [batfish-wrapper](https://github.com/ool-mddo/batfish-wrapper)
  - Some rake tasks and [mddo_toolbox](exe/mddo_toolbox.rb) call its API (REST).
- [netoviz](https://github.com/corestate55/netoviz)

Exec data analysis and topology data generation tasks.

### Optional: Attach ruby environment

If you don't have ruby environment locally, exec all `bundle exec foo` commands below inside netomox-exp container.

```shell
docker-compose exec netomox-exp bash
```

### Perform all data generation steps at once

```text
bundle exec rake [NETWORK=<network-name>]
                 [OFF_NODE=<draw-off-node> [OFF_INTF_RE=<draw-off-link>]]
```

Arguments of the rake tasks (Environment Values):
* `NETWORK`: A target network name to analyze and data-generate
* `OFF_NODE`: A node name to draw-off
  * Without `OFF_INTF_RE`, it assumes node-down case (draw-off all links of the node)
  * e.g. `bundle exec rake OFF_NODE=regiona-ce01`
* `OFF_INTF_RE`: A regexp pattern to specify draw-off link(s) on the node (`OFF_NODE`)
  * default: `/.*/` (any links)
  * e.g. `bundle exec rake OFF_NODE=regiona-ce01 OFF_INTF_RE="ge-0/0/[45]"`

See details of task sequence `default` task in [Rakefile](./Rakefile).

### Optional: Step-by-step data generation (for debugging)

Generate draw-off/link-down snapshot patterns

```shell
bundle exec rake simulation_pattern
```

Generate normalized data (CSV) from batfish registered snapshots

```shell
bundle exec rake snapshot_to_model
```

Generate index file for netoviz

```shell
bundle exec rake netoviz_index
```

Generate topology data for netoviz

```shell
bundle exec rake netoviz_model
```

Generate diff data between original and simulated (draw-off/link-down) topology data

```shell
bundle exec rake netomox_diff
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

### Check disconnected network

For topology file with layer1 link-down snapshot.

Check disconnected network

- `-f`, `--format` : specify output format (json/yaml, default: yaml)

```text
bundle exec ruby exe/mddo_toolbox.rb get_subsets [options] <topology-file>
```

Compare origin topology.

- before: topology file from original snapshot (without link-down)
- after: topology file(s) with link-down snapshot(s)
  - it can specify multiple files with wildcard, e.g. `... compare orig.json target*.json`
- `-m`, `--min-score`: minimum score to filter result
- `-f`, `--format` : specify output format (json/yaml, default: yaml)

```text
bundle exec ruby exe/mddo_toolbox.rb compare_subseets [options] <before-topology-file> <after-topology-file(s)>
```

### Check reachability (traceroute)

Run reachability test.

- test-pattern-def: reachability test pattern definition
  - [traceroute_patterns.yaml](exe/traceroute_patterns.yaml)
- `-n`, `--network` : target network name (a test case runs for all snapshots in a network)
- `-s`, `--snapshot-re` : [optional] target snapshot name (limit snapshots matching the regexp)
- `-f`, `--format` : specify output format (yaml/json/csv, default: yaml; ignored with `-r` option)
- `-r`, `--run_test` : run test-unit for test-results
  (all test results are saved to each files automatically from network name: `-n`)
  - `<network-name>.test_summary.json`
  - `<network-name>.test_detail.json`
  - `<network-name>.test_summary.csv`

```text
bundle exec ruby exe/mddo_toolbox.rb test_reachability [options] <test-pattern-def>
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
