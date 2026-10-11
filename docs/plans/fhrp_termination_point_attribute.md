# Plan: queries の VRRP/HSRP 情報を layer3 TP の `fhrp` 属性として付与する

(状態: 実装済み (ブランチ `v1.20.0-dev`、未コミット)。Gemfile の制約引き上げと CI 対応は netomox 公開後)

### 実装結果

- 追加: `lib/topology_builder/csv_mapper/fhrp_props_table.rb` (`FhrpPropertiesTable` / `FhrpPropertiesTableRecord#to_attribute`)
- 変更: `lib/topology_builder/l3_data_builder.rb` (`add_l3_tp` → `l3_tp_attribute`。`fhrp` がある TP にのみ `fhrp` を付与)
- fixture: `spec/fixtures/queries/mddo-fw-fhrp/original_asis` (現行 queries のコピー)
- spec 追加 (18 examples): `spec/topology_builder/csv_mapper_fhrp_spec.rb`, `spec/topology_builder/topology_builder_fhrp_spec.rb`,
  `spec/static_verifier/static_verifier_fhrp_spec.rb`
- docs 更新: `docs/architecture.md`, `docs/test_plan.md`
- 確認:
  - `RUBYLIB=/home/hagiwara/ool-mddo/netomox/lib BUNDLE_WITH=test bundle exec rspec` → 163 examples, 0 failures (従来 145 + 18)
  - `rake rubocop` 違反なし
  - 実環境 `21_generate_conduit.sh` → 正常終了。`fhrp` を持つ L3 TP: `original_asis` 12 / `emulated_asis` 12 (TP 名は `eth3.0` 等に変換されて保持)。
    `*_conduit*` は 0 (Phase E の対象)。全 snapshot で、`fhrp` を除いた topology.json は実行前と同一。

### Phase D (名前空間変換での保持) の結果

- 調査: netomox-exp 内で L3 TP の属性を扱う箇所は次のとおり。いずれも `Netomox.convert_attr_topo2dsl(tp.attribute.to_data)` で
  属性を丸ごと変換する方式で、netomox 0.14.0 の `fhrp` 対応により `fhrp` が保持される。**lib の変更は不要**だった。
  - `NamespaceConverter#rewrite_term_point` (original → emulated。`fhrp` 内に node/TP 名は無いので名前変換は不要)
  - `UpperLayer3Filter#filter_term_point`
  - API (`helpers.rb` の `_node_hash` / `_interfaces_hash`, `config_params.rb`): `attribute.to_data` を返すため、
    `nodes` / `interfaces` の `attribute` に `fhrp` が含まれる (追加のみ。`config_params` は `ip_addrs`/`description` のみ参照で影響なし)
  - `usecase_deliverer/external_as_topology/*` は外部 AS の TP を新規構築する (既存 TP の属性は触らない) ので対象外
- spec 追加 (5 examples): `spec/convert_namespace/namespace_converter_fhrp_spec.rb`, `spec/convert_namespace/upper_layer3_filter_fhrp_spec.rb`
  (全 12 TP の `fhrp` が変換後の名前 (`ethN.0`) で一致、`fhrp` の無い TP に付かない、他の属性が保持される)
- 確認: rspec 168 examples, 0 failures (従来 163 + 5)、rubocop 違反なし。実環境の
  `GET /topologies/mddo-fw/emulated_asis/topology/layer3/interfaces?node_name=site-b-cr-2` で
  `eth3.0` (reverse `ge-0/0/2.0`) / `eth4.0` (reverse `ge-0/0/3.0`) の `attribute.fhrp` を確認。
- README の `interfaces` API に `fhrp` を含む旨の注記を追加。

### 確認事項の決定 (2026-10-11)

