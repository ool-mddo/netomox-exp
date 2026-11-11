# レイヤ単位のトポロジ取得 API

トポロジデータのレイヤ (network) 単位の取得と、ノード・インタフェース・設定パラメータの一覧を返す API。

> **注意:** `nodes`、`interfaces`、`config_params` は名前空間変換後の名前を返す。
> 先に変換テーブルを作成しておくこと ([ns_convert_table.md](ns_convert_table.md))。

## レイヤ / レイヤ種別によるトポロジの取得

ネットワーク (レイヤ) 単位、またはネットワークタイプ (レイヤ種別) に一致する全ネットワークを、RFC8345 形式の JSON で取得する。

* GET `/topologies/<network>/<snapshot>/topology/<layer>`
* GET `/topologies/<network>/<snapshot>/topology/layer_type_<layer_type>`

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/ospf_area0
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer_type_ospf
```

## ノードの一覧

レイヤ内の全ノードと属性を、名前空間変換後の名前で取得する。

> **注意:** RFC8345 形式ではない。簡略化された形式で、ノードテーブルの追加情報を含む。

* GET `/topologies/<network>/<snapshot>/topology/<layer>/nodes` (単一レイヤ)
* GET `/topologies/<network>/<snapshot>/topology/layer_type_<layer_type>/nodes` (複数レイヤ)
* オプション (ノードのフィルタ)
  * `node_name`: [任意] 名前でノードを選択
  * `node_type`: [任意] 指定したタイプのノードだけ選択 (segment/node/endpoint)
  * `exc_node_type`: [任意] 指定したタイプのノードを除外 (segment/node/endpoint)
  * `node_type` と `exc_node_type` は同時に指定できない
  * layer3 のノードは、名前が `*svrN` に一致する場合、または Batfish 上でホストとして定義されている場合
    (`node_props.csv` の `Configuration_Format` が `HOST`) に `endpoint` として扱う

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/ospf_area0/nodes
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer_type_ospf/nodes
```

## インタフェースの一覧

レイヤ内の全インタフェースと属性を、名前空間変換後の名前で取得する。

> **注意:** RFC8345 形式ではない。簡略化された形式で、ノード・インタフェースのテーブルの追加情報を含む。

* GET `/topologies/<network>/<snapshot>/topology/<layer>/interfaces` (単一レイヤ)
* GET `/topologies/<network>/<snapshot>/topology/layer_type_<layer_type>/interfaces` (複数レイヤ)
* オプション (ノードのフィルタ)
  * `node_name`: [任意] 名前でノードを選択
  * `node_type`: [任意] 指定したタイプのノードだけ選択 (segment/node/endpoint)
  * `exc_node_type`: [任意] 指定したタイプのノードを除外 (segment/node/endpoint)
  * `node_type` と `exc_node_type` は同時に指定できない
  * layer3 インタフェースの `attribute` は、VRRP/HSRP グループを持つ場合に `fhrp` を含む

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/ospf_area0/interfaces
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer_type_ospf/interfaces
```

## CNF 設定生成用パラメータ

CNF (cRPD など) の設定を生成するための、全ノードとインタフェースのパラメータを取得する。

* GET `/topologies/<network>/<snapshot>/topology/<layer>/config_params`
  * `node_type`: [任意] 指定したタイプのノードだけ選択 (segment/node/endpoint)
  * `exc_node_type`: [任意] 指定したタイプのノードを除外 (segment/node/endpoint)
  * `node_type` と `exc_node_type` は同時に指定できない
  * `if_list[].fhrp`: term-point の FHRP (VRRP/HSRP) グループ (キーは topology.json の `fhrp` と同じ。無ければ `[]`)。
    playbook テンプレート (`crpd.j2`) が Junos の `vrrp-group` 設定の生成に使う。

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/config_params
```

<details>
<summary>応答例</summary>

```text
[
  {
    "name": "Seg_192.168.0.0/30",                 : ノード名 (L3 モデル)
    "agent_name": "Seg-192.168.0.0-30",           : ノード名 (L1 エージェント)
    "type": "segment",                            : ノードアトリビュート由来のノードタイプ
    "if_list": [
      {
        "name": "regiona-rt1_eth1.0",             : インタフェース名 (L3 モデル)
        "agent_name": "Ethernet1",                : インタフェース名 (L1 エージェント)
        "ipv4": null,                             : インタフェースアトリビュート由来の IPv4 アドレス
        "description": "to_regiona-rt1_eth1.0",   : インタフェースアトリビュート由来の description
        "original_if": "regiona-rt1_ge-0/0/0.0"   : 元の名前空間 (変換前) でのインタフェース名
      },
      {
        "name": "regiona-rt2_eth1.0",
        "agent_name": "Ethernet2",
        "ipv4": null,
        "description": "to_regiona-rt2_eth1.0",
        "original_if": "regiona-rt2_ge-0/0/0.0"
      }
    ]
  },
...
]
```

</details>
