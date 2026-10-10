# netomox-exp テスト導入計画

> **ステータス: P0〜P2 + CI 実装済み** (137 examples, 0 failures, 0 pending)。実装結果・計画からの差分は「実装結果」、未対応事項は末尾「残課題」を参照。

## Context

netomox-exp (Ruby 3.4 / Grape REST API, lib 88 ファイル・約 9,000 行) には自動テストが無い。
`lib/test_*.rb` は手動実行スクリプトで、assert を持たず CI でも使われていない。
一方、直近の変更（FW HA ペアの eth 番号割当て、fabric リンク自動生成、ns_convert_table のスナップショット単位化など）は
複雑な命名規則・分岐ロジックを含み、回帰が起きやすい。デモ実行 (`21_generate_conduit.sh`) でしか検証できないのは遅く、原因切り分けも難しい。

目的: **回帰を早期に検知できる最小限かつ保守しやすいテスト基盤**を作り、リスクの高いロジックから段階的にカバーする。

## 方針

- **フレームワーク: RSpec**（環境に rspec 3.13 導入済み。Gemfile の `group :test, optional: true` に `rspec`, `rack-test` を追加（本番イメージに入れないため。後述）。rubocop-rspec は任意）。
  - API 層のテストに `rack-test` (`Rack::Test::Methods` + `NetomoxExp::NetomoxRestApi`) を使用。
- **ネットワーク/外部依存なし**で実行できること。`netomox` gem は必須だが、これは bundle 済み前提。
- 実行: `bundle exec rspec`（Rakefile に `RSpec::Core::RakeTask` を追加し `rake spec` も可）。
- **テスト対象外**: `model_defs/`（プロトタイプ）、`lib/test_*.rb`（後述の通り spec へ移行後に廃止検討）。
- **ディレクトリ構成**
  ```
  spec/
    spec_helper.rb          # $LOAD_PATH に repo root と lib を追加、tmp dir 用 ENV 設定
    support/
      tmp_dirs.rb           # MDDO_TOPOLOGIES_DIR / MDDO_USECASES_DIR を Dir.mktmpdir に向ける helper
      topology_fixtures.rb  # fixture 読み込み helper
    fixtures/
      queries/mini/...      # 最小 Batfish CSV 一式（手書き 2〜3 ノード）
      queries/mddo-fw/...   # 実データのコピー (約 108KB) ← FW 用
      topologies/*.json     # 期待値 (golden) 兼 入力
      usecases/...          # params.yaml 等
    topology_builder/ convert_namespace/ convert_topology/ static_verifier/
    usecase_deliverer/ api/
  ```
- **注意**: `queries/` `topologies/` は自動生成ディレクトリで編集不可 → リポジトリ直下を参照せず、
  **spec/fixtures にコピーして固定**する（生成物の変動でテストが壊れないようにする）。
  `configs/mddo-fw` 由来の実データは小さい (queries 108KB / topology 104KB) ので fixture 化可能。
- 定数が load 時に `ENV.fetch` で確定する（`app.rb` の `TOPOLOGIES_DIR` 等、`helpers_usecase.rb` の `USECASE_DIR`）。
  → `spec_helper.rb` で **require より前に** ENV を tmp dir に設定する。

## テスト対象と優先度

### P0: 純粋ロジック（ユニットテスト、最優先）— 近期に修正が入り回帰リスクが最も高い