- CSV (`vrrp_props.csv` / `hsrp_props.csv`) が無いときは空として扱う。
- TP は `(node, interface)` だけで引く (`source-address` では絞り込まない)。
- fixture は現行 queries のコピー `spec/fixtures/queries/mddo-fw-fhrp/original_asis` を追加する (そのままコピー。116KB)。
  内容: 18 ノード、`vrrp_props.csv` 12 行 (3 サイトの cr-1/cr-2 × `ge-0/0/2.0` (group 1) / `ge-0/0/3.0` (group 2)、
  cr-1 が priority 150、cr-2 が 100)、`hsrp_props.csv` はヘッダのみ。VRRP の 12 行はすべて `ip_owners.csv` の (Node, Interface) と一致する。
- `fhrp` は `(protocol, group_id)` でソートする。
- テストはローカル実行のみで進める。CI は netomox 公開後に対応する (Gemfile の制約引き上げもその時)。

playground の `docs/work/plans/fhrp_termination_point_attributes.md` の Phase C に相当する。全体計画・データモデルはそちらを参照。
この文書は netomox-exp 側の実装範囲だけを扱う。

## 目的

Batfish クエリ結果 `vrrp_props.csv` / `hsrp_props.csv` から、TopologyBuilder の layer3 term-point に
`fhrp` 属性 (`mddo-topology:l3-termination-point-attributes` の `fhrp` 配列) を付与する。
スコープは topology.json の生成まで。保持 (ns_convert 等) の確認は Phase D、conduit は Phase E。

## 前提・現状 (調査結果)

- ブランチ: 現在 `v1.19.2-dev` (clean、`origin/v1.19.2-dev` と同期)。ここから **`v1.20.0-dev`** を切って作業する。
- 依存: netomox gem は `Gemfile` で `>= 0.13.0`。fhrp 対応は netomox `v0.14.0-dev` (commit `c1d349f`、未公開・未バージョン更新)。
  ローカルでは playground の `docker-compose.override.yaml` が netomox-exp コンテナにローカルの netomox を bind mount している。
- **ローカルでの spec 実行:**
  - ホストで `BUNDLE_WITH=test bundle exec rspec` が動く (現状 145 examples, 0 failures)。
  - fhrp 対応版 netomox を使うには `RUBYLIB=/home/hagiwara/ool-mddo/netomox/lib` を付ける。動作確認済み
    (`$LOADED_FEATURES` が local の `netomox/version.rb` を指し、`Netomox::Topology::MddoFhrp` が見える)。
    → `RUBYLIB=/home/hagiwara/ool-mddo/netomox/lib BUNDLE_WITH=test bundle exec rspec`
  - 実装時に `gem` を差し替える必要はない (Gemfile / Gemfile.lock は触らない。`Gemfile.lock` は git 管理外)。
- L3 TP の生成箇所: [l3_data_builder.rb](../../lib/topology_builder/l3_data_builder.rb)
  - `add_l3_tp(rec, l3_node, l2_node_name, l2_tp_name)` が `l3_tp.attribute = { ip_addrs:, description: }` を設定する。
    `rec` は ip_owners の 1 行 (`rec.node`, `rec.interface`, `rec.ip`, `rec.mask`)。
    **属性 Hash を丸ごと代入するので、`fhrp` もここで同時に入れる必要がある** (後から別の場所で足すなら `merge` が必要)。
  - `add_l3_tp` は同じ TP に対して複数回呼ばれうる (セグメントごと・unlinked TP 走査) が、毎回同じ内容を代入するので冪等。
  - loopback TP (`add_l3_loopback_tps`) と segment ノードの TP (`add_l3_seg_tp`) は FHRP 対象外。
  - `rec.node` は Batfish のノード名 (VRF ノードでも VRF 抜きの元ノード名)。
    `rec.interface` は VRRP の `Interface` (`node[ifname]` の ifname) と同形式 (`ge-0/0/2.0`)。
    LAG 親経由で ip_owner が引かれる場合も `rec.interface` を使えば VRRP の名前と一致する。
