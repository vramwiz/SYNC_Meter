unit Meter_Parameters;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// AviUtl2 標準の設定項目を登録し、編集APIで選択したプリセットを反映する。

interface

uses Meter_Settings;

// DLL が保持する設定テーブルを初期化する。登録時に一度だけ呼ぶ。
procedure RegisterMeterParameters;
// コールバック中のホスト値を、描画・音声側で使える独立した値へコピーする。
function ReadMeterSettings: TMeterSettings;

implementation

uses System.SysUtils, System.Math, Winapi.Windows, AviUtl2FilterTypes, PluginFilterTable;

type
  TMeterGroup = (mgBasic, mgReading, mgTime, mgOverflow, mgColors, mgAudio);
  TTrackDefinition = record
    Minimum, Maximum, Step: Double;
  end;

const
  COLOR_NAMES: array[TMeterColor] of PWideChar = ('本体色', '表示面色',
    '計測表示色', '文字・目盛り色', '警告色');
  GROUP_NAMES: array[TMeterGroup] of PWideChar = ('基本設定', '計測設定',
    '時間設定', '異常値演出', '色設定', '効果音設定');
  TRACKS: array[TMeterTrack] of TTrackDefinition = (
    (Minimum:-10000000; Maximum:10000000; Step:0.01),
    (Minimum:-10000000; Maximum:10000000; Step:0.01),
    (Minimum:-10000000; Maximum:10000000; Step:0.01),
    (Minimum:-10000000; Maximum:10000000; Step:0.01),
    (Minimum:0; Maximum:6; Step:1),
    (Minimum:0; Maximum:3600; Step:0.01),
    (Minimum:0; Maximum:3600; Step:0.01),
    (Minimum:0; Maximum:100; Step:0.01));

var
  PresetItem, KindItem, OverflowItem: TFILTER_ITEM_SELECT;
  PresetButton: TFILTER_ITEM_BUTTON;
  KindOptions: array[0..Ord(High(TMeterKind)) + 1] of TFILTER_ITEM_SELECT_ITEM;
  OverflowOptions: array[0..Ord(High(TOverflowMode)) + 1] of TFILTER_ITEM_SELECT_ITEM;
  TrackItems: array[TMeterTrack] of TFILTER_ITEM_TRACK;
  ColorItems: array[TMeterColor] of TFILTER_ITEM_COLOR;
  GroupItems, GroupEnds: array[TMeterGroup] of TFILTER_ITEM_GROUP;
  UnitItem: TFILTER_ITEM_STRING;
  SoundItem: TFILTER_ITEM_CHECK;

procedure ApplyPreset(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE; Effect, Item: PWideChar); cdecl;
var
  Kind: TMeterKind;
  S: TMeterSettings;
  Color: TMeterColor;
  Track: TMeterTrack;
  Saved: PAnsiChar;
  Name, Target: string;

  procedure WriteItem(Field: PWideChar; const Value: string);
  var
    Encoded: UTF8String;
  begin
    Encoded := UTF8String(Value);
    if not Edit^.SetObjectItemValue(Obj, PWideChar(Target), Field, PAnsiChar(Encoded)) then
      OutputDebugString(PWideChar('SYNC_Meter preset: ' + string(Field)));
  end;

  procedure WriteTrack(Field: TMeterTrack);
  begin
    WriteItem(TrackItems[Field].Name, FloatToStr(S.Values[Field], TFormatSettings.Invariant));
  end;

begin
  if (Edit = nil) or (Obj = nil) or (Effect = nil) or
    not Assigned(Edit^.GetObjectItemValue) or not Assigned(Edit^.SetObjectItemValue) then Exit;
  try
    Target := Effect;
    Saved := Edit^.GetObjectItemValue(Obj, PWideChar(Target), PresetItem.Name);
    if Saved = nil then Exit;
    Name := string(UTF8String(Saved));
    for Kind := Low(TMeterKind) to High(TMeterKind) do
      if Name = string(METER_NAMES[Kind]) then
      begin
        S := PresetSettings(Kind);
        WriteItem(KindItem.Name, Name);
        for Track := mtMinimum to mtDecimals do WriteTrack(Track);
        WriteItem(UnitItem.Name, S.UnitText);
        WriteItem(OverflowItem.Name, string(OVERFLOW_NAMES[S.Overflow]));
        for Color := Low(TMeterColor) to High(TMeterColor) do
          WriteItem(ColorItems[Color].Name, IntToHex(S.Colors[Color], 6));
        WriteItem(SoundItem.Name, IntToStr(Ord(S.Sound)));
        WriteTrack(mtVolume);
        Exit;
      end;
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Meter preset: ' + E.Message));
  end;
