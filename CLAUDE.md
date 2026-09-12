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
  `containerlab_topology`, `nodes`, `interfaces`, `config_params` の各 API はこのファイルが
  存在することを前提とする。存在しない場合は 404 エラー
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