- CSV の読み込み: `lib/topology_builder/csv_mapper/*_table.rb`。`TableBase#initialize` が `CSV.table("#{target}/#{file}")`
  で読み、`EdgeBase` が `node[ifname]` を分解し、`true_string?` / `parse_array_string` が型変換を担う。
  CSV が無いと `CSV.table` が `Errno::ENOENT`。
- `ExpandedL3DataBuilder` は L3 TP の `attribute` をそのまま参照コピーするため、追加の対応は不要 (`layer3exp` は出力に含まれない)。
- 実データ (`queries/mddo-fw/original_asis/vrrp_props.csv`): 12 行 (3 サイト × cr-1/cr-2 の 6 ノード × 2 グループ)、
  `Interface` は `site-b-cr-1[ge-0/0/2.0]` 形式。`hsrp_props.csv` はヘッダのみ。
- 手元の現行 queries を新 netomox で `generate_data` すると正常に動く (0.8 秒、リグレッションなし) ことは確認済み。

## 実装内容

### 1. CSV マッパ

**新規** `lib/topology_builder/csv_mapper/fhrp_props_table.rb`:

- `FhrpPropertiesTableRecord < TableRecordBase`
  - `node`, `interface` (`EdgeBase` で分解)、`group_id` (Integer)、`virtual_addresses` (`parse_array_string`)、
    `source_address`、`priority` (Integer)、`preempt` / `active` (`true_string?` で Boolean)、`protocol` ('vrrp' / 'hsrp')。
  - CSV の値は `CSV.table` の数値変換で整数になる列もあるが、文字列で来ても `to_i` で扱えるようにしておく。
- `FhrpPropertiesTable < TableBase`
  - 1 つのクラスで vrrp / hsrp の両 CSV を読む (両 CSV は同一スキーマ)。`initialize(target)` で
    `vrrp_props.csv` (protocol 'vrrp') と `hsrp_props.csv` (protocol 'hsrp') を読み、`@records` に連結する。
    (`TableBase#initialize` は 1 ファイル前提のため、クラス内で `CSV.table` を 2 回呼ぶか、`TableBase` を継承せずに独立させる。実装時に決める)
  - **CSV が存在しない場合は空として扱う** (古い queries との後方互換。docs/architecture.md の「CSV 必須依存」の例外として明記)。
    ファイルが無いときは `@logger` に info/warn を出す。
  - `find_all_records_by_node_intf(node, intf)` → 該当インタフェースの全グループ (配列、無ければ `[]`)。

### 2. L3 データビルダ

[l3_data_builder.rb](../../lib/topology_builder/l3_data_builder.rb):

- `require_relative 'csv_mapper/fhrp_props_table'`、`initialize` で `@fhrp_props = CSVMapper::FhrpPropertiesTable.new(target)`。
- `add_l3_tp` の属性代入で、該当レコードがあるときだけ `fhrp` キーを足す:
  ```ruby
  attr = { ip_addrs: ["#{rec.ip}/#{rec.mask}"], description: ... }
  fhrp = fhrp_attribute(rec.node, rec.interface)
  attr[:fhrp] = fhrp unless fhrp.empty?
  l3_tp.attribute = attr
  ```
- `fhrp_attribute(node, interface)` (private): レコードを PseudoDSL 用 Hash の配列にする。
  キーは netomox DSL のキーワード引数に合わせる:
  `{ protocol:, group_id:, virtual_addresses:, priority:, preempt:, source_address:, active: }`。
- FHRP を持たない TP には `fhrp` キーを付けない (出力 topology.json の差分を FHRP 追加分だけにする)。
- 並び順: CSV の出現順ではなく `(protocol, group_id)` でソートして安定させる (Batfish の行順が実行ごとに変わっても topology.json が変わらないようにする)。
- 付与対象は `add_l3_tp` のみ (loopback / segment TP は対象外)。
- `Metrics/ClassLength` などの rubocop 制約は既存の disable コメント内で収まる見込み (超える場合はメソッドを小さく保つ)。

### 3. 他の変更が不要なことの確認

