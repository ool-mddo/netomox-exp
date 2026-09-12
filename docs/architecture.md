# Architecture Overview — netomox-exp

## システム概要

netomox-exp は ool-mddo プロジェクトのネットワーク運用自動化パイプラインにおけるバックエンド API サーバーです。
以下の役割を担います。

1. **トポロジデータ管理** — RFC8345 形式の JSON を受け取り、ファイルシステムに保存・提供する
2. **トポロジ生成** — Batfish のクエリ結果（CSV）からマルチレイヤートポロジ（L1〜BGP-AS）を自動生成する
3. **名前空間変換** — 実機ネットワーク名称からエミュレーション環境名称への変換テーブルを管理・適用する
4. **形式変換** — RFC8345 トポロジを Batfish (layer1_topology.json) や ContainerLab (clab-topo.yaml) の入力形式に変換する
5. **静的検証** — 各レイヤーのトポロジ整合性を検証し、問題点をレポートする
6. **ユースケース支援** — pni_te（BGP トラフィックエンジニアリング）等のユースケース固有データを生成する

## パイプライン全体像

```
実機ネットワーク設定
    │
    ▼
Batfish（設定解析）
    │ CSV クエリ結果
    ▼
MDDO_QUERIES_DIR/<network>/<snapshot>/
    │  *.csv (edges_layer1, interface_props, ip_owners, routes, ospf_*, bgp_*, ...)
    │
    ▼  POST /topologies/:network/:snapshot/topology
netomox-exp
    │  TopologyBuilder (L1 → L2 → L3 → OSPF → BGP)
    ▼
MDDO_TOPOLOGIES_DIR/<network>/<snapshot>/topology.json
    │
    ├─ GET /topologies/:network/:snapshot/topology          → netoviz（可視化）
    │
    ├─ POST /topologies/:network/ns_convert_table           → 名前空間変換テーブル生成
    │       └─ ns_convert_table.json
    │
    ├─ GET /topologies/:network/:snapshot/topology/:layer/batfish_layer1_topology
    │       └─ Batfish 再解析（エミュレーション環境設定検証）
    │
    └─ GET /topologies/:network/:snapshot/topology/:layer/containerlab_topology
            └─ ContainerLab（エミュレーション環境構築）
```

## コンポーネント構成

```
app.rb / config.ru
└── NetomoxExp::NetomoxRestApi (Grape::API)
    ├── ApiRoute::Topologies (/topologies)
    │   ├── GET/POST /topologies/index
    │   └── ApiRoute::Network (/:network)
    │       ├── DELETE /:network
    │       ├── GET /:network/snapshots
    │       ├── ApiRoute::NsConvertTable (/:network/ns_convert_table)
    │       └── ApiRoute::Snapshot (/:network/:snapshot)
    │           └── ApiRoute::Topology (/:network/:snapshot/topology)
    │               ├── POST   (生成 or 登録)
    │               ├── GET    (取得)
    │               ├── GET upper_layer3 (L3+ フィルタ)
    │               ├── ApiRoute::LayerType (/layer_type_:type) ※先にマッチ
    │               ├── ApiRoute::Layer (/:layer)
    │               │   ├── ConfigParams      (/config_params)
    │               │   ├── ConvertLayerTopology (/batfish_layer1_topology, /containerlab_topology)
    │               │   ├── LayerObjects      (/nodes, /interfaces)
    │               │   └── VerifyLayer       (/verify)
    │               └── VerifyLayers          (/verify)
    └── ApiRoute::Usecases (/usecases)
        └── ApiRoute::Usecase (/:usecase)
            └── ApiRoute::UsecaseNetwork (/:network)
                ├── UsecaseDataByFile  (GET /flows/:file, GET /params/*, GET :params)
                └── UsecaseSnapshot (/:snapshot)
                    └── UsecaseDataByTopology
                        ├── GET /external_as_topology
                        └── GET /iperf_commands
```

## 名前空間変換の3層モデル

実機ネットワークとエミュレーション環境では、ノード名・インターフェース名の命名規則が異なります。
netomox-exp はこの変換を「ns_convert_table」として管理します。

```
original_node_name
    │
    ▼  NodeNameTable（変換テーブル）
    ├─ l3_model    : L3 トポロジモデル上の名前（エミュレーション環境）
    │                例: "regiona-rt1" → "regiona-rt1"（ノード名は変換なし）
    │                例: "Seg_192.168.0.0/30" → "Seg-192.168.0.0-30"（L3 セグメント）
    ├─ l1_agent    : エミュレーション環境の config 上の名前（cRPD/cEOS の設定ファイル名）
    │                例: セグメントノード → "Seg-192-168-0-0-30"（OVS bridge 設定名）
    └─ l1_principal: エミュレーション環境のインスタンス名（ContainerLab のノード名）
                     例: "regiona-rt1"、セグメントノード → OVS bridge インスタンス名
```

### 変換テーブルの初期化フロー

```
POST /topologies/:network/ns_convert_table
  { "origin_snapshot": "original_asis" }
        │
        ▼
ConvertTable.load_from_topology(topology_data)
    ├─ NodeNameTable.make_table       ← L3 ノード名マッピングを最初に生成（他テーブルが参照）
    ├─ TermPointNameTable.make_table  ← TP 名マッピング（usecase_params で調整可）
    ├─ OspfProcIdTable.make_table     ← OSPF プロセス ID マッピング
    └─ StaticRouteTpTable.make_table  ← 静的ルートの next-hop インターフェースマッピング
        │
        ▼
ns_convert_table.json として保存
```

