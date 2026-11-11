# 静的検証 API

トポロジデータを静的に検証する API。全レイヤ、または 1 つのレイヤを、そのネットワークタイプに応じて検証する。

* GET `/topologies/<network>/<snapshot>/topology/verify` : 全レイヤを検証
* GET `/topologies/<network>/<snapshot>/topology/<layer>/verify` : 1 つのレイヤを検証
* オプション
  * `severity`: [任意] 基準とする severity (デフォルト: debug)

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/original_asis/topology/layer1/verify
```