- `ExpandedL3DataBuilder`: 属性を参照コピーするだけ。
- `static_verifier/layer3_verifier.rb`: `ip_addrs` 等しか見ない。`fhrp` で壊れないことを spec で確認。
- `config_params.rb` (API): `tp.attribute.ip_addrs`/`description` のみ参照。影響なし (`fhrp` を出す必要は今回なし)。

## テスト計画

既存 spec の方針 (`docs/test_plan.md`、`spec/fixtures` に固定コピーを置く、`FixtureHelper.path`) に従い、機能ごとに専用ファイルを作る。

### fixture

既存の `spec/fixtures/queries/mddo-fw/original_asis` は 8 ノード (br/fw のみ) の古いデータで、cr ノード (VRRP 持ち) が無い。
他の spec が件数・ノード数をアサートしているため**変更しない**。代わりに現行 queries のコピーを別名で追加する:

- `spec/fixtures/queries/mddo-fw-fhrp/original_asis/*.csv` (playground の `queries/mddo-fw/original_asis` の現行コピー、約 156KB、
  18 ノード。`vrrp_props.csv` 12 行と `hsrp_props.csv` ヘッダのみを含む)
- HSRP は実データが無いので、CSV マッパの spec 用に手書きの小さな `hsrp_props.csv` を spec 内の一時ファイル/インライン fixture で作る。

### spec

| ファイル | 内容 |
|---|---|
| `spec/topology_builder/csv_mapper_fhrp_spec.rb` | `FhrpPropertiesTable`: vrrp 12 行を読める、各フィールドの型 (Integer / Boolean / Array)、`protocol` が付く、`node[ifname]` 分解、`find_all_records_by_node_intf` (複数グループ・無し)、vrrp/hsrp が両方あるとき連結される (hsrp は手書き一時 CSV)、CSV が存在しないとき空になる、ヘッダのみの CSV が空。 |
| `spec/topology_builder/topology_builder_fhrp_spec.rb` | `TopologyBuilder.generate_data(mddo-fw-fhrp)` の layer3: `site-b-cr-1` の `ge-0/0/2.0` に `fhrp` (`protocol: vrrp, group-id: 1, virtual-address: ["192.168.101.1"], priority: 150, preempt: true, source-address: "192.168.101.2/24", active: true`)。cr-2 側は priority 100 (HA ペアの対応)。`ge-0/0/3.0` は group 2。`fhrp` を持つ TP が全 layer3 TP のうち期待する数 (CSV の 12 行に対応する TP のみ)で、それ以外 (br/fw/segment/loopback) の TP に `fhrp` キーが無い。出力が `Netomox::Topology::Networks` でパースでき `MddoFhrp` が取れる (netomox との結合)。`generate_data` を 2 回実行しても結果が同一 (順序の安定)。 |
| 既存 `topology_builder_spec.rb` | 変更しない。`mddo-fw` 古い fixture に vrrp_props.csv が無くても通ること (CSV 欠落時の後方互換) の回帰テストとして兼ねる。 |
| `spec/static_verifier/` | `fhrp` を持つ topology でも `Layer3Verifier` が例外を出さず指摘 0 件であること (fixture の layer3 に `fhrp` が載った topology を渡す)。 |

実行:

```bash
cd /home/hagiwara/ool-mddo/playground/repos/netomox-exp
RUBYLIB=/home/hagiwara/ool-mddo/netomox/lib BUNDLE_WITH=test bundle exec rspec
RUBYLIB=/home/hagiwara/ool-mddo/netomox/lib BUNDLE_WITH=test bundle exec rake rubocop
```

**CI の注意:** CI (`.github/workflows/test.yaml`) は GitHub Packages から netomox を取得する。
fhrp の spec は netomox 0.14.0 (公開後) が必要。公開前に push すると、`fhrp` 関連の spec が失敗する。
→ Gemfile の `netomox` 制約を `>= 0.14.0` に上げるのは、netomox の公開 (Phase B の最後に別途指示を受ける) とセットで行う。

