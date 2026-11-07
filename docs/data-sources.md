# 使えるデータの調査

確認日: 2026-11-07(JST)。各 URL を 1〜数回だけ実際に取得して、形式・サイズ・応答のヘッダーを確かめた。サイズは HTTP の転送バイト数の実測(gzip で配信されるものは「転送 / 展開後」)。確かめられなかったことは最後の節に「未確認」としてまとめた。

**非公式**と書いたものは、提供元が API として公表していない(仕様の公開がなく、予告なく変わりうる)か、公的機関ではない民間のサービス。

## 1. 一覧

| 名前 | URL | 形式 | 更新 | 利用条件・出典表示 | データ量(実測) | ズーム | 公式/非公式 |
|---|---|---|---|---|---|---|---|
| 洪水浸水想定区域(想定最大規模)統合版 | `https://disaportaldata.gsi.go.jp/raster/01_flood_l2_shinsuishin_data/{z}/{x}/{y}.png`(国管理河川だけは `..._kuni_data`、都道府県別は `01_flood_l2_shinsuishin_pref_data/NN/`) | PNG 256px RGBA | 不定期(取得したタイルの Last-Modified は 2026-09-10) | 公共データ利用規約(PDL1.0)。出典「出典：「ハザードマップポータルサイト」」、加工したときは「「ハザードマップポータルサイト」を加工して作成」。都道府県管理の河川は許諾を得た県だけ。東京都の図面は 0.1m 未満を塗らない | 荒川周辺: z14 7,211B、z17 4,495B | 2〜17(z1・z18 は 404) | 公式 |
| 津波浸水想定 統合版 | `https://disaportaldata.gsi.go.jp/raster/04_tsunami_newlegend_data/{z}/{x}/{y}.png`(県別は `04_tsunami_newlegend_pref_data/NN/`) | PNG | 不定期(取得したタイルは 2023-06-08)。40 都道府県 | 同上 | 鎌倉の沿岸 z14 5,552B | 2〜17 | 公式 |
| 高潮浸水想定区域 統合版 | `https://disaportaldata.gsi.go.jp/raster/03_hightide_l2_shinsuishin_data/{z}/{x}/{y}.png` | PNG | 不定期。18 都道府県 | 同上 | 荒川 z14 8,912B | 2〜17 | 公式 |
| 土砂災害警戒区域(土石流・急傾斜地の崩壊・地すべり) | `https://disaportaldata.gsi.go.jp/raster/05_dosekiryukeikaikuiki/{z}/{x}/{y}.png`、`05_kyukeishakeikaikuiki`、`05_jisuberikeikaikuiki` | PNG(境界はなじませてある) | 元データは国土数値情報の令和7年度版(取得したタイルは 2026-07-29) | 上記+国土数値情報の規約(CC BY 4.0 に一部の制限)。神奈川・京都・和歌山・広島・長崎・鳥取は公開の条件つき。出典例「国土数値情報（令和７年度土砂災害警戒区域）をもとに国土地理院が加工」 | 横須賀 z14 の急傾斜地 62,111B(ほかより重い) | 2〜17 | 公式 |
| 指定緊急避難場所(災害の種類ごと) | `https://cyberjapandata.gsi.go.jp/xyz/skhb01/{z}/{x}/{y}.geojson` 〜 `skhb08` | GeoJSON の点 | 随時(東京の z10 タイルの Last-Modified は 2026-11-02) | 国土地理院コンテンツ利用規約。地理院の利用上の注意(下)を利用者に伝える | 東京 z10(909/403): skhb01 349,472B(1,195 件)、skhb05 55,639B(183 件)。**gzip なし** | **z10 だけ**(z14 は 404) | 公式 |
| 指定避難所 | `https://cyberjapandata.gsi.go.jp/xyz/sih/{z}/{x}/{y}.geojson`(一般)、`sfh`(福祉) | GeoJSON | 随時 | 同上 | 東京 z10 の sih 397,455B(1,605 件) | z10 | 公式 |
| 避難場所の CSV(全国・市町村別) | https://hinanmap.gsi.go.jp/index.html | CSV / GeoJSON | 随時 | 同意の操作の先にあるため、開いていない | 未確認 | - | 公式 |
| 気象庁 地震の一覧 | `https://www.jma.go.jp/bosai/quake/data/list.json` | JSON | 随時。Cache-Control max-age=60 | 気象庁サイトの規約(PDL1.0)、出典「出典：気象庁ホームページ」。JSON の自動取得についての記載はない | 22,934B / 245,490B(184 件) | - | **非公式** |
| 気象庁 地震の詳細 | `https://www.jma.go.jp/bosai/quake/data/{一覧の json 項目}` | JSON(観測点の震度を含む) | 随時 | 同上 | 980B / 2,495B(震度2の小さな地震) | - | **非公式** |
| 気象庁 津波の一覧・詳細 | `https://www.jma.go.jp/bosai/tsunami/data/list.json`、`/bosai/tsunami/data/{json}` | JSON(予報区のコードと名前、予想の高さ) | 随時 | 同上 | 一覧 518B / 3,917B、詳細 1,394B / 4,464B | - | **非公式** |
| 気象庁 津波予報区の海岸線 | `https://www.jma.go.jp/bosai/common/const/geojson/tsunami.json` | GeoJSON(MultiLineString 66 本、properties は code) | 2026-11-05 | 同上 | 37,299B / 115,477B | - | **非公式** |
| 気象庁 推計震度分布 | 一覧 `https://www.jma.go.jp/bosai/estimated_intensity_map/data/list.json`、画像 `/bosai/estimated_intensity_map/data/{url}/{mesh_num}.png` | 一覧は JSON、画像は1次メッシュ(約 80km)ごとの PNG 800×800 | 発表ごと。画像は max-age=86400 | 同上 | 一覧 30,891B / 245,226B(339 件)、画像1枚 41,439B | 画像の四隅は mesh_num から計算 | **非公式** |
| P2P地震情報 API v2 | `https://api.p2pquake.net/v2/history?codes=551&limit=1`、`/v2/jma/quake`、`/v2/jma/tsunami`、WebSocket `wss://api.p2pquake.net/v2/ws` | JSON | リアルタイム(551 地震、552 津波予報、556 緊急地震速報) | 商用・非商用とも無料、無保証。上限は /history 60回/分/IP、/jma 10回/分/IP、/ws 2接続/IP | 551 の1件 462B / 811B | - | **非公式**(民間のサービス) |
| 標高タイル | `https://cyberjapandata.gsi.go.jp/xyz/dem_png/{z}/{x}/{y}.png`(DEM10B)、`dem5a_png`、`dem5b_png`、`dem5c_png`、`dem1a_png` | PNG 256px RGB | 標高モデルの更新に合わせて | 出典の明示だけで申請不要(リアルタイムに読み込む場合)。「国土地理院」または「地理院タイル」と書き、タイル一覧のページへのリンクを付ける。加工したときは「地理院タイル（標高タイル）を加工して作成」 | 荒川: dem_png z14 18,510B、dem5a_png z15 49,636B、dem1a_png z16 39,248B、z17 18,318B | DEM10B 1〜14、DEM5A/B/C 1〜15、DEM1A 1〜17 | 公式 |
| 航空写真(全国最新写真 シームレス) | `https://cyberjapandata.gsi.go.jp/xyz/seamlessphoto/{z}/{x}/{y}.jpg` | JPEG 256px | 随時 | 出典の明示で利用可。一部の範囲に Landsat-8、「GRUS画像（© Axelspace）」を含み、その範囲では追加の表記が必要 | z18 15,811B、z16 15,768B(川の上)、z12 104,012B | 2〜18(z14〜18 が写真) | 公式 |
| 国土地理院 ベクトルタイル提供実験 | `https://cyberjapandata.gsi.go.jp/xyz/experimental_bvmap/{z}/{x}/{y}.pbf` | MVT(gzip で配信) | 2〜4か月ごと(最新 2026-09-16) | 出典「国土地理院ベクトルタイル提供実験」 | 北千住 z16 44,055B / 88,032B(建物 2,127 件) | 4〜16 | 公式(提供実験) |
| 国土地理院 最適化ベクトルタイル | `https://cyberjapandata.gsi.go.jp/xyz/optimal_bvmap-v1/{z}/{x}/{y}.pbf`(PMTiles 版もある) | MVT(非圧縮) | xyz 版は 2023年10月のデータで更新停止。PMTiles 版は 2026-07-01 時点 | 試験公開。出典「国土地理院最適化ベクトルタイル」 | 北千住 z16 50,648B(建物 1,039 件) | 4〜16 | 公式(試験公開) |
| PLATEAU 建物 | カタログ `https://api.plateauview.mlit.go.jp/datacatalog/plateau-datasets`、建物は 3D Tiles の `tileset.json` | 3D Tiles(b3dm)。建物の MVT はカタログにない | 年度ごと | PDL1.0(CC BY 4.0 互換)。出典例「出典：国土交通省 PLATEAUウェブサイト（URL）」 | 建物の最新データセット 1,065 件・**306 市区町村**、file_size の合計 56.27GB(中央値 33MB)。千代田区 LOD1 は 8.4MB、b3dm 1個 920,804B(105 棟、gzip なし。うち属性の JSON が 508KB) | 3D Tiles の LOD | 公式 |
| OpenStreetMap | Overpass API(公開のインスタンス) | XML / JSON | 常時 | ODbL。「© OpenStreetMap contributors」と、openstreetmap.org/copyright へのリンク | 日本の建物 31,144,149 件のうち height あり 5,199,932 件(16.7%)、building:levels あり 3,465,215 件(約 11%)(Geofabrik taginfo、2026-11-06) | - | 公式(OSMF) |

