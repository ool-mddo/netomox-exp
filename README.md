
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

### Update submodules

Pull network device configurations for experiments (at netomox-exp directory).

- [configs/batfish-test-topology](https://github.com/corestate55/batfish-test-topology)
- [configs/pushed_configs](https://github.com/ool-mddo/pushed_configs)


```shell
git submodule update --init --recursive
```

### Install ruby gems

```shell
bundle install --path=vendor/bundle
```

### Install python packages

```shell
pip install -r configs/requirements.txt
```

### Install docker/docker-compose

For ubuntu linux

```shell
apt install docker.io docker-compose
```

Optional: Add `docker` group to your group to allow use docker without sudo.

## Generate topology json from normalized network data

```shell
bundle exec rake
```

See details of task sequence `default` task in `Rakefile`.

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

## Development

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
