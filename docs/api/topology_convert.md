# エミュレーション環境向けトポロジ変換 API

トポロジデータの指定レイヤを、Batfish や ContainerLab の入力形式に変換する API。

> **注意:** 名前空間変換後の名前を使う。先に変換テーブルを作成しておくこと ([ns_convert_table.md](ns_convert_table.md))。

## Batfish 用 layer1_topology.json への変換

指定したレイヤのトポロジを、Batfish 用の `layer1_topology.json` に変換する。

* GET `/topologies/<network>/<snapshot>/topology/<layer>/batfish_layer1_topology`

```shell
curl -s http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/batfish_layer1_topology
```

## ContainerLab 用 clab-topo.yaml への変換

指定したレイヤのトポロジを、ContainerLab 用の `clab-topo.yaml` に変換する。

* GET `/topologies/<network>/<snapshot>/topology/<layer>/containerlab_topology`
  * この API は JSON を返す。containerlab で使うには YAML に変換すること。
  * containerlab 全体のオプション
    * `env_name`: [任意] containerlab の環境名 (省略時はスナップショット名)
  * FW HA クラスタのペア (primary/secondary) のメンバーは、固定のリンク `eth2` (control) と `eth3` (fabric) で直接つなぐ。
    ペアの相手ノードがトポロジ内に見つからない場合は追加しない。
  * ルータノード (cRPD) のオプション
    * `image`: イメージ名 (`containerlab_nodes` で上書きされないノードに使う)
    * `bind_license`: [任意] ライセンスファイルをコンテナにバインドする docker volume マウント文字列
    * `license`: [任意] ライセンスファイルのパス
  * endpoint ノード (linux endpoint) のオプション
    * `endpoint_image`: [任意] イメージ名 (デフォルト: `ghcr.io/ool-mddo/ool-iperf:main`)
    * endpoint ノードは `kind: linux` で出力し、`exec` コマンドをトポロジから生成する。
      各 term-point について `ip addr add <ip> dev <intf>` と `ip link set dev <intf> mtu 1500`、
      各 static route について次のコマンドを生成する
      (`0.0.0.0/0` は `ip route del default` + `ip route add default via <next-hop>`、
      それ以外は `ip route add <prefix> via <next-hop>`)。生成するコマンドが無ければ `exec` は出力しない。
  * ノード単位の上書きのオプション
    * `usecase`: [任意] `params.yaml` から `containerlab_nodes` の定義を読み込むユースケース名
      * `params.yaml` の `containerlab_nodes` は、ノード名をキーとするノード単位の containerlab 定義。
        `kind`、`image`、`env`、`binds`、`ports`、`labels` を指定でき、cRPD のデフォルトより優先される。
        主に FW (proxmox ベース) などの cRPD 以外のノードを定義するために使う。

```yaml
# 例: usecases/<usecase>/<network>/params.yaml
containerlab_nodes:
  site-a-fw-1:
    kind: linux
    image: 'rtedpro/proxmox:9.2.3'
    env:
      container: docker
    binds:
      - /dev/kvm:/dev/kvm
    ports:
      - "8006:8006"
    labels:
      ansible-group: junos
      redundant: act
```

```shell
curl -s "http://localhost:9292/topologies/mddo-ospf/emulated_asis/topology/layer3/containerlab_topology?image=crpd:22.1R1.10&bind_license=license.key:/tmp/license.key:ro" \
  | ruby -r json -r yaml -e "puts YAML.dump_stream(JSON.parse(STDIN.read))"

# ノード単位の上書き (FW ノード)
curl -s "http://localhost:9292/topologies/mddo-fw/original_asis/topology/layer1/containerlab_topology?image=ghcr.io/ool-mddo/crpd:latest&usecase=refocus_topology" \
  | ruby -r json -r yaml -e "puts YAML.dump(JSON.parse(STDIN.read))"
```

### ノード定義の優先順位

1. `containerlab_nodes` に定義がある場合は、その定義を使う (FW / proxmox ノード)
2. `l3_preallocated_resources` の `emulated_params` に定義がある場合は、そちらを使う (Nokia SR-SIM など)
3. どちらも無い場合は、`juniper_crpd` のデフォルトを使う (cRPD ノード)

実装の詳細は [CLAUDE.md](../../CLAUDE.md) の「ContainerLab トポロジ変換: FW ノード (proxmox) 対応」を参照。
