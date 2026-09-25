# CLAUDE.md — netomox-exp

## プロジェクト概要

netomox-exp は、ネットワークトポロジデータ（RFC8345形式）を管理・操作する Ruby 製 REST API サーバーです。
ool-mddo プロジェクトのバックエンドとして機能し、Batfish による設定解析結果（CSV）から
ContainerLab / cRPD ベースのエミュレーション環境構築までをつなぐパイプラインを担います。

## 重要な前提・制約

- **Rubyバージョン:** 3.4 以上
- **`netomox` gem:** GitHub Packages (`ool-mddo` org) からのみ取得可能。`bundle install` に GitHub 認証が必要
- **ポート番号:** 9292 に hardcode あり（[lib/api/helpers_usecase.rb](lib/api/helpers_usecase.rb) L50, L64）
  - `external_as_topology` / `iperf_commands` API が自身に HTTP リクエストを送る self-call 設計
- **URL マッチ順序:** `/layer_type_:layer_type` は `/:layer` より先にマウントする必要がある
  （[lib/api/topologies/network/snapshot/topology.rb](lib/api/topologies/network/snapshot/topology.rb) L62-63 参照）
- **`ns_convert_table.json` の事前初期化:** `converted_topology`, `batfish_layer1_topology`,
  `containerlab_topology`, `nodes`, `interfaces`, `config_params` の各 API はスナップショット
  ディレクトリ内の `ns_convert_table.json` が存在することを前提とする。存在しない場合は 404 エラー。
  ファイルは `POST /topologies/:nw/:ss/ns_convert_table` で生成される。
- **`DELETE /topologies/:nw/:ss` はスナップショットディレクトリごと削除:** `FileUtils.rm_rf` で即時削除。
  `conduit_topology` API が既存の `*_conduitN` スナップショットを削除する際に使用される。
  失敗しても後続処理は続行 (デバッグのため残す設計)。
- **`eval` 使用:** CSV の配列フィールドのパース時に `eval` を使用している
  ([lib/topology_builder/csv_mapper/table_base.rb](lib/topology_builder/csv_mapper/table_base.rb) L51)
- **JSON gem:** v3.x を使用。`JSON.parse` / `JSON.dump` はオプションなしで呼び出しており互換性に問題なし
- **CSV gem:** Ruby 3.4 以降は明示的に Gemfile へ記載が必要（`require 'csv'` は lib 内で使用中）

## 環境変数

| 変数 | デフォルト | 説明 |
|------|------------|------|
| `MDDO_QUERIES_DIR` | `./queries` | Batfish CSV（入力）のルートディレクトリ |
| `MDDO_TOPOLOGIES_DIR` | `./topologies` | トポロジ JSON / NS 変換テーブルの保存先 |
| `MDDO_USECASES_DIR` | `/mddo/usecases` | ユースケース YAML / CSV のルートディレクトリ |
| `NETOMOX_EXP_LOG_LEVEL` | `info` | ログレベル（fatal / error / warn / info / debug） |
| `NETOMOX_LOG_LEVEL` | `info` | netomox gem のログレベル |

## 開発コマンド

```bash
# 依存インストール（GitHub Packages 認証が必要）
export BUNDLE_RUBYGEMS__PKG__GITHUB__COM="USERNAME:TOKEN"
bundle install

# 開発サーバー起動（ファイル変更で自動リロード）
rerun bundle exec rackup -s webrick -o 0.0.0.0 -p 9292

# コンテナ内（volume マウント）の場合
rerun --force-polling bundle exec rackup -s webrick -o 0.0.0.0 -p 9292

# lint
bundle exec rake rubocop
bundle exec rubocop --autocorrect   # safe fixes only
bundle exec rubocop -A               # unsafe fixes も含む

# API ドキュメント生成 (YARD)
bundle exec rake yard
bundle exec yard server   # http://localhost:8808/

# Docker イメージビルド（認証が必要）
ghp_credential="USERNAME:TOKEN" docker buildx build -t netomox-exp --secret id=ghp_credential .
```

## テスト

自動テストは存在しない。`lib/test_*.rb` は手動実行スクリプト（位置づけ要確認）。

## ディレクトリ構成の要点

```
lib/api/               # Grape REST API 定義（ルーティング層）
lib/topology_builder/  # Batfish CSV → RFC8345 JSON 変換
lib/convert_namespace/ # オリジナル ↔ エミュレーション名前空間変換
lib/convert_topology/  # RFC8345 → Batfish / ContainerLab 形式変換
lib/static_verifier/   # レイヤー別静的検証（L1/L2/L3/OSPF/BGP）
lib/usecase_deliverer/ # ユースケース固有データ生成（外部AS、iperf）
model_defs/            # プロトタイプ用手書きトポロジ定義（本番フローとは独立）
```

詳細は [docs/architecture.md](docs/architecture.md) を参照。

## FW ノードアトリビュート JSON スキーマ

FW アトリビュートの JSON スキーマは複数リポジトリをまたがる canonical definition として管理されている:
**`playground/docs/firewall_node_attributes.md`**