| 対象 | 主なテスト観点 |
|---|---|
| `convert_namespace/namespace_convert_table/term_point_name_table.rb` | cRPD の `ethN.0`/`ethN` 連番、vSRX の l3_model/l1_agent/l1_principal 3 値。`build_firewall_eth_map`: management=eth1, control=eth2, fabric=eth3, データポート eth4〜、**HA パートナー側 FPC (ge-7/*) を別グループで eth4 から再採番**（コミット 9464d18 の回帰テスト）。同一物理ポートの複数サブIF が同じ ethM を共有。fabric エントリ (`ge-0/0/0` サフィックスなし)。`interface_sort_key` の若番ソート (ge-0/0/10 > ge-0/0/2)。`reverse_lookup` / `key?` |
| `convert_table.rb`, `convert_table_base.rb` | `extract_l3_firewall_node_names`（`flag: ["firewall"]` による判定）、`firewall_node?`、`to_hash` → `reload` の往復一致 |
| `node_name_table.rb`, `ospf_proc_id_table.rb`, `static_route_tp_table.rb` | ノード名変換・方向 (original→emulated / emulated→original)、静的ルート next-hop（cRPD は `dynamic`、FW は JunOS 名保持） |
| `namespace_converter.rb` | topology JSON 入力 → 変換後の node/tp/link/support 名が期待通り。変換 → 逆変換で元に戻る (round-trip)。`rewrite_tp_supports`, `rewrite_link`, `find_next_hop_interface` |
| `convert_topology/containerlab_converter.rb` | `select_node_data` の優先順位 (containerlab_nodes > l3_preallocated_resources > cRPD デフォルト)、`unique_links`（双方向リンクの片側化）、`firewall_primary_node?`、`make_fabric_link` / `fabric_link_data`（primary:eth3 ↔ secondary:eth3）、`startup-config` が proxmox ノードに付かないこと |
| `convert_topology/batfish_converter.rb` | layer1_topology.json 形式への変換（小 fixture で golden 比較） |

### P1: トポロジ生成・検証（fixture ベース / golden master）

| 対象 | 主なテスト観点 |
|---|---|
| `topology_builder/csv_mapper/*` | 各 CSV → record 変換。特に `table_base.rb` の `parse_array_string`（`[...]` / 数字カンマ区切り / 空 / 不正文字列で StandardError）、`true_string?`、`extract_interfaces`。`eval` 使用箇所のため**悪意ある入力に対する挙動を明文化**（不正形式は例外） |
| `topology_builder` (`l1/l2/l3/ospf/bgp_proc_data_builder`, `l3_segment_ledger`) | mini CSV fixture → `generate_data` の結果を golden JSON と比較（ネットワーク種別・ノード数・リンク対称性など構造的アサーションを併用し、golden 更新時の見落としを防ぐ）。`JUNOS_INTERFACE_REGEXP` / `LO_INTERFACE_REGEXP` の表形式テスト |
| `topology_builder` + mddo-fw 実データ | FW (`flag: firewall`) ノードが生成されること、HA pair 属性 |
| `static_verifier/*` | 正常 topology → 指摘 0 件。意図的に壊した topology（片方向リンク、TP 無しノード、孤立ノード、重複リンク）→ 期待する level (`fatal/error/warn`) とメッセージ |
| `usecase_deliverer/iperf_command_generator.rb` | ポート採番 (5201 起点、client_node ソート)、scale 計算 |
| `usecase_deliverer/external_as_topology/tiny_ipam.rb` ほか | IP 割当ての一意性・枯渇、BGP/iBGP link 生成（小入力） |
| `layer3_preallocated_resource_builder.rb` | params.yaml → 予約リソース |

### P2: API 層（rack-test による統合テスト、tmp dir 使用）

`Rack::Test` で `NetomoxExp::NetomoxRestApi` を直接叩く。

| エンドポイント | テスト観点 |
|---|---|
| `POST/GET /topologies/:nw/:ss/topology` | 生成 (queries fixture から) と登録・取得 |
| URL マッチ順序 | `/layer_type_:layer_type` が `/:layer` より先にマッチ（CLAUDE.md の制約の回帰） |
| `DELETE /topologies/:nw/:ss` | snapshot dir ごと削除、存在しない場合の挙動 |
| `GET/POST/DELETE /topologies/:nw/:ss/ns_convert_table` | POST の 3 パターン（空 / usecase / `convert_table` 直接指定）、任意 snapshot (`original_*` / `emulated_*`) への保存 |
| ns_convert_table 前提 API | `converted_topology`, `containerlab_topology`, `batfish_layer1_topology`, `nodes`, `interfaces`, `config_params` が **table 無しで 404**、POST 後は 200 |
| `GET /usecases/:uc/:nw/:ss/topology` | blueprint JSON を返す／無ければ 404 |
| `containerlab_topology?usecase=` | params.yaml の `containerlab_nodes` が反映される |
| `GET /topologies/index`, `POST` | `_index.json` の読み書き |

- **self-call API** (`external_as_topology`, `iperf_commands` は `localhost:9292` に HTTP):
  WebMock 等は使わず `HTTPClient` 呼び出しをスタブ（`allow_any_instance_of` ではなく `Helpers` のメソッドを stub）。
  ポート hardcode の解消は本計画のスコープ外（別課題として記載のみ）。

### P3: 後回し / 対象外

- `model_defs/`（手書きプロトタイプ）
- YARD / rubocop（既存の `rake rubocop` を CI に追加するのみ）
- 実 Batfish / ContainerLab を使った E2E（playground 側 demo スクリプトの責務）

## 段階的導入ステップ

1. **基盤整備**: Gemfile に `rspec`, `rack-test` 追加（`group :test, optional: true`）、`.dockerignore` 更新、`.rspec`, `spec/spec_helper.rb`, `support/tmp_dirs.rb`、Rakefile の `spec` タスク。空の smoke spec (`require 'app'` が通る) で動作確認。`.rubocop.yml` に spec 用の Metrics 緩和 (`Metrics/BlockLength` を `spec/**/*` で除外)。
2. **P0**: fixture は `queries/mddo-fw` の実データから `ConvertTable` に必要な最小 topology JSON を作成（HA ペア fw-1/fw-2 + cRPD 数ノード）。TermPointNameTable → ConvertTable → NamespaceConverter → ContainerLabConverter の順に実装。
3. **P1**: mini CSV fixture と golden JSON。golden 更新用に `UPDATE_GOLDEN=1 bundle exec rspec` で再生成できる helper を用意（差分は必ずレビュー）。
4. **P2**: API 統合テスト。
5. **CI**: 別 workflow `.github/workflows/test.yaml` を追加（詳細は「CI」節）。
6. **既存 `lib/test_*.rb` の扱い**: 内容を spec に移行した後、削除するか `script/` に移すかを別途判断（本計画では触らない）。
7. **ドキュメント**: CLAUDE.md の「テスト」節を更新（`bundle exec rspec` の実行方法、fixture/golden の更新手順）。

## 成功基準

- `bundle exec rspec` がローカル・CI で数秒〜数十秒で完走する（外部サービス不要）。
- P0 の対象ファイルは主要分岐（FW/cRPD、primary/secondary、original/emulated）を網羅。
- 直近修正（コミット 9464d18: パートナー側ポート再採番）を戻すとテストが落ちることを確認する（mutation 的確認）。
- 目安カバレッジ: `convert_namespace/` `convert_topology/` で行カバレッジ 80%+（SimpleCov は任意で導入）。

## 検証方法

- `bundle exec rspec` / `bundle exec rake spec` / `bundle exec rake rubocop`
- 意図的に `build_firewall_eth_map` のパートナー FPC 分離を壊して spec が失敗することを確認。
- `POST /topologies/:nw/:ss/ns_convert_table` を叩いて得た実出力と fixture の golden が一致することを、playground の `21_generate_conduit.sh` 実行結果（`topologies/mddo-fw/*/ns_convert_table.json`）と一度手動で突き合わせる。

## 確定事項（ユーザー指示）

1. **テストフレームワークは RSpec**（minitest は使わない）。
2. **CI は GitHub Actions で実行**する（下記「CI」節）。
3. **コンテナビルドにテスト関連のファイル・コンポーネントを含めない**（下記「コンテナへの非混入」節）。

## CI（GitHub Actions）

テストは `.github/workflows/test.yaml` に定義し、`.github/workflows/actions.yaml`（`on: push`、docker build & push）から reusable workflow として呼び出す。
**CI (rubocop + rspec) が成功した場合のみ image を build / push する** (`build_and_push` は `needs: test`)。

- トリガ: `pull_request` (単体実行) と `workflow_call` (`actions.yaml` の `test` ジョブ経由。push 時はこちら。二重実行を避けるため `test.yaml` 自体は push を購読しない)
- 呼び出し側ジョブに `permissions: contents: read, packages: read` が必要 (reusable workflow は呼び出し側の権限を超えられない)
- steps: `actions/checkout` → `ruby/setup-ruby`（ruby 3.4、`bundler-cache` は GitHub Packages 認証が必要なため `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` を env に渡してから使用）→ `bundle exec rspec` → `bundle exec rake rubocop`
- 認証: `BUNDLE_RUBYGEMS__PKG__GITHUB__COM: ${{ github.repository_owner }}:${{ secrets.GITHUB_TOKEN }}`、`permissions: contents: read, packages: read`（既存 docker build が同じ GITHUB_TOKEN で gem を取得しているため同方式で可）
- bundle は `BUNDLE_WITH=test`（または `bundle config set with test`）でテスト用 group を有効化
- docker build の job は `needs: test` (確定。テスト失敗時はイメージを push しない)
- 失敗時に RSpec 出力を確認できるよう `--format documentation` / JUnit は不要（最小構成）

## コンテナへの非混入

現状の `Dockerfile` は `COPY . /netomox-exp` + `bundle install`（group 指定なし）、ENTRYPOINT は `rerun`（Gemfile の development group）を使うため、次の対応が必要。

1. **Gemfile**: テスト用 gem は新設の `group :test, optional: true` に置く（`rspec`, `rack-test`, 必要なら `simplecov`）。
   `optional: true` により、通常の `bundle install`（Dockerfile）では**インストールされない**。CI とローカル開発のみ `BUNDLE_WITH=test`（または `bundle config set --local with test`）で有効化。
   `development` group（`rerun` 等）は ENTRYPOINT が使うので現状維持。
2. **`.dockerignore`** に追記（`COPY .` でイメージに入らないように）:
   ```
   # tests
   spec
   .rspec
   lib/test_*.rb
   ```
   （`.github` は既に除外済み。`.rubocop.yml` も既に除外）
3. **Gemfile.lock**: `.dockerignore` で除外されているため、コンテナは lock なしで resolve される。optional group の gem は lock には入るが、コンテナ側では install されない。→ Dockerfile は変更不要。確認としてビルド後に `docker run --rm <image> bundle exec ruby -e 'require "rspec"'` が **失敗する**こと、および `ls /netomox-exp/spec` が存在しないことを検証する。
4. **ランタイムコードにテスト用 require を入れない**: `lib/` 配下に spec 専用の helper / fixture を置かない（すべて `spec/` 内）。`lib/test_*.rb` は .dockerignore で除外（spec 移行後に削除を別途判断）。

## 未確定事項

- なし（docker build を test 成功に依存させる点は確定）

## Golden master 方針（確定: 構造アサーション中心）

- **基本は構造アサーション**: ノード/リンク数、TP 名の変換結果（例: fw-1 の `ge-0/0/1.0` → `l1_principal: eth4`）、リンクの対称性、`flag: ["firewall"]`、HA pair 属性、fabric リンク（primary:eth3 ↔ secondary:eth3）など、ルール単位で個別に assert する。
- **全文 golden は最小限**: `ns_convert_table`（mini fixture、約200行以内）のみ。キー順・配列順はソートして正規化して比較。
- **実データ (mddo-fw) の topology 全体は全文比較しない**（構造アサーションのみ）。
- 全文 golden を更新する場合は `UPDATE_GOLDEN=1 bundle exec rspec` で再生成し、差分を必ずレビューする。
- 上記により、P1 の「golden JSON と比較」は「構造アサーション中心（変換テーブルのみ全文 golden）」と読み替える。

## 実装結果（計画との差分）

- 構成: `spec/{convert_namespace,convert_topology,topology_builder,static_verifier,usecase_deliverer,api}`、`spec/support/{fixtures,golden,converters,api_helper}.rb`
- **fixture は mini ではなく mddo-fw 実データ (queries / topology) のコピー**を使用（小さく、FW HA の全ケースが含まれるため）。
  ghost ポート等の追加ケースは、テスト内でトポロジを加工して作る。
  全文 golden は `spec/fixtures/golden/ns_convert_table_subset.json`（代表 3 ノード）のみ。
- 追加: `emulated_asis` topology fixture により「original → `NamespaceConverter#convert` が emulated と一致する」ラウンドトリップを検証。
- Gemfile: `group :test, optional: true`。`.dockerignore` に `spec` / `.rspec` / `lib/test_*.rb` を追加。
- 実装中に見つかった問題:
  - **修正済み**: `TopologyConverterBase#initialize` のエラーメッセージが未定義変数 `file` を参照し、本来の `StandardError` ではなく `NameError` になっていた (`lib/convert_topology/topology_converter_base.rb`)。
  - **修正済み (後続対応)**:
    1. `GET .../topology/upper_layer3` が `UpperLayer3Filter` 未修飾参照で NameError (`ConvertNamespace::UpperLayer3Filter` が必要)。model-conductor が使用している API。
    2. `GET .../topology/verify` が `/:layer` にシャドーされ 404 (マウント順: `Layer` が `VerifyLayers` より先) → `VerifyLayers` を `Layer` より前にマウント。上記 1 は `ConvertNamespace::UpperLayer3Filter` に修飾して修正。対応する spec の `pending` は外した。
  - **未修正 (観察のみ)**: `Layer3Verifier` は `require 'ipaddress'` を持たず (アプリ経由では builder が先に読み込む)、リンクが片方向欠落した topology では `NoMethodError` で落ちる (API は 500 を返す)。
- `httpclient` 2.8.3 は Ruby 3.4 で `mutex_m` が必要。ローカルの `Gemfile.lock` (git 管理外) は `bundle update httpclient` で 2.9.0 に更新した。

## 残課題

### 未確認 (実環境での検証が必要)

- [ ] **CI が未実行**: `.github/workflows/test.yaml` は GitHub Actions で未実行。
  GitHub Packages 認証 + `bundler-cache` の組み合わせ、および `Gemfile.lock` が git 管理外のため CI では毎回依存を新規解決する点
  (`httpclient` 2.9.0 が Ruby 3.4 で読み込めるか) を要確認。
- [ ] **docker build が未確認**: `.dockerignore` の効果、イメージ内に rspec / rack-test / `spec/` が無いことを未検証
  (確認手順は「コンテナへの非混入」節の 3)。
- [ ] **未コミット**: ブランチ `add-rspec-tests` 上の変更。lib の修正 (`topology_converter_base.rb`, `topology.rb`) はテスト追加とは別コミットに分けるのが望ましい。

### テストの穴

- [ ] **BGP / OSPF**: mddo-fw fixture に BGP が無いため `bgp_proc_data_builder`、`BgpProcVerifier` / `BgpAsVerifier`、`ospf_data_builder` の個別ロジックはほぼ未テスト。BGP を含む fixture (例: `mddo-bgp`) の追加が必要。
- [ ] **external_as_topology 系**: `layer3_data_builder*`, `bgp_*_data_builder*`, `int_as_data_builder` と `layer3_preallocated_resource_builder` が未テスト。
  `external_as_topology` / `iperf_commands` API は `localhost:9292` への self-call があり未テスト (スタブ方針は P2 の注記参照)。
- [ ] **静的ルート変換**: fixture に静的ルートが無く `StaticRouteTpTable` (cRPD は `dynamic`、FW は元の名前保持) が未テスト。
- [ ] **`eval` の入力テスト**: `parse_array_string` は不正形式での例外までを確認。悪意ある入力に対する挙動は未テスト。
- [ ] **カバレッジ未計測**: SimpleCov 未導入 (成功基準の 80% 以上は未確認)。
- [ ] **`lib/test_*.rb`**: 手動スクリプトのまま。spec へ移行して削除するか `script/` に移すか未決定。
- [ ] **mini fixture / 全文 golden の範囲**: 計画の mini CSV fixture は作らず実データのコピーで代替。全文 golden は `ns_convert_table` の代表 3 ノードのみ。

### 運用上の課題

- [ ] **fixture の追従**: `spec/fixtures/` は mddo-fw のコピー。デモ側の出力が変わっても自動追従せず、更新手順が無い
  (`UPDATE_GOLDEN` の対象は golden のみ)。
- [x] **docker build と test の依存 → 対応済み**: `actions.yaml` の `build_and_push` を `needs: test` (reusable workflow `test.yaml`) にした。実走は未確認。
- [ ] **rubocop-rspec 未導入**: spec の lint は標準 rubocop のみ。

### 調査が必要な点

- [x] **`flag: ["firewall"]` の欠落 → 修正済み**: netomox gem (0.13.0) はノードのトップレベル `flag` を扱わないため、
  `NamespaceConverter#convert` / `UpperLayer3Filter#filter` の出力から消えていた。
  変換前・後どちらでも常に残る仕様とし、`NamespaceConverterBase` が元の topology JSON からノードの `flag` を保持し、出力へ復元する
  (`extract_node_flags` / `restore_node_flags`)。`flag` は FW 以外の値も含めてそのまま保持する。
  これにより `emulated_*` の topology から ns_convert_table を生成しても FW ノードを判定できる。
  spec: `namespace_converter_spec.rb` (変換前後・逆変換)、`upper_layer3_filter_spec.rb`、`convert_table_spec.rb` (emulated からの表生成)。
  `spec/fixtures/topologies/mddo-fw/emulated_asis.topology.json` は復元後の出力で更新した (差分は FW 4 ノードの `flag` のみ)。

### 既知の未修正事項 (コード側)

- [ ] `Layer3Verifier`: `require 'ipaddress'` が無い。セグメントノードのリンクが片方向のみ欠けたトポロジで `NoMethodError` (API は 500)。
- [ ] self-call のポート hardcode (`localhost:9292`): 本計画のスコープ外。

### 優先順位 (案)

1. CI の実走確認 (上記「CI が未実行」)
2. docker build の確認 / コミット整理
3. BGP / external_as 系のテスト追加 (BGP fixture 用意)
4. カバレッジ計測、`lib/test_*.rb` の整理