## 2. 浸水の深さを色から読む

洪水・津波・高潮は同じ凡例の画像(`shinsui_legend3.png`)を使っている。凡例の画素から取った色:

| RGB | 深さの区間 |
|---|---|
| (220,122,220) | 20m 以上 |
| (242,133,201) | 10〜20m |
| (255,145,145) | 5〜10m |
| (255,183,183) | 3〜5m |
| (255,216,192) | 0.5〜3m(細分のある行では 1〜3m に当たる) |
| (248,225,166) | 0.5〜1m |
| (247,245,169) | 0.5m 未満(細分のある行では 0.3〜0.5m に当たる) |
| (255,255,179) | 0.3m 未満 |

- 実際のタイルの画素は、凡例の色と透明(0,0,0,0)だけだった(洪水 z14: 6色+透明、z17: 3色+透明、高潮: 6色+透明、津波: 7色+透明)。**なじませ(アンチエイリアス)も半透明もなく、alpha は 0 か 255 だけ**。色から深さの区間をそのまま引ける(このアプリでも、荒川 z14 の洪水タイルで色の数を数え直して確かめた)
- 凡例の細分の欄(0.5〜1m、0.3m 未満)を津波・高潮が使うという公式の説明は見つからなかった(推定)。洪水のタイルにも (248,225,166) が 8 画素あったので、区間の体系は完全には分かれていない。アプリでは、どの色も上の表のとおりに読む
- 読み取りは「完全に一致する色だけ」。一致しない色は「区間不明」にする
- 土砂災害は別の凡例: 急傾斜地 特別警戒 (250,40,0)・警戒 (250,230,0)、土石流 特別警戒 (165,0,33)・警戒 (230,200,50)、地すべり 特別警戒 (180,0,40)・警戒 (255,153,0)。指定の予定は点線の枠。こちらは**境界をなじませてあり**(急傾斜地のタイルで 2,379 色)、半透明の縁がある。alpha 255 の画素だけを使い、一番近い色で分ける

