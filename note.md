# SYNC_Meter 作業ノート

## プロジェクトの前提

- 作業フォルダーは `D:\DelphiProg\MyApp\SYNC_Meter`。Delphi プロジェクト名は `SYNC_Meter`、グループは `SYNC`、日本語名は「メーター演出」。
- `D:\DelphiProg\MyApp\SYNC_WeatherFX` のプロジェクト設定、SDK の共通基盤、作業ノートを継承する。
- 本番は `SYNC_Meter.dproj` / `SYNC_Meter.auf2` の1つ。動作と操作方法は `README.md` を参照する。

## ビルド

- Delphi 37.0 / Win64。IDE では `SYNC_Meter.dproj` を直接開く。
- プロジェクトルートで `rsvars.bat` を呼び、MSBuild で Debug / Release の両方を実行する。警告0・エラー0と AUF2 の更新を確認し、最後に Release を配置する。

```powershell
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_Meter.dproj /t:Build /p:Config=Debug /p:Platform=Win64'
cmd /c 'call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat" && msbuild SYNC_Meter.dproj /t:Build /p:Config=Release /p:Platform=Win64'
```

全体を再ビルドしてログを残す場合は `/t:Rebuild` を選び、事前に `Win64\BuildLogs` を作成する。

## ビルド後イベントとプロジェクト登録

- 出力先は Debug / Release 共通で `C:\ProgramData\aviutl2\Plugin\SYNC_Meter\`。DLL を `SYNC_Meter.auf2` へコピーし、成功後に DLL を削除する。Release では RSM も削除する。
- イベントはコピー元の一行の `copy ... && del ...` を維持する。後続コマンドが `if` の条件内へ取り込まれる `&&if errorlevel ...` の連結へ戻さない。
- DCU は `Win64\Debug\DCU` / `Win64\Release\DCU`。AUF2 の更新時刻・サイズと、DLL / Release RSM が残っていないことを確認する。
- デバッガーホストはコピー元の `.dproj` に合わせ、両構成とも `D:\aviutl2_v2.1.16\aviutl2.exe`。
- ユニット追加時は `.dpr` の `in` と `.dproj` の `DCCReference` を両方更新する。検索パスは `Source\Common`、`Source\Lib`、`Source\Lib\FilterTable`、`Source\Plugin\Filter`。
- 開いている `.dpr` / `.dproj` を外部更新した場合は、IDE で開き直して参照を読み込む。古い内容で保存して追加ユニットの参照を失わないようにする。
- MSBuild 成功と IDE の Code Insight・メッセージ表示は区別する。

## ソース配置

- `SYNC_Meter.dpr` は DLL の公開関数、`Source/Plugin/Filter` は AviUtl2 への登録、パラメータ、プリセット反映、オブジェクトごとのリソースを管理する。
- `Meter_Settings` は20種類のプリセットと計測値、範囲外の状態、共通目盛りを処理する。表示範囲が逆転した場合は昇順に直し、同値の場合は中心値の上下に 0.5 を確保する。
- `Meter_Analog`、`Meter_Digital`、`Meter_Levels` は計器を描画する。`Meter_Canvas` と `Meter_Glyphs` は時計演出の共通図形と数字を継承する。`Meter_Renderer` は Direct2D のサーフェスとキャッシュを管理し、ホストへ RGBA を渡す。
- `Meter_Audio` は電子式計器の電子音をサンプル位置から生成する。液柱の破損時刻と電子音の範囲外到達時刻は計測値の変化から求める。
- `Source/Lib` は SDK 型と設定項目の登録処理を保持する。音声 ABI は SDK の `FILTER_PROC_AUDIO` と照合した。メディアオブジェクトの画像を `set_image_data` で渡す方式は SDK のサンプルと同じ。 [AviUtl ExEdit2 SDK の MediaObject サンプル](https://github.com/oov/aviutl2_plugin_sdk/blob/main/MediaObject.cpp)

## コメント・分割・文字コード

- ユニット先頭に目的と責務を書く。
- 公開処理には入力、出力、重要な副作用を記載する。必要に応じて値の単位、状態の有効範囲、所有権、保存対象も記載する。
- ホストの画像・テーブル・項目ポインター、描画バッファ、キャッシュは、誰が保持・解放するかを書く。コードをそのまま言い換えるコメントを避ける。
- 日本語を含む `.pas` / `.dpr` / Windows PowerShell 用 `.ps1` は UTF-8 BOM 付きとし、改行は CRLF にする。
- 1ユニットは約1,500行を目安に責務で分割する。UI・描画・データ処理を分け、フォームの `.pas` と `.dfm` は同じフォルダーへ置く。
- SDK 型の順序・サイズ・配置を変更する場合は公式定義と照合する。ホスト所有ポインターはコールバック中に使い、Delphi 例外は DLL 境界で処理する。

## 検査とアプリ操作

- 通常のビルド・検査はコマンドラインで行う。AviUtl2 と IDE の画面検査はユーザーから明示された場合に行う。
- 本体を検査する場合は本番 AUF2 を直接読み込む。検査用に生成したファイルは `Win64` 以下に置く。

## Setup の扱い

- 初回実装では WeatherFX の setup をコピーした。v1.0.0 の配布準備で、SYNC_Sanpai の手順をひな形にして SYNC_Meter 用に変更した。ZIP は Release AUF2、README、ライセンスを専用フォルダーにまとめる。

## AviUtl2 カタログ登録時の共通ルール

1. 概要は `summary` の実際の表示文字列で35文字以内とする。機能の詳細は説明・READMEに記載する。
2. 公開カタログで近い用途のタグを確認し、既存タグを優先する。 [公開カタログの index.json](https://github.com/Neosku/aviutl2-catalog-data/blob/main/index.json)
3. 配布ZIPを製品専用フォルダーにまとめ、そのフォルダーだけを対象に配置・アンインストールする。既存パッケージを変更する際は、ZIPの配置とセットアップスクリプトの検証条件を照合する。

## 初回ビルドと検査（2026-11-26）

- Delphi 37.0 の Win64 Debug / Release を再ビルドし、両方で警告0・エラー0を確認した。Release の AUF2 を標準の出力先へ配置した。
- 両構成の AUF2 を直接ロードし、登録名、20プリセットの反映、透過 RGBA、範囲外表示、シーク時の再現性、0秒の切り替え、同値・逆順の範囲、効果音を確認した。全計器の出力見本は `Win64/Verification/all-meters.png`、破損と警告表示は `Win64/Verification/overflow.png`。
- AviUtl2 の画面上での追加メニュー、合成表示、カメラ操作は未確認。
- `setup` の5ファイルについて、コピー元とファイル名および SHA-256 が一致することを確認した。

## v1.0.0 の配布準備（2026-11-26）

- 設定・描画・音声それぞれの公開処理と、キャッシュおよびホストのデータの寿命に関するコメントを補足した。最長の本番ユニットは 347 行。
- README をインストールと利用方法に整理し、20種類の描画見本を Sample/meters.png に置いた。同梱READMEとカタログは公開タグの画像を参照する。
- ZIP 内の AUF2 の XXH3-128 は cc5376970c1b3db38cf4cef40ab5be05。カタログには同じ値を記録した。
