

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
- Python 3.x (development under python/3.8.3 and pip/21.3.1)

### Update submodules

Pull network device configurations for experiments (at netomox-exp directory).

- [configs/batfish-test-topology](https://github.com/corestate55/batfish-test-topology)
- [configs/pushed_configs](https://github.com/ool-mddo/pushed_configs)

```shell
git submodule update --init --recursive
```

### Install ruby gems

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

## Generate topology json from normalized network data

Up services with docker-compose.

```shell
docker-compose up
```

Service:

- [batfish](https://github.com/batfish/batfish)
- [batfish-wrapper](https://github.com/ool-mddo/batfish-wrapper)
  - Some rake tasks and [mddo_boolbox](exe/mddo_toolbox.rb) call its API (REST).
- [netoviz](https://github.com/corestate55/netoviz)

Exec data analysis and topology data generation tasks.

```text
bundle exec rake [MODEL_NAME=<target model name>]
                 [OFF_NODE=<draw-off target node> [OFF_LINK_RE=<draw-off target link>]]
```

Arguments of the rake tasks (Environment Values):

* `MODEL_NAME`: target snapshot base
* `OFF_NODE` : A node name to draw-off
* `OFF_LINK_RE` : A regexp pattern to specify draw-off link(s) on the node (`OFF_NODE`), default: `/.*/` (any links)

See details of task sequence `default` task in [Rakefile](./Rakefile).

Optional environment variables:

- Log level variable
  - `NETOMOX_LOG_LEVEL` (default `info`)
  - `TOPOLOGY_BUILDER_LOG_LEVEL` (default `info`)
- select a value from `fatal`, `error`, `warn`, `info` and `debug`

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
- `-f`, `--format` : specify output format (yaml/json/csv, default: yaml)
  - ignored with `-r` option
- `-r`, `--run_test` : save reachability test results to specified (json) files.
  - the results are saved in specified `hoge.json` file (summary) and `hoge.detail.json` file (detail)

```text
bundle exec ruby exe/mddo_toolbox.rb test_reachability [options] <test-pattern-def>
```

## Development

### Build netomox container

```shell
docker-compose build
```

### Generate link-down snapshots (config files)

```shell
bundle exec rake linkdown_snapshots
# or like below:
python3 configs/make_linkdown_snapshots.py -i configs/pushed_configs -o configs/pushed_configs_linkdown
```

### Register snapshots into batfish

```shell
bundle exec rake bf_snapshots
# or like below:
python3 configs/register_snapshots.py -n pushed_configs -i configs/pushed_configs
```

### Generate normalized data (CSV) from batfish registered snapshots

```shell
bundle exec rake snapshot_to_model
# or like below
python3 configs/exec_queries.py -b localhost -n pushed_configs
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