## TopologyBuilder のレイヤー依存関係

```
L1L3DataBuilder (layer1)
    edges_layer1.csv, interface_props.csv, node_props.csv, ip_owners.csv
    └─ L2DataBuilder (layer2)
           sw_vlan_props.csv
           └─ L3DataBuilder (layer3)
                  ip_owners.csv, interface_props.csv, routes.csv
                  └─ ExpandedL3DataBuilder (layer3 拡張)
                         └─ OspfDataBuilder (ospf_area*)
                                ospf_proc_conf.csv, ospf_area_conf.csv, ospf_intf_conf.csv
                                └─ BgpProcDataBuilder (bgp_proc)
                                       bgp_proc_conf.csv, bgp_peer_conf.csv, named_structures.csv
```

各 Builder は `Netomox::PseudoDSL::PNetworks` を生成し、最終的に `to_data` で RFC8345 Hash に変換します。

## 主要データ構造

### topology.json (RFC8345)

```json
{
  "ietf-network:networks": {
    "network": [
      {
        "network-id": "layer1",
        "network-types": { "mddo-topology:mddo-l1-network": {} },
        "node": [
          {
            "node-id": "router1",
            "mddo-topology:mddo-l1-node-attributes": { "os-type": "juniper" },
            "ietf-network-topology:termination-point": [...]
          }
        ],
        "ietf-network-topology:link": [...]
      },
      { "network-id": "layer2", ... },
      { "network-id": "layer3", ... },
      { "network-id": "ospf_area0", ... },
      { "network-id": "bgp_proc", ... },
      { "network-id": "bgp_as", ... }
    ]
  }
}
```

**保存場所:** `$MDDO_TOPOLOGIES_DIR/<network>/<snapshot>/topology.json`

### ns_convert_table.json

```json
{
  "node_name_table": {
    "Seg_192.168.0.0/30": {
      "l3_model":     "Seg-192.168.0.0-30",
      "l1_agent":     "Seg-192-168-0-0-30",
      "l1_principal": "Seg-192-168-0-0-30"
    },
    "regiona-rt1": {
      "l3_model":     "regiona-rt1",
      "l1_agent":     "regiona-rt1",
      "l1_principal": "regiona-rt1"
    }
  },
  "tp_name_table": { ... },
  "ospf_proc_id_table": { ... },
  "static_route_tp_table": { ... }
}
```

**保存場所:** `$MDDO_TOPOLOGIES_DIR/<network>/ns_convert_table.json`

## 静的検証（StaticVerifier）

各レイヤーに対応した Verifier クラスが共通の検証（リンク対称性、未接続 TP、孤立ノード）を行い、
レイヤー固有の検証を追加します。

| Verifier クラス | 対象レイヤー | 固有検証 |
|-----------------|-------------|---------|
| `Layer1Verifier` | layer1 | — |
| `Layer2Verifier` | layer2 | — |
| `Layer3Verifier` | layer3 | セグメントプレフィックス整合性、IP 重複検出 |
| `OspfAreaVerifier` | ospf_area* | — |
| `BgpProcVerifier` | bgp_proc | — |
| `BgpAsVerifier` | bgp_as | — |

検証結果は `{ severity, target, message }` の配列として返ります。severity は fatal / error / warn / info / debug / unknown の優先順位を持ちます。

## ユースケース: pni_te (PNI Traffic Engineering)

外部 AS とのピアリングインターフェースにおけるトラフィックエンジニアリングを支援するユースケースです。

```
GET /usecases/pni_te/:network/:snapshot/external_as_topology
    │
    ├─ flows/normal.csv          → フロー情報（src/dst サブネット、レート）
    ├─ params.yaml               → usecase 設定（source_as/dest_as の AS 番号、接続情報等）
    └─ topology.json             → 内部 AS トポロジ（self HTTP GET）
            │
            ▼
    BgpAsDataBuilder
        ├─ BgpProcDataBuilder × n (source_as 毎)
        │       └─ Layer3/BgpProc レイヤーの外部 AS トポロジを構築
        └─ BgpProcDataBuilder (dest_as)
            │
            ▼
    外部 AS トポロジ (layer3 + bgp_proc + bgp_as レイヤー) を RFC8345 JSON で返す
```

## 注意点・既知の制約

1. **self-call (localhost:9292 ハードコード):** `helpers_usecase.rb` の `fetch_l3_endpoints` / `fetch_topology_object` は自身の API にリクエストする。ポートが変わると機能しない。

2. **ns_convert_table の事前初期化が必要な API:**
   - `GET /converted_topology`
   - `GET /topology/:layer/batfish_layer1_topology`
   - `GET /topology/:layer/containerlab_topology`
   - `GET /topology/:layer/nodes`
   - `GET /topology/:layer/interfaces`
   - `GET /topology/:layer/config_params`

3. **layer_type vs layer のルートマッチ順序:** `topology.rb` で `LayerType` を `Layer` より先にマウントしないと `/layer_type_ospf` が `:layer = "layer_type_ospf"` として解釈されてしまう。

4. **TopologyBuilder の CSV 必須依存:** `generate_data` は複数の CSV ファイルが全て揃っていることを前提とする。ファイルが欠けると例外で終了する。

5. **L3→L2 サポート情報の意図的除外:** NamespaceConverter は L3→L2 のサポートリンクを変換後のトポロジに含めない（エミュレーション環境では不要なため）。

6. **`eval` によるCSV配列パース:** `table_base.rb` の `parse_array_string` は `eval` を使用している。信頼できるデータソース（Batfish 出力）のみを対象とすること。
