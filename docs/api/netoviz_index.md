# netoviz index API

旧 netoviz が使うインデックス (表示対象のネットワーク・スナップショットの一覧) を読み書きする API。
netoviz2 向けの API は [netoviz2.md](netoviz2.md) を参照。

## インデックスの取得

* GET `/topologies/index`

```shell
curl http://localhost:9292/topologies/index
```

## インデックスの保存

* POST `/topologies/index`
  * `index_data`: netoviz index データ

```shell
# netoviz_index.json
# -> { "index_data": <netoviz index data> }
curl -X POST -H "Content-Type: application/json" -d @netoviz_index.json \
  http://localhost:9292/topologies/index
```