このファイルには以下が記載されている:
- per-node JSON / topology endpoint payload / topology.json 内の配置の各スキーマ
- `flag: ["firewall"]` と `firewall` アトリビュートの二重構造の説明
- netomox gem の `ATTR_DEFS[ext:]` との整合性制約

## 名前空間変換: FW ノード (vSRX) 対応

`lib/convert_namespace/namespace_convert_table/` の変換テーブルは、
layer3 ノードが FW ノード（vSRX）かどうかで変換ルールを分けている。

**FW ノード判定 (`firewall_node?` in `convert_table_base.rb`):**  
RFC8345 トップレベルの `"flag": ["firewall"]` を持つノードを FW ノードと判定する。
`ConvertTable#load_from_topology` が生の topology JSON から FW ノード名 Set を抽出し (`extract_l3_firewall_node_names`)、
全サブテーブルに注入 (`firewall_node_names=`)。`node.attribute.firewall` は全ノードで常に non-nil のため使用不可。

**TP 名変換ルール:**

| | cRPD ノード | vSRX（FW）ノード |
|---|---|---|
| `l3_model` | `ethN.0`（連番） | 元の JunOS インタフェース名（例: `ge-0/0/1.0`） |
| `l1_agent` | `ethN`（連番） | 元の物理名（例: `ge-0/0/1`、ユニット番号なし） |
| `l1_principal` | `ethN`（連番） | Proxmox ホスト側 NIC 名（例: `eth3`） |

**vSRX の `l1_principal` 割り当て順序:**
- `management` インタフェース → `eth1`
- `control` インタフェース → `eth2`
- `fabric` インタフェース (ge-0/0/0 / ge-7/0/0) → `eth3` (固定; L3 TP に現れないが containerlab で直接使用)
- データポート → `ge-x/y/z` を若番ソートして `eth4` 以降を割当て。ただし HA パートナー側の FPC 番号
  (下記) に属するポートは、自ノードのポートとは**別グループとして独立に** `eth4` から番号を振り直す
- 同一物理ポートの複数サブインタフェースは同じ `ethM` を共有

**HA ペアの config 共有に関する注意:** chassis cluster 構成では fw-1/fw-2 (node0/node1) が
同一の設定内容を持つため、両ノードの L3 TP に自分側 (`ge-0/*/*`) とパートナー側 (`ge-7/*/*`) の
データポートが両方現れる（実リンクは自分側にしか無い、いわば「幽霊」ポート）。しかし
`NamespaceConverter#rewrite_node` はノードの全 TP（実リンクの有無を問わず）を変換テーブルで
引くため、パートナー側ポートも変換テーブルへのエントリ自体は必要。
`build_firewall_eth_map` は `partner_fpc_number(node)` (`pair` の相手側の fabric メンバー
インタフェースから判定) でパートナー側の FPC 番号を求め、そのポート群だけを自分側とは別グループに
分けて `eth4` から番号を振り直す（`assign_sequential_eth_names`）。結果として自分側とパートナー側で
同じ `ethM` が重複して使われるが、パートナー側ポートは実体のない参照専用エントリのため実害はない。

**静的ルートの next-hop インタフェース (`StaticRouteTpTable`):**
- cRPD ノード: `'dynamic'` に変換
- vSRX（FW）ノード: 元の JunOS インタフェース名を保持

## 追加済みエンドポイント・ヘルパー

### `DELETE /topologies/:network/:snapshot`

スナップショットディレクトリを削除する。`FileUtils.rm_rf` で即時削除。
`topology.json` と `ns_convert_table.json` の両方が同じディレクトリにあるため、同時に削除される。
`lib/api/topologies/network/snapshot.rb` に定義。

### `GET /usecases/:usecase/:network/:snapshot/topology`

usecase ディレクトリ内の blueprint topology JSON を返す。
`$MDDO_USECASES_DIR/:uc/:nw/:ss/topology.json` を読み込む。
`lib/api/usecases/usecase/network/snapshot/blueprint_topology.rb` に定義。

呼び出し例:
```
GET /usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology
→ usecases/refocus_topology/mddo-fw/original_asis_blueprint/topology.json
```

### `Helpers#read_usecase_snapshot_topology(usecase, network, snapshot)`

`helpers_usecase.rb` に追加したヘルパーメソッド。
`USECASE_DIR/:uc/:nw/:ss/topology.json` を `read_json_file` で読んで返す。
`blueprint_topology.rb` のルートブロックから呼び出される。
(`USECASE_DIR` 定数は `Helpers` モジュール内でしかアクセスできないため、ルートから直接参照不可。)

## ContainerLab トポロジ変換: FW ノード (proxmox) 対応

`GET /topologies/:nw/:ss/topology/:layer/containerlab_topology` で `usecase` パラメータを渡すと、
ユースケース params.yaml の `containerlab_nodes` セクションに定義されたノードごとの設定を優先的に使用する。

