# netomox-exp
A trial of network model construction.

# Setup

## Clone sources

Clone each repositories.

```text
+ ool-mddo/
  + netomox-exp/         # https://github.com/ool-mddo/netomox-exp (THIS repository)
  + pushed_configs/      # https://github.com/ool-mddo/pushed_configs
    - configs/           #   - network device configs
  + netbox2inet-henge/   # https://github.com/ool-mddo/netbox2inet-henge
    - layer1_topology.sample.json # L1 topology for batfish from netbox
```

## Update submodules

Pull network device configurations for experiments (in netomox-exp directory).

```shell
git submodule update --init --recursive
```

## Install ruby gems

```shell
bundle install --path=vendor/bundle
```

## Generate normalized CSV files from configs

### Up batfish and netoviz containers

```shell
docker-compose up -d
```

- netoviz: `http://localhost:3000/` with browser.
- batfish: localhost `tcp/9996-9997`

### Activate pybatfish environment (w/venv)

Note: venv and pybatfish are `~/batfish/bf-venv`

```shell
. ~/batfish/bf-venv/bin/activate
cd model_defs/mddo_trial
# for model_defs/batfish-test-topology data
python exec_l2queries.py
# for MDDO project (pushed_configs) data
./make_csv.sh
cd -
```

## Generate topology json for netoviz

```shell
bundle exec rake [TARGET=./model_defs/hoge.rb]
```

# Setup python venv and pybatfish

[Pybatfish](https://github.com/batfish/pybatfish) is a python frontend for batfish.
Setup venv for python3 before install pybatfish.

ref: [pybatfish on github](https://github.com/batfish/pybatfish#install-pybatfish)

```
mkdir -p ~/batfish
cd ~/batfish

python -m venv bf-venv
. bf-venv/bin/activate
pip install wheel
python -m pip install --upgrade git+https://github.com/batfish/pybatfish.git
```

# Generate YARD documents

```shell
bundle exec rake yard
```

Run yard document server (access `http://localhost:8808/` with browser)

```shell
bundle exec yard server
```

# Repository configuration

## Original

- https://github.com/corestate55/netomox-examples

## Submodule

- [model_defs/batfish-test-topology](https://github.com/corestate55/batfish-test-topology)