## 3. 避難場所の災害の種類

- 指定緊急避難場所(skhb)の properties: `name`、`address`、`remarks`、`disaster1`〜`disaster8`。当てはまる種類だけ値が 1 で、当てはまらない種類はキーがない
  - disaster1 洪水 / disaster2 崖崩れ・土石流・地すべり / disaster3 高潮 / disaster4 地震 / disaster5 津波 / disaster6 大規模な火事 / disaster7 内水氾濫 / disaster8 火山現象
  - skhb01 の 1,195 件はすべて disaster1=1、skhb05 の 183 件はすべて disaster5=1 だった(タイルの番号と種類が合っている)。1つのタイルにほかの種類のフラグも入っている
  - 例: お台場学園港陽小・中学校は disaster1〜5 が 1
- 指定避難所(sih)の properties: `name`、`address`、`accept`、`necessary_matters`、`remarks`
- 全件をそろえるには skhb01〜08 をすべて取って、名前と座標で重ねる(1つの種類だけでは、その種類に指定された所しか入っていない)
- 地理院の利用上の注意を、アプリでも伝える: 最新でない場合があるので市町村に確かめること。指定緊急避難場所は災害の種類ごとに指定されていること
- タイルは z10(約 35km 四方)だけで、gzip で配信されない(東京の1枚で 350KB 前後)。Wi-Fi のときに、現在地と登録した場所の z10 タイルの skhb01〜08・sih を取り、アプリの中で小さい形(名前・座標・種類のビット)に直して保存する。東京の1枚分を全種類取ると約 1〜2MB、直した後は 1 割程度の見込み