**`containerlab_nodes` (params.yaml):**
ノード名をキーとするハッシュ。各エントリが `ContainerLabConverter#find_clab_node_params` で参照される。
`l3_preallocated_resources` とは独立した別セクション（処理コードは共有しない）。

サポートするフィールド: `kind`, `image`, `env`, `binds`, `ports`, `labels`
（`startup-config` は付与されない — proxmox/VM ベースのノードは config ファイル注入を使わない）

```yaml
# usecases/<usecase>/<network>/params.yaml
containerlab_nodes:
  site-a-fw-1:
    kind: linux
    image: 'rtedpro/proxmox:9.2.3'
    env:
      container: docker
    binds:
      - /dev/kvm:/dev/kvm
      - /tmp/proxmox-shared:/var/tmp
      - /tmp/proxmox-shared/qemu:/opt/qemu-shared
    ports:
      - "8006:8006"
    labels:
      ansible-group: junos
      clusterid: 1
      redundant: act   # secondary は "sby"
```

**優先順位 (`select_node_data` の参照順):**
1. `containerlab_nodes` に定義あり → その定義を使用（FW / proxmox ノード）
2. `l3_preallocated_resources` の `emulated_params` に定義あり → そちらを使用（Nokia SR-SIM 等）
3. いずれも未定義 → `juniper_crpd` デフォルト（cRPD ノード）

実装: [`lib/convert_topology/containerlab_converter.rb`](lib/convert_topology/containerlab_converter.rb)

### FW HA ペアの fabric リンク自動生成

`ContainerLabConverter#convert` は通常の L3 リンクに加え、FW HA クラスタのファブリックリンクを自動追加する。
ファブリックリンクは L3 トポロジに現れないが、エミュレーション環境では必要なリンク。

**eth 番号の割り当て (vSRX / Proxmox):**
| eth 番号 | 用途 |
|---|---|
| eth1 | management |
| eth2 | control (JunOS eth0 相当) |
| eth3 | **fabric** (ge-0/0/0 / ge-7/0/0 — 固定) |
| eth4 以降 | データポート (ge-x/y/z を若番ソート。HA パートナー側ポートは別グループとして
  独立に eth4 から採番されるため、自分側と番号が重複しうる — 詳細は上記「名前空間変換」節参照) |

primary ノードの `node.attribute.firewall.pair` から secondary ノードを特定し、
primary:eth3 ↔ secondary:eth3 のリンクを生成する。

**関連メソッド:**
- `firewall_primary_node?(node)` — primary/secondary 判定
- `fabric_eth_name(_node)` — `'eth3'` を返す（固定）
- `make_fabric_link(primary_node)` — 1 ペア分のリンク Hash を生成
- `fabric_link_data` — 全 HA ペアのファブリックリンク Array を返す

### ns_convert_table の fabric インタフェースエントリ

`TermPointNameTable#make_table_for_firewall_actual` は、L3 TP として現れない fabric インタフェース
(ge-0/0/0 / ge-7/0/0) のエントリも変換テーブルに追加する。

```json
"site-a-fw-1": {
  "ge-0/0/1.0": { "l3_model": "ge-0/0/1.0", "l1_agent": "ge-0/0/1", "l1_principal": "eth4" },
  "ge-0/0/0":   { "l3_model": "ge-0/0/0",   "l1_agent": "ge-0/0/0", "l1_principal": "eth3" }
}
```

fabric インタフェースはサブインタフェース指定なし (物理ポート直接使用のため `.0` サフィックスなし)。
`extract_fabric_member_interfaces(node)` が `pair[...]['atypical_interfaces']` から取得する。

## ns_convert_table のスナップショット単位管理

変換テーブルはスナップショットごとに独立して管理される:

- **ファイルパス:** `$MDDO_TOPOLOGIES_DIR/<network>/<snapshot>/ns_convert_table.json`
  (topology.json と同一ディレクトリ)
- **REST API:** `GET/POST/DELETE /topologies/:nw/:ss/ns_convert_table`
  (`lib/api/topologies/network/snapshot/ns_convert_table.rb`)
- **自動削除:** `DELETE /topologies/:nw/:ss` で snapshot ディレクトリを `rm_rf` すると自動削除される
- **404:** `ns_convert_table.json` が存在しない状態で参照 API を呼ぶと 404 を返す

### POST の動作

| リクエストボディ | 動作 |
|---|---|
| `{ usecase: "..." }` または空 | URL の `:ss` の `topology.json` からテーブルを生成・保存 |
| `{ convert_table: {...} }` | 提供されたテーブルを直接保存 (手動上書き) |

### 変換方向の意味

| snapshot プレフィックス | テーブルの方向 |
|---|---|
| `original_*` | original → emulated |
| `emulated_*` | emulated → original |

ヘルパーメソッド: `ns_convert_table_file(network, snapshot)`, `read_ns_convert_table(network, snapshot)`,
`save_ns_convert_table(network, snapshot, data)`, `ns_converter_wo_topology(network, snapshot)`
