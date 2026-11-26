# ライセンスと共通基盤の由来

メーター演出（SYNC_Meter） Copyright (c) 2026 VRAMの魔術師

本体のソースコードは GNU General Public License v3.0（GPL-3.0-only）です。 [ライセンス全文](LICENSE)

## AviUtl ExEdit2 Plugin SDK

- Copyright (c) 2025 Kenkun
- ライセンスは MIT です。対象は `Source/Lib/AviUtl2FilterTypes.pas` の SDK 型、コールバック、編集 API の ABI 定義です。 [SDK のライセンス全文](ThirdParty/LICENSE.AviUtl2-SDK.txt)

## 継承元

- SYNC_WeatherFX と SYNC_AquaFX から Delphi プロジェクト、Win64 ビルド設定、公開関数、SDK 定義、設定項目の登録処理を継承しています。
- フィルターテーブル登録処理の継承元は Syncroh2 / SYNC_Lyrics です。
- SYNC_Clock の Direct2D キャンバス、数字描画、映像・音声コールバックの SDK 宣言を流用しています。
