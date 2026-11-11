# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.007 |
| アプリ名 | しめきりディフェンス / Deadline Defense（AI が決めた。本人の許可 2026-11-04） |
| サブタイトル | 締め切りが歩いてくるToDo / Your to-dos march on a castle |
| カテゴリ | 仕事効率化（主）・ライフスタイル（副） |
| App 内課金 | com.enludus.daily.007.pro（非消耗型・¥600・ファミリー共有あり） |
| サポート URL | https://github.com/enludus-daily/app-20261111-deadline-defense/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261111-deadline-defense/blob/main/PRIVACY.md |
| 年齢区分の答え | 暴力：なし（敵は時計の顔の丸い生き物で、倒すと光の輪で消えるだけ。血・武器の描写なし）。ギャンブル・くじ：なし。Web 閲覧：なし（プライバシーポリシーへのリンクだけ）。生成 AI：なし。ユーザー同士の交流：なし。→ 4+ の見込み。API では入れないので本人が入力 |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・タイマー・占いなどではない。締め切りの残り時間で敵が道を進み、済ませると砲台が倒す、という ToDo とタワーディフェンスの組み合わせ。
- 4.3 の焼き直し：前の毎日のアプリ（腕立て・肩こり・作りおき など）と題材・画面の型・部品（地図・時計の敵・城・砲台）が違う。白いカード＋グラデーションのボタンの型は使っていない。
- 既存のアプリとの意味のある違い：Habitica・BattleTask は「済ませたら経験値」。これは締め切りまでの時間そのものが敵の位置になり、済ませないと本当に城へ近づく。大きい用事を分けると倒しやすくなる。
- 長く使える価値（4.2）：締め切りは毎日生まれる。守った日・マス・城のレベル・1 年の記録が積み上がる。今日の作戦 42、分け方の型 30。
- 他社の名前・商標・見た目を使っていないか：使っていない。部品はすべて自作の Shape / Canvas。アイコンも自作。
- Apple Intelligence：使わない。
- 通知：オプトイン（設定でオンにしたときだけ許可を求める）。断られたら「設定を開く」の案内。

## 収益の道筋

- 形：買い切りの Pro ¥600（StoreKit 2）。理由と比べた表・勝算の表は README の「課金」。
- 課金の画面：今日の波を守りきった直後（1 日 1 回まで）と、鍵のある物を押したときだけ。起動時には出さない。購入を復元できる。
- Paid Apps Agreement が有効であること（本人が確認）。

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない。解析・広告 SDK なし。用事・締め切り・設定は端末の UserDefaults だけに保存。ローカルのお知らせは端末の中で作る）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ、外側の画面）。場面は `ci.yml` の `screenshot-scenes`（field・shot・split・report・paywall など、日本語と英語）。Duo の内側の画面は CI では撮れない（シミュレータの制約。daily-ideas #17）。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）。Duo の内側の画面も
- [ ] サンドボックスで Pro の購入と復元を確かめる
- [ ] スクリーンショットを確かめる
- [ ] 審査に提出する（App 内課金 com.enludus.daily.007.pro も一緒に）