## 4. 地震・津波

- 気象庁の地震の一覧は 184 件で展開後 245KB あるが、gzip で 23KB。一覧で十分(震源の緯度経度・深さ・M・最大震度が入っている)。震度の分布は、詳細の JSON の観測点(数KB)で描ける
- 津波: 気象庁の津波の JSON は予報区のコード(例 310)だけで、座標はない。`const/geojson/tsunami.json` の海岸線と code で結び付ければ、沿岸の位置と方角を計算できる(どちらも非公式)。P2P の 552 も予報区の名前だけ
  - 海岸線は 115KB(gzip 37KB)。アプリに同梱する(予報区ごとに間引いた折れ線にして数十KB)。更新はスマートダッシュボードと同じく手元のスクリプトで行う
- 気象庁の一覧には 2026-11-06 の「津波予報(若干の海面変動)」があったが、P2P の /jma/tsunami の最新は 2026-07-28 の解除だった。P2P はこの種類を配信しない可能性がある(推定)。津波は気象庁の JSON を主に、P2P を補助にする
- 推計震度分布は、80km の範囲ごとの PNG(1枚 40KB)。カメラ表示に重ねるには重いので、v0.2 では観測点の震度を使い、推計震度分布は「地図で見る」(Wi-Fi のときだけ)に回す
- 緊急地震速報(P2P の 556)は WebSocket で受け取る。アプリを開いている間だけつなぐ(LiveContainer ではバックグラウンドで受け取れない)。上限は 2接続/IP
- 気象業務法により、気象庁以外は警報を出せない。アプリが独自に「警報」と書かない(「気象庁の発表: 津波警報」のように、発表元を付けて引用する)

## 5. 地形と建物

