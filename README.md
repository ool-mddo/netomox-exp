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

```shell
./configs/make_csv.sh
```

## Generate topology json from normalized network data

```shell
bundle exec rake [TARGET=./model_defs/hoge.rb]
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