end;

procedure RegisterMeterParameters;
var
  Kind: TMeterKind;
  Mode: TOverflowMode;
  Color: TMeterColor;
  Track: TMeterTrack;
  Code: Cardinal;
  S: TMeterSettings;

  procedure BeginGroup(Group: TMeterGroup; Expanded: Byte = 0);
  begin
    AddGroup(GroupItems[Group], GROUP_NAMES[Group], Expanded);
  end;

  procedure EndGroup(Group: TMeterGroup);
  begin
    AddGroup(GroupEnds[Group], '', 0);
  end;

  procedure RegisterTrack(Field: TMeterTrack);
  var
    Def: TTrackDefinition;
  begin
    Def := TRACKS[Field];
    AddTrack(TrackItems[Field], TRACK_NAMES[Field], S.Values[Field],
      Def.Minimum, Def.Maximum, Def.Step);
  end;

begin
  S := PresetSettings(mkColumn);
  for Kind := Low(TMeterKind) to High(TMeterKind) do
  begin
    KindOptions[Ord(Kind)].Name := METER_NAMES[Kind];
    KindOptions[Ord(Kind)].Value := Ord(Kind);
  end;
  for Mode := Low(TOverflowMode) to High(TOverflowMode) do
  begin
    OverflowOptions[Ord(Mode)].Name := OVERFLOW_NAMES[Mode];
    OverflowOptions[Ord(Mode)].Value := Ord(Mode);
  end;

  AddSelect(PresetItem, 'プリセット', Ord(S.Kind), @KindOptions[0]);
  AddButton(PresetButton, '設定を反映', ApplyPreset);
  BeginGroup(mgBasic, 1);
  AddSelect(KindItem, '計測器の種類', Ord(S.Kind), @KindOptions[0]);
  EndGroup(mgBasic);

  BeginGroup(mgReading, 1);
  for Track := mtMinimum to mtTarget do RegisterTrack(Track);
  AddString(UnitItem, '単位', METER_PRESETS[S.Kind].DefaultUnit);
  RegisterTrack(mtDecimals);
  EndGroup(mgReading);

  BeginGroup(mgTime);
  RegisterTrack(mtDelay);
  RegisterTrack(mtDuration);
  EndGroup(mgTime);

  BeginGroup(mgOverflow);
  AddSelect(OverflowItem, '計測範囲外の演出方法', Ord(S.Overflow), @OverflowOptions[0]);
  EndGroup(mgOverflow);

  BeginGroup(mgColors);
  for Color := Low(TMeterColor) to High(TMeterColor) do
  begin
    Code := S.Colors[Color];
    AddColor(ColorItems[Color], COLOR_NAMES[Color], Byte(Code and 255),
      Byte((Code shr 8) and 255), Byte((Code shr 16) and 255));
  end;
  EndGroup(mgColors);

  BeginGroup(mgAudio);
  AddCheck(SoundItem, '効果音', Ord(S.Sound));
  RegisterTrack(mtVolume);
  EndGroup(mgAudio);
end;

function ReadMeterSettings: TMeterSettings;
var
  Defaults: TMeterSettings;
  Color: TMeterColor;
  Track: TMeterTrack;
begin
  Result.Kind := TMeterKind(EnsureRange(KindItem.Value, 0, Ord(High(TMeterKind))));
  Defaults := PresetSettings(Result.Kind);
  Result.Overflow := TOverflowMode(EnsureRange(OverflowItem.Value, 0, Ord(High(TOverflowMode))));
  Result.Sound := SoundItem.Value <> 0;
  Result.UnitText := '';
  if UnitItem.Value <> nil then
    SetString(Result.UnitText, UnitItem.Value, Min(64, StrLen(UnitItem.Value)));
  for Color := Low(TMeterColor) to High(TMeterColor) do
    Result.Colors[Color] := (Cardinal(ColorItems[Color].R) shl 16) or
      (Cardinal(ColorItems[Color].G) shl 8) or ColorItems[Color].B;
  for Track := Low(TMeterTrack) to High(TMeterTrack) do
    Result.Values[Track] := EnsureRange(FiniteValue(TrackItems[Track].Value,
      Defaults.Values[Track]), TRACKS[Track].Minimum, TRACKS[Track].Maximum);
end;

end.
