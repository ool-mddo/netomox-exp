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

## Generate normalized CSV files from configs

### Up batfish and netoviz containers

```shell
docker-compose up -d
```

- netoviz: `http://localhost:3000/` with browser.
- batfish: localhost `tcp/9996-9997`

### Generate normalized network data from configs (snapshots)

several keywords can use to target creating csv (see help: `-h`)

```shell
./configs/make_csv.sh all
```

## Generate topology json from normalized network data

```shell
bundle exec rake
```

## Tools

### Check L1 interface description

Check existence of interface description and it format is correct.

```shell
bundle exec exe/check_l1_intf_description.rb -i <topology file>
```

### Make L1 interface description

Make L1 interface description from topology file (layer1 topology).
It print description data as CSV (to stdio)

```shell
bundle exec exe/make_l1_intf_description.rb  -i <topology file>
```

### Check disconnected network

For topology file with layer1 link-down snapshot.
Check disconnected network and compare origin topology.

```shell
bundle exec exe/check_disconnected_network.rb compare -m 20 <before topology file> <after topology file(s)>
```

- before: topology file from original snapshot (without link-down)
- after: topology file(s) with link-down snapshot(s)
  - it can specify multiple files with wildcard, e.g. `... compare orig.json target*.json`

`-m` option is minimum score to print result. (optional)


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
