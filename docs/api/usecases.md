# ユースケース API (`usecases` 空間)

ユースケース固有のデータを扱う API。データは `$MDDO_USECASES_DIR/<usecase>/<network>/` 以下から読み込む。

## 共通

ユースケースのパラメータ (`params.yaml`) を取得する。

* GET `/usecases/<usecase>/<network>/params`

```shell
curl -s http://localhost:9292/usecases/pni_te/mddo-bgp/params
```

## PNI ユースケース

フローデータを取得する。

* GET `/usecases/<usecase>/<network>/flows/<flow_data>`

```shell
# usecases/pni_te/mddo-bgp/flows/normal.csv を JSON で取得
curl -s http://localhost:9292/usecases/pni_te/mddo-bgp/flows/normal
```

外部 AS のトポロジデータを生成する。

* GET `/usecases/<usecase>/<network>/<snapshot>/external_as_topology`
* オプション
  * `flow_data`: フローデータ (ファイル名)

```shell
curl -s "http://localhost:9292/usecases/pni_te/mddo-bgp/original_asis/external_as_topology?flow_data=normal"
```

iperf のコマンドを生成する。

* GET `/usecases/<usecase>/<network>/<snapshot>/iperf_commands`
* オプション
  * `flow_data`: フローデータ (ファイル名)

```shell
curl -s "http://localhost:9292/usecases/pni_te/mddo-bgp/emulated_asis/iperf_commands?flow_data=normal"
```

> `external_as_topology` と `iperf_commands` は、内部で自身 (ポート 9292) に HTTP リクエストを送る。

## Manual-Ops ユースケース

layer3 の事前割り当て (空の) リソースのトポロジデータを生成する。

* GET `/usecases/<usecase>/<network>/params/layer3_pre_allocated`

```shell
curl -s http://localhost:9292/usecases/manual-ops/mddo-bgp/params/layer3_pre_allocated
```

## Refocus-topology ユースケース

blueprint のトポロジデータを取得する。`$MDDO_USECASES_DIR/<usecase>/<network>/<snapshot>/topology.json` を返す。

* GET `/usecases/<usecase>/<network>/<snapshot>/topology`

```shell
curl -s http://localhost:9292/usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology
```