## 動作確認 (実環境)

1. ローカル netomox を使ったままコンテナを使う (playground の override 構成で起動済み)。
2. `cd demo/candidate_model_ops && source demo_vars && ./21_generate_conduit.sh`
3. `topologies/mddo-fw/original_asis/topology.json` の layer3 を `jq` で確認:
   - `site-b-cr-1` の `ge-0/0/2.0` に `fhrp` がある。
   - FHRP を持たない TP に `fhrp` キーが無い。
   - 追加分以外の差分が無い (実行前の topology.json を退避して `diff`)。
4. `emulated_asis` にも `fhrp` が残っているか (Phase D の先取り確認。netomox が保持できていれば残る見込み)。
   `*_conduit*` では落ちる想定 (Phase E)。

## ドキュメント修正の調査結果

| ファイル | 要否 | 内容 |
|---|---|---|
| `docs/architecture.md` | **要修正** | (a) L141〜150 付近の Builder と CSV 依存の図で、`L3DataBuilder` の入力に `vrrp_props.csv`, `hsrp_props.csv` (任意) を追加。(b) L25 の CSV 一覧に追記。(c) L272「TopologyBuilder の CSV 必須依存」に、vrrp/hsrp は欠けても動く (空扱い) 例外を追記。 |
| `CLAUDE.md` | 要確認・小修正 | CSV の一覧や builder の記述があれば追記 (現状 grep では該当なし。`ディレクトリ構成の要点` は変更不要)。 |
| `docs/test_plan.md` | 要追記 | 「テスト対象と優先度」の P1 (`topology_builder/csv_mapper/*`, `topology_builder`) に fhrp の観点を追記。fixture に `mddo-fw-fhrp` を追加した旨を追記。 |
| `README.md` | 不要 | CSV 一覧・属性一覧の記述なし。 |
| YARD (`doc/`) | 不要 | git 管理外 (自動生成)。新クラス・メソッドに YARD コメントを付ける。 |
| playground `docs/work/plans/fhrp_termination_point_attributes.md` | 要更新 | Phase C の実施結果と、確定した設計 (CSV 欠落時は空扱い、ソート順) を反映。 |
| playground `docs/architecture.md` ほか | 確認 | queries の CSV 一覧を載せている箇所があれば追記 (grep では該当なし)。 |

## 実装ステップ (順序)

1. `v1.19.2-dev` から `v1.20.0-dev` を作成。
2. fixture 追加 (`mddo-fw-fhrp`) と CSV マッパ + spec (`csv_mapper_fhrp_spec.rb`)。
3. L3 データビルダの変更 + spec (`topology_builder_fhrp_spec.rb`、`static_verifier` 追加)。
4. 全 rspec / rubocop (netomox を `RUBYLIB` で差し替え)。
5. コンテナでの動作確認 (`21_generate_conduit.sh`)。
6. ドキュメント更新 (`docs/architecture.md`, `docs/test_plan.md`, playground の計画)。
7. コミット (バージョン更新・Gemfile の制約変更は公開時にまとめて)。

## 確認したい点 (回答済み。上の「確認事項の決定」を参照)

- **CSV 欠落時の挙動:** 空扱い (推奨、古い queries との後方互換) でよいか。それとも他の CSV と同様に必須とするか。
- **TP の特定方法:** `(node, interface)` だけで引く (推奨)。1 インタフェースに複数 IP がある場合は、現状 `add_l3_tp` が 1 つの IP しか持たないため
  `source-address` による絞り込みは不要と見る。それでよいか。
- **fixture:** 現行 queries のコピー `mddo-fw-fhrp` (約 156KB) を追加する方針でよいか。
- **ソート:** `(protocol, group_id)` で並べ替える方針でよいか。
- **Gemfile の制約:** `netomox >= 0.14.0` への引き上げは netomox 公開時にまとめて行う方針でよいか。
