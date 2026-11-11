# netomox-exp

Backend api to operate topology data. (original: https://github.com/corestate55/netomox-examples)

## Directories

```text
+ netomox-exp/         # https://github.com/ool-mddo/netomox-exp (THIS repository)
  + doc/               # class documents (generated w/yard)
  + docs/              # documents (API manuals: docs/api/, architecture, test plan)
  + figs/              # design diagrams
  + lib/               # REST API body
  + model_defs/        # scripts to generate topology data (prototype)
  + spec/              # automated tests (rspec)
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
* `MDDO_PROFILES_DIR`: diagram profile directory for netoviz2 (YAML files written by hand: `<network>/<name>.yaml`; read only; default: `./profiles`)

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

Details of each API (parameters, responses and curl examples) are split into manuals by purpose.
The manuals are written in Japanese.

### `topologies` space

| Purpose | Document |
|---|---|
| Register/fetch/delete topology data, list snapshots | [docs/api/topology_data.md](docs/api/topology_data.md) |
| Fetch by layer, list nodes / interfaces / CNF config parameters | [docs/api/topology_layers.md](docs/api/topology_layers.md) |
| Operate namespace convert table, fetch namespace-converted topology | [docs/api/ns_convert_table.md](docs/api/ns_convert_table.md) |
| Convert topology for Batfish / ContainerLab | [docs/api/topology_convert.md](docs/api/topology_convert.md) |
| Static verification | [docs/api/verification.md](docs/api/verification.md) |
| Fetch/save netoviz index (legacy netoviz) | [docs/api/netoviz_index.md](docs/api/netoviz_index.md) |
| API for netoviz2 (summary / layers / supports / attributes / profiles) | [docs/api/netoviz2.md](docs/api/netoviz2.md) |

### `usecases` space

| Purpose | Document |
|---|---|
| Common / PNI / Manual-Ops / Refocus-topology usecases | [docs/api/usecases.md](docs/api/usecases.md) |

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

### Test

Automated tests are written with [RSpec](https://rspec.info/) (`spec/`).
Test gems (`rspec`, `rack-test`) belong to the optional `test` group in `Gemfile`,
so they are **not** installed into the container image (`spec/` is also excluded by `.dockerignore`).

```shell
# enable the optional `test` group (needs github packages credential, see "Optional: Install ruby gems")
export BUNDLE_WITH=test
bundle install

# run all tests
bundle exec rspec
# or
bundle exec rake spec

# run a part of tests
bundle exec rspec spec/convert_namespace
bundle exec rspec spec/api/ns_convert_table_api_spec.rb
bundle exec rspec spec/convert_namespace/convert_table_spec.rb:56
```

- Tests do not need external services (Batfish, ContainerLab, etc.). Topology/usecase directories
  (`MDDO_*_DIR`) are redirected to temporary directories, and test data is in `spec/fixtures/`
  (copy of `mddo-fw` network data; `mddo-fw-fhrp` / `mddo-fw-endpoint` queries are variants with VRRP/HSRP and
  endpoint (host) nodes).
- Some expected data (`spec/fixtures/golden/`) can be regenerated with `UPDATE_GOLDEN=1 bundle exec rspec`.
  **Always review the diff** of regenerated files.
- CI: GitHub Actions (`.github/workflows/test.yaml`) runs rubocop and rspec on pull request.
  On push, `actions.yaml` runs it first and builds/pushes the container image only if it succeeds.
- Test plan and policy: [docs/test_plan.md](docs/test_plan.md)
