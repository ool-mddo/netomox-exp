# 名前空間変換 API

original と emulated の間で、ノード名・インタフェース名の名前空間を変換するための API。
変換テーブルは**スナップショット単位**で管理され、`$MDDO_TOPOLOGIES_DIR/<network>/<snapshot>/ns_convert_table.json`
(`topology.json` と同じディレクトリ) に保存される。

> **事前条件:** `converted_topology`、`batfish_layer1_topology`、`containerlab_topology`、`nodes`、`interfaces`、
> `config_params` の各 API は、`ns_convert_table.json` が存在することを前提とする。
> 存在しない場合は 404 を返すため、先にテーブルを作成 (POST) しておくこと。

## 変換テーブルの削除

* DELETE `/topologies/<network>/<snapshot>/ns_convert_table`

```shell
curl -X DELETE http://localhost:9292/topologies/mddo-ospf/original_asis/ns_convert_table
```

スナップショットを削除 (`DELETE /topologies/<network>/<snapshot>`) すると、テーブルも一緒に削除される。

## 変換テーブルの作成・更新

* POST `/topologies/<network>/<snapshot>/ns_convert_table`
  * `usecase`: [任意] テーブル生成時に `params.yaml` を読み込むユースケース名
  * `convert_table`: [任意] 直接保存する変換テーブル (手動での上書き)

| リクエストボディ | 動作 |
|---|---|
| `{ "usecase": "..." }` または空 | URL の `<snapshot>` の `topology.json` からテーブルを生成して保存する |
| `{ "convert_table": {...} }` | 渡されたテーブルをそのまま保存する (手動上書き) |

```shell
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"usecase": "refocus_topology"}' \
  http://localhost:9292/topologies/mddo-ospf/original_asis/ns_convert_table
```

### original / emulated のペア保存

テーブルは origin (original) のトポロジから生成した 1 枚で、方向別の内容は持たない。
model-conductor の `ns_convert` API が、同一内容を `original_*` と対応する `emulated_*` の両スナップショットに
`convert_table` として POST して保存する。保存後の同期は行わない (片方だけ DELETE しても他方は残る)。

## 変換テーブルの取得

* GET `/topologies/<network>/<snapshot>/ns_convert_table`

```shell
curl http://localhost:9292/topologies/mddo-ospf/original_asis/ns_convert_table
```

## 変換テーブルによる名前の変換

* POST `/topologies/<network>/<snapshot>/ns_convert_table/query`
  * `host_name`: 変換するホスト名
  * `if_name`: [任意] 変換するインタフェース名

```shell
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"host_name": "Seg_192.168.0.0/30", "if_name": "regiona-rt1_ge-0/0/0.0"}' \
  http://localhost:9292/topologies/mddo-ospf/original_asis/ns_convert_table/query
```

応答:

```json
{
  "origin_host": "<original hostname>",
  "target_host": { "l3_model": "...", "l1_agent": "...", "l1_principal": "..." },
  "origin_if": "<original if name>",
  "target_if": { "l3_model": "...", "l1_agent": "...", "l1_principal": "..." }
}
```

* `origin_if` / `target_if` は `if_name` を指定したときだけ含まれる。
* `target_host` / `target_if` は、レイヤ視点 (`l3_model` / `l1_agent` / `l1_principal`) ごとの変換後の名前を持つハッシュ。
* 変換テーブルにノードまたはインタフェースが見つからないときは HTTP 404 を返す。

## 名前空間を変換したトポロジの取得

* GET `/topologies/<network>/<snapshot>/converted_topology`
  * 注意: 呼び出す前に、その network の変換テーブルを作成しておくこと。

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/original_asis/converted_topology
```

## 変換ルールの補足

FW ノード (vSRX) と cRPD ノードでは変換ルールが異なる。詳細は [CLAUDE.md](../../CLAUDE.md) の
「名前空間変換: FW ノード (vSRX) 対応」を参照。