- 標高タイルの値: x = 2^16·R + 2^8·G + B。x < 2^23 なら x × 0.01m、x = 2^23(128,0,0)はデータなし、それより大きければ (x − 2^24) × 0.01m(`GSIElevationTile`、スマートダッシュボードから写した)
- 細かいズームほど空白が多い(荒川で dem5a z15 は 5,994 画素、dem1a z17 は 36,595 画素がデータなし)。dem5a → dem_png(DEM10B)の順に引く
- 航空写真は z14〜18 が写真。川や畑の上は 15KB 前後、市街地は重くなる(市街地の値は未確認。設計では 25KB と見積もった)
- 国土地理院のベクトルタイルの建物には高さがない(提供実験の `building` は `ftCode`・`lvOrder` など)。形だけ
- PLATEAU は 306 市区町村で、高さ(`bldg:measuredHeight`、千代田区で 0.8〜209.5m)と地上階数がある。配信は 3D Tiles(b3dm)だけで、属性の JSON が重い(b3dm 1個 920KB のうち 508KB)。携帯回線では重すぎるので、**都市ごとに「棟ごとの外形と高さ」だけに直したものを前もって作り、GitHub Releases などに置く**のがよい(v0.5 で検討)
- OpenStreetMap は高さのある建物が 2 割弱。Overpass の公開インスタンスはアプリのバックエンドに使えない(1日 1 万リクエスト・1GB の目安、一般向けアプリでの利用は不可と明記)。使うなら前もって抽出したものを置く

## 6. 通信の注意

- gzip: 気象庁と P2P は gzip(JSON は 1/8〜1/10 になる)。skhb の GeoJSON、ハザードのタイル、PLATEAU の b3dm、最適化ベクトルタイルは圧縮なし
- ETag と Last-Modified: disaportaldata・cyberjapandata・気象庁・PLATEAU に付いている。保存したタイルの取り直しは条件付き GET(If-None-Match)にして、変わっていなければ 304 で済ませる
- Cache-Control: disaportaldata(洪水・高潮・急傾斜地)は 3日、津波のタイルはなし。cyberjapandata はなし。気象庁の一覧 60秒、推計震度の画像 1日。P2P 1秒
- データのない場所のタイルは 404(本文 150〜330B)。「データなし」として覚え、取り直さない
- 地理院タイルが申請不要なのは「リアルタイムに読み込む場合」と書かれている。端末にキャッシュとして保存する使い方はこれに当たると考えるが、まとめて取ってアプリに同梱する扱いは未確認(同梱はしない)

## 7. 確かめられなかったこと

- 指定緊急避難場所・指定避難所の全国の件数とファイルの大きさ(CSV のページは同意の操作の先のため開いていない)
- 重ねるハザードマップの各層の全国のタイルの総量と、更新の頻度の公式な記載(提供開始日しか載っていない)
- 凡例の細分(0.3m 未満、0.5〜1m)が津波・高潮用だという公式の文章
- 気象庁の bosai の JSON の利用の可否と、自動の取得についての公式な見解(規約に記載がない。非公式として扱う)
- P2P の緊急地震速報(556)と津波予報(552)の実データ(期間内に該当がなかった。仕様書の形だけ確認)。WebSocket はつながる(101)ところまでで、配信の中身は受けていない
- 地理院のベクトルタイルの ftCode の意味、航空写真の全国の量、市街地の航空写真1枚の大きさ
- PLATEAU の file_size が zip のサイズか展開後か、3D Tiles 以外の建物の配信

## 出典のページ

- https://disaportal.gsi.go.jp/hazardmapportal/hazardmap/copyright/opendata.html
- https://disaportal.gsi.go.jp/hazardmapportal/hazardmap/copyright/copyright.html
- https://maps.gsi.go.jp/development/ichiran.html
- https://www.gsi.go.jp/bousaichiri/hinanbasho.html
- https://nlftp.mlit.go.jp/ksj/gml/datalist/KsjTmplt-A33-2024.html
- https://www.jma.go.jp/jma/kishou/info/coment.html
- https://www.p2pquake.net/secondary_use/ 、https://www.p2pquake.net/swagger-ui/specification.yaml
- https://github.com/gsi-cyberjapan/optimal_bvmap 、https://github.com/gsi-cyberjapan/gsimaps-vector-experiment
- https://www.mlit.go.jp/plateau/site-policy/ 、https://www.mlit.go.jp/plateau/open-data
- https://www.openstreetmap.org/copyright 、https://dev.overpass-api.de/overpass-doc/en/preface/commons.html
- https://taginfo.geofabrik.de/asia:japan/
