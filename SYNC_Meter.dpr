library SYNC_Meter;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only

// メーター演出の AviUtl2 DLL 境界。登録と終了の入口を公開する。
// Delphi 例外は C コールバックの外へ漏らさない。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
  Meter_Settings in 'Source\Common\Meter_Settings.pas',
  Meter_Canvas in 'Source\Common\Meter_Canvas.pas',
  Meter_Glyphs in 'Source\Common\Meter_Glyphs.pas',
  Meter_Analog in 'Source\Common\Meter_Analog.pas',
  Meter_Digital in 'Source\Common\Meter_Digital.pas',
  Meter_Levels in 'Source\Common\Meter_Levels.pas',
  Meter_Audio in 'Source\Common\Meter_Audio.pas',
  Meter_Renderer in 'Source\Common\Meter_Renderer.pas',
  Meter_Parameters in 'Source\Plugin\Filter\Meter_Parameters.pas',
  SYNC_Meter_FilterPlugin in 'Source\Plugin\Filter\SYNC_Meter_FilterPlugin.pas';

{$R *.res}

// ホストのバージョンを確認し、DLL 所有の登録テーブルを初期化する。
// 非対応バージョンと初期化失敗は 0 を返す。
function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  Result := 0;
  try
    if Version < METER_REQUIRED_VERSION then Exit;
    GetMeterFilterTable;
    Result := 1;
  except
    // 初期化失敗は戻り値でホストへ伝える。
  end;
end;

// 描画資源はホストのfunc_destroyでエフェクトごとに解放する。
procedure UninitializePlugin; cdecl;
begin
end;

// 公式 SDK 形式の最低対応バージョン番号を返す。
function RequiredVersion: Cardinal; cdecl;
begin
  Result := METER_REQUIRED_VERSION;
end;

// DLL 所有の登録テーブルを返す。取得失敗時は nil を返す。
function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := nil;
  try
    Result := GetMeterFilterTable;
  except
    // 登録失敗時はテーブルを返さずホスト側へ判断を委ねる。
  end;
end;

exports
  RequiredVersion name 'RequiredVersion',
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
