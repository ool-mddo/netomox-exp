# トポロジデータの操作 API

トポロジデータ (RFC8345 形式の `topology.json`) の登録・取得・削除と、スナップショットの一覧を扱う API。
データは `$MDDO_TOPOLOGIES_DIR/<network>/<snapshot>/topology.json` に保存される。

## トポロジデータの削除

network 内の全トポロジ (および関連データ) を削除する。

* DELETE `/topologies/<network>`

```shell
curl -X DELETE http://localhost:9292/topologies/pushed_configs
```

スナップショットを削除する。スナップショットのディレクトリごと即時に削除されるため、
`topology.json` と `ns_convert_table.json` が同時に消える。

* DELETE `/topologies/<network>/<snapshot>`

```shell
curl -X DELETE http://localhost:9292/topologies/mddo-fw/original_asis_conduit1
```

## トポロジデータの保存 (登録)

* POST `/topologies/<network>/<snapshot>/topology`
  * `topology_data`: RFC8345 形式のトポロジデータ

```shell
# topology.json
# -> { "topology_data": <RFC8345 topology data> }
curl -X POST -H "Content-Type: application/json" -d @topology.json \
  http://localhost:9292/topologies/pushed_configs/mddo_network/topology
```

## トポロジデータの取得

* GET `/topologies/<network>/<snapshot>/topology`

```shell
curl http://localhost:9292/topologies/pushed_configs/mddo_network/topology
```

layer3 とその上位レイヤだけを取得する。

* GET `/topologies/<network>/<snapshot>/topology/upper_layer3`

```shell
curl http://localhost:9292/topologies/mddo-ospf/original_asis/topology/upper_layer3
```

レイヤ単位の取得・ノード/インタフェースの一覧は [topology_layers.md](topology_layers.md) を参照。

## スナップショットの一覧

network 内のスナップショットを一覧する。

* GET `/topologies/<network>/snapshots`
  * `prefix`: [任意] スナップショット名の接頭辞

```shell
curl "http://localhost:9292/topologies/mddo-bgp/snapshots?prefix=original"
```
