# netoviz2 向け API

netoviz2 (汎用トポロジビューワー) が必要とする構造を、`topology.json` から整形して返す API。
いずれも読み取り専用 (POST の `attributes` も副作用なし)。

> **正本 (データ形式・API 仕様):** playground リポジトリの `docs/netoviz2_data_format.md`。
> このドキュメントは利用の概要であり、応答フィールドの詳細は正本を参照すること。

## API 一覧

| API | 内容 |
|---|---|
| `GET /topologies/<network>/<snapshot>/netoviz2/summary` | レイヤ一覧 (kind、支持関係、rank、件数)、`flags`、`has_diff`、`warnings`、`etag` |
| `GET /topologies/<network>/<snapshot>/netoviz2/layers/<layer>` | 指定レイヤの構造 (nodes / tps / links。属性なし) |
| `GET /topologies/<network>/<snapshot>/netoviz2/supports` | 全レイヤのオブジェクト間の support |
| `POST /topologies/<network>/<snapshot>/netoviz2/attributes` | 指定した ID の属性・差分の詳細 (最大 200 件) |
| `GET /topologies/<network>/netoviz2/profiles` | network のダイアグラムプロファイル (schematic レイアウト用) |

```shell
curl -s http://localhost:9292/topologies/mddo-fw/original_asis/netoviz2/summary
curl -s http://localhost:9292/topologies/mddo-fw/original_asis/netoviz2/layers/layer3
curl -s http://localhost:9292/topologies/mddo-fw/original_asis/netoviz2/supports

# ids は文字列の配列 (1〜200 件)
curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"ids": ["layer3/site-a-br-1", "layer3"]}' \
  http://localhost:9292/topologies/mddo-fw/original_asis/netoviz2/attributes

curl -s http://localhost:9292/topologies/mddo-fw/netoviz2/profiles
```

## オブジェクトの ID

各セグメントをパーセントエンコードして `/` で連結する。先頭のセグメントは layer の ID。

| 対象 | 形式 |
|---|---|
| node | `<layer>/<node>` |
| term-point | `<layer>/<node>/<tp>` |
| link | `<layer>/~link/<link-id>` |

## ETag と条件付きリクエスト

* GET の各 API は `ETag` (`v<スキーマ版>-<mtime>-<size>`) を返す。`If-None-Match` に一致すると 304 (本文なし) を返す。
* POST の `attributes` は ids によって応答が変わるため、ETag も 304 も扱わない。
* `profiles` も ETag ヘッダと 304 を持たない (毎回ファイルを読む)。

## diff

`_diff_state_` から状態を導出し、`added` / `deleted` / `changed` のオブジェクトにだけ `diff` を付ける。
`_diff_state_` は diff でないトポロジにも `kept` で入っている (netomox が常に出力する) ため、存在の有無では判定しない。
属性・support 内の差分の復元には netomox 0.15.1 以降が必要。

## エラー

| ステータス | 条件 |
|---|---|
| 404 | network / snapshot / `topology.json` / layer が存在しない |
| 422 | `ids` が配列でない、文字列以外の要素を含む、空、または上限 (200 件) 超過 |
| 500 | 元データが読み込めない、または整形処理の不具合。本文は `{"error": "..."}` |

## ダイアグラムプロファイル API (`profiles`)

schematic レイアウト用のダイアグラムプロファイルを、YAML から JSON に変換して返す。
network 単位の API で、snapshot には依存しない (適用先の snapshot はプロファイル自身の `target.snapshot` が宣言する)。

* 元データ: `$MDDO_PROFILES_DIR/<network>/<名前>.{yaml,yml}` (人が書く YAML。読み取りのみ)
* 変換するだけで、プロファイルの意味は検証しない (検証・選択は netoviz2 が行う)
* 応答: `{network, profiles: [{name, etag, documents, error?}]}`。YAML の文書 (`---` 区切り) ごとに `documents` の 1 要素になる
* ファイル単位のエラー: 次のファイルは、そのファイルだけ `error` にする (HTTP は 200 で、他のファイルは返す)
  * YAML の構文エラー
  * JSON で表せない書き方 (アンカー・エイリアス・タグ、文字列でないキー、日付・シンボル、`.nan` / `.inf`、深さ 64 超)
  * 1MB を超えるファイル
* 名前は `[A-Za-z0-9_][A-Za-z0-9_.-]*` (ファイル名から拡張子を除いたもの) に限る。
  通常のファイルだけを読み、シンボリックリンクは辿らない。同名の `.yaml` と `.yml` があれば `.yaml` を使う。
  network 名が `..` や `/` を含むなど不正なときは、`profiles` は `[]` になる
* 型は YAML 1.1 (Psych) の規則に従う (例: `017` は 15、`yes` は真偽値)。文字列にしたい値は引用符で囲む

プロファイルの書式は playground の `profiles/README.md` と netoviz2 の `docs/design/profile_format.md` を参照。

## 実装

* ロジック: `lib/netoviz2/` (`ObjectId`、`Model`、`LayerGraph`、各 `*Builder`、`ModelCache`、`ProfileFiles`)
* API: `lib/api/topologies/network/snapshot/netoviz2_api.rb`、`lib/api/topologies/network/netoviz2_profiles_api.rb`、
  `lib/api/helpers_netoviz2.rb`
* モデルは ETag をキーに直近 2 件をキャッシュする
* 実装上の注意は [CLAUDE.md](../../CLAUDE.md) の「netoviz2 向け API」を参照
