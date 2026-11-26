unit Meter_Settings;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// プリセット、計測範囲、オブジェクト時刻からの表示状態を管理する。

interface

type
  TMeterKind = (mkColumn, mkAnalogTemperature, mkDigitalTemperature, mkClinical,
    mkHumidity, mkBarometer, mkSpeed, mkTachometer, mkPressure, mkVoltage, mkCurrent,
    mkPower, mkFuel, mkBodyScale, mkScale, mkSound, mkRadiation, mkLight, mkBattery,
    mkWater);
  TMeterMethod = (mmColumn, mmDial, mmFan, mmDigital, mmBar);
  TOverflowMode = (omPreset, omClamp, omExtend, omError, omBreak);
  TMeterColor = (mcBody, mcFace, mcReading, mcInk, mcWarning);
  TMeterColors = array[TMeterColor] of Cardinal;
  TMeterTrack = (mtMinimum, mtMaximum, mtInitial, mtTarget, mtDecimals, mtDelay,
    mtDuration, mtVolume);
  TMeterValues = array[TMeterTrack] of Double;
  TReadingStatus = (rsLow, rsNormal, rsHigh);
  TOutOfRange = (oorClamp, oorLo, oorHi, oorL, oorH, oorError, oorOL, oorBreak);
  TBeepKind = (bkStart, bkFinish, bkWarning);
  TBeepKinds = set of TBeepKind;

  TMeterPreset = record
    Method: TMeterMethod;
    Width, Height: Integer;
    Caption, DefaultUnit: PWideChar;
    Minimum, Maximum, Initial, Target: Double;
    Decimals: Integer;
    LowAction, HighAction: TOutOfRange;
    Beeps: TBeepKinds;
    Colors: TMeterColors;
  end;

  TMeterSettings = record
    Kind: TMeterKind;
    Values: TMeterValues;
    UnitText: string;
    Colors: TMeterColors;
    Overflow: TOverflowMode;
    Sound: Boolean;
  end;

  TMeterRange = record
    Lower, Upper: Double;
  end;

  TMeterReading = record
    Number: Double;    // クランプ前の計測値
    Display: Double;   // 数字として表示する値
    Fraction: Double;  // 針・液柱・バー用。目盛り超過時だけ 0～1 を越える
    Status: TReadingStatus;
    MessageText: string;
    BreakAge: Double;  // 発生していないときは -1 秒
  end;

  TMeterTick = record
    Fraction: Double;
    LabelText: string;
  end;

const
  METER_NAMES: array[TMeterKind] of PWideChar = ('液柱式温度計', 'アナログ温度計',
    'デジタル温度計', 'デジタル体温計', '湿度計', '気圧計', '速度計', '回転計',
    '圧力計', '電圧計', '電流計', '電力計', '燃料計', '体重計', 'はかり',
    '騒音計', '放射線測定器', '照度計', 'バッテリー残量計', '水位計');
  OVERFLOW_NAMES: array[TOverflowMode] of PWideChar = ('プリセットに従う',
    '上限・下限で停止', '目盛りを超える', 'エラー表示', '破損演出');
  TRACK_NAMES: array[TMeterTrack] of PWideChar = ('最小値', '最大値', '初期値',
    '目標値', '小数点以下の表示桁数', '演出開始までの時間', '演出の時間', '音量');

  METER_PRESETS: array[TMeterKind] of TMeterPreset = (
    (Method:mmColumn; Width:360; Height:640; Caption:'THERMOMETER'; DefaultUnit:'℃';
     Minimum:-20; Maximum:110; Initial:18; Target:86; Decimals:0; LowAction:oorClamp; HighAction:oorBreak;
     Beeps:[]; Colors:($657A86,$F3EFE2,$E32F42,$222F37,$FF5444)),
    (Method:mmDial; Width:440; Height:440; Caption:'TEMPERATURE'; DefaultUnit:'℃';
     Minimum:-40; Maximum:60; Initial:8; Target:32; Decimals:0; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($A8B9BD,$F3F4EB,$C94736,$243745,$CF4731)),
    (Method:mmDigital; Width:420; Height:270; Caption:'DIGITAL TEMP'; DefaultUnit:'℃';
     Minimum:-50; Maximum:150; Initial:21.5; Target:74.6; Decimals:1; LowAction:oorLo; HighAction:oorHi;
     Beeps:[bkFinish,bkWarning]; Colors:($285985,$C6DAB6,$233C2A,$213B34,$8C331F)),
    (Method:mmDigital; Width:500; Height:200; Caption:'BODY TEMP'; DefaultUnit:'℃';
     Minimum:32; Maximum:43; Initial:35.6; Target:37.2; Decimals:1; LowAction:oorL; HighAction:oorH;
     Beeps:[bkStart,bkFinish,bkWarning]; Colors:($E5F4F3,$C0D5B7,$253936,$224F57,$A23A39)),
    (Method:mmDial; Width:440; Height:440; Caption:'HUMIDITY'; DefaultUnit:'%';
     Minimum:0; Maximum:100; Initial:35; Target:68; Decimals:0; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($43756D,$E4EADB,$18625B,$263C3B,$AC472F)),
    (Method:mmDial; Width:460; Height:460; Caption:'BAROMETER'; DefaultUnit:'hPa';
     Minimum:950; Maximum:1050; Initial:1003; Target:1024; Decimals:0; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($A87944,$EEE0BE,$784533,$3A3026,$97472E)),
    (Method:mmDial; Width:480; Height:440; Caption:'SPEED'; DefaultUnit:'km/h';
     Minimum:0; Maximum:240; Initial:0; Target:124; Decimals:0; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($303B4A,$121C28,$54DDF8,$E3F0F6,$F45951)),
    (Method:mmDial; Width:440; Height:440; Caption:'TACHOMETER'; DefaultUnit:'rpm';
     Minimum:0; Maximum:9000; Initial:800; Target:6200; Decimals:0; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($363235,$171923,$F8EDD7,$F2EBE8,$FF4A52)),
    (Method:mmDial; Width:420; Height:470; Caption:'PRESSURE'; DefaultUnit:'MPa';
     Minimum:0; Maximum:2.5; Initial:0.2; Target:1.8; Decimals:1; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($69737C,$EEEFE9,$293B46,$202F3A,$D64639)),
    (Method:mmDigital; Width:360; Height:420; Caption:'VOLT METER'; DefaultUnit:'V';
     Minimum:0; Maximum:600; Initial:0; Target:230; Decimals:1; LowAction:oorClamp; HighAction:oorOL;
     Beeps:[bkWarning]; Colors:($DF8F2F,$C1D4AC,$243C29,$23322D,$972C29)),
    (Method:mmDigital; Width:380; Height:460; Caption:'CLAMP METER'; DefaultUnit:'A';
     Minimum:0; Maximum:100; Initial:0; Target:12.8; Decimals:2; LowAction:oorClamp; HighAction:oorOL;
     Beeps:[bkWarning]; Colors:($C7633E,$C2D7BB,$263A30,$283A38,$982C24)),
    (Method:mmFan; Width:450; Height:326; Caption:'POWER'; DefaultUnit:'W';
     Minimum:0; Maximum:2000; Initial:0; Target:1350; Decimals:0; LowAction:oorClamp; HighAction:oorOL;
     Beeps:[]; Colors:($494C4F,$EEE6CE,$643523,$232320,$BC3F2F)),
    (Method:mmFan; Width:390; Height:280; Caption:'FUEL'; DefaultUnit:'E・F';
     Minimum:0; Maximum:100; Initial:75; Target:18; Decimals:0; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($323F4D,$182329,$FFCB72,$F1F0D5,$F56E52)),
    (Method:mmDigital; Width:448; Height:416; Caption:'BODY SCALE'; DefaultUnit:'kg';
     Minimum:0; Maximum:180; Initial:0; Target:62.4; Decimals:1; LowAction:oorError; HighAction:oorError;
     Beeps:[bkFinish,bkWarning]; Colors:($6A979D,$162E36,$C3F6F6,$E4F1EF,$FF7976)),
    (Method:mmDigital; Width:460; Height:320; Caption:'PRECISION SCALE'; DefaultUnit:'g';
     Minimum:0; Maximum:5000; Initial:0; Target:428; Decimals:0; LowAction:oorError; HighAction:oorError;
     Beeps:[bkFinish,bkWarning]; Colors:($586571,$A8CBBC,$233B39,$263832,$932D29)),
    (Method:mmDigital; Width:324; Height:462; Caption:'SOUND LEVEL'; DefaultUnit:'dB';
     Minimum:30; Maximum:130; Initial:33; Target:87.8; Decimals:1; LowAction:oorLo; HighAction:oorHi;
     Beeps:[bkWarning]; Colors:($314A57,$B1D6BE,$173C32,$263C30,$9E3A44)),
    (Method:mmDigital; Width:374; Height:380; Caption:'RADIATION'; DefaultUnit:'μSv/h';
     Minimum:0; Maximum:99; Initial:0.08; Target:0.48; Decimals:2; LowAction:oorClamp; HighAction:oorOL;
     Beeps:[bkStart,bkWarning]; Colors:($D9B446,$B7CF9B,$253D22,$293728,$962920)),
    (Method:mmDigital; Width:334; Height:432; Caption:'LUX METER'; DefaultUnit:'lx';
     Minimum:0; Maximum:100000; Initial:120; Target:1540; Decimals:0; LowAction:oorLo; HighAction:oorOL;
     Beeps:[bkWarning]; Colors:($465879,$A6D9CA,$173931,$243B41,$A63930)),
    (Method:mmBar; Width:466; Height:230; Caption:'BATTERY'; DefaultUnit:'%';
     Minimum:0; Maximum:100; Initial:15; Target:86; Decimals:0; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($485B62,$182A2D,$81DC91,$DEEFE8,$F97159)),
    (Method:mmBar; Width:328; Height:470; Caption:'WATER LEVEL'; DefaultUnit:'cm';
     Minimum:0; Maximum:120; Initial:12; Target:98; Decimals:0; LowAction:oorClamp; HighAction:oorClamp;
     Beeps:[]; Colors:($476678,$1A303E,$42C7E7,$DBF0FA,$FF9356)));

// 計測器の既定値を返す。単位文字列と配色は呼び出し元で個別に変更できる。
function PresetSettings(Kind: TMeterKind): TMeterSettings;
// 設定項目から来る NaN と無限大を既定値に戻してから、各項目の範囲に収める。
function FiniteValue(Value, Fallback: Double): Double;
// 指定された端点を昇順にし、同値の場合も正の表示幅を返す。元の設定は書き換えない。
function MeterRange(const S: TMeterSettings): TMeterRange;
// 生の計測値を表示範囲と比較する。範囲の端点は通常表示に含む。
function ReadingStatus(Value: Double; const Bounds: TMeterRange): TReadingStatus;
// オブジェクト先頭からの再生秒を、計測値・表示用の値・破損状態に変換する。
function EvaluateMeter(const S: TMeterSettings; Seconds: Double): TMeterReading;
// 開始時点で範囲外なら 0 秒。演出中に境界を越えなければ -1 秒。
function RangeEntryTime(const S: TMeterSettings; const Bounds: TMeterRange;
  Side: TReadingStatus): Double;
// 描画位置は範囲内の比率で返す。補助目盛りでは LabelText が空になる。
function MeterTicks(const Bounds: TMeterRange; MaxIntervals: Integer): TArray<TMeterTick>;
// 地域設定によらない小数点表記で、内蔵字形用のラベルを整形する。
function FixedNumber(Value: Double; Decimals: Integer): string;
// 表示桁数のトラック値を描画用の整数にする。
function DisplayDecimals(const S: TMeterSettings): Integer;

implementation

uses System.Math, System.SysUtils;

function PresetSettings(Kind: TMeterKind): TMeterSettings;
var
  P: TMeterPreset;
begin
  P := METER_PRESETS[Kind];
  Result.Kind := Kind;
  Result.UnitText := string(P.DefaultUnit);
  Result.Values[mtMinimum] := P.Minimum;
  Result.Values[mtMaximum] := P.Maximum;
  Result.Values[mtInitial] := P.Initial;
  Result.Values[mtTarget] := P.Target;
  Result.Values[mtDecimals] := P.Decimals;
  Result.Values[mtDelay] := 0.35;
  Result.Values[mtDuration] := 2.00;
  Result.Values[mtVolume] := 50;
  Result.Colors := P.Colors;
  Result.Overflow := omPreset;
  Result.Sound := P.Beeps <> [];
end;

function FiniteValue(Value, Fallback: Double): Double;
begin
  if IsNan(Value) or IsInfinite(Value) then Exit(Fallback);
  Result := Value;
end;

function MeterRange(const S: TMeterSettings): TMeterRange;
var
  A, B: Double;
begin
  A := S.Values[mtMinimum];
  B := S.Values[mtMaximum];
  Result.Lower := Min(A, B);
  Result.Upper := Max(A, B);
  if Result.Upper - Result.Lower < 0.000001 then
  begin
    Result.Lower := A - 0.5;
    Result.Upper := A + 0.5;
  end;
end;

function ReadingStatus(Value: Double; const Bounds: TMeterRange): TReadingStatus;
begin
  if Value < Bounds.Lower then Exit(rsLow);
  if Value > Bounds.Upper then Exit(rsHigh);
  Result := rsNormal;
end;

function RangeEntryTime(const S: TMeterSettings; const Bounds: TMeterRange;
  Side: TReadingStatus): Double;
var
  Start, Target, Boundary: Double;
begin
  Start := S.Values[mtInitial];
  Target := S.Values[mtTarget];
  // 待ち時間がなく即座に切り替わる場合、途中で表示されない初期値は警告に含めない。
  if ReadingStatus(Start, Bounds) = Side then
  begin
    if (S.Values[mtDelay] > 0) or (S.Values[mtDuration] > 0) or
      (ReadingStatus(Target, Bounds) = Side) then Exit(0);
    Exit(-1);
  end;
  if ReadingStatus(Target, Bounds) <> Side then Exit(-1);
  if Side = rsLow then Boundary := Bounds.Lower else Boundary := Bounds.Upper;
  Result := S.Values[mtDelay] + S.Values[mtDuration] * (Boundary - Start) / (Target - Start);
end;

function EvaluateMeter(const S: TMeterSettings; Seconds: Double): TMeterReading;
var
  Bounds: TMeterRange;
  T, Duration, Position, Entry: Double;
  P: TMeterPreset;
  Action: TOutOfRange;
begin
  Seconds := FiniteValue(Seconds, 0);
  Bounds := MeterRange(S);
  P := METER_PRESETS[S.Kind];
  T := Seconds - S.Values[mtDelay];
  Duration := S.Values[mtDuration];
  Position := 0;
  if T >= 0 then
    if (Duration = 0) or (T >= Duration) then Position := 1
    else Position := T / Duration;
  // 端点を直接使い、丸め誤差で到達値が範囲外になるのを防ぐ。
  if Position = 1 then Result.Number := S.Values[mtTarget]
  else Result.Number := S.Values[mtInitial] + (S.Values[mtTarget] - S.Values[mtInitial]) * Position;
  Result.Status := ReadingStatus(Result.Number, Bounds);
  Result.Display := EnsureRange(Result.Number, Bounds.Lower, Bounds.Upper);
  Result.Fraction := (Result.Display - Bounds.Lower) / (Bounds.Upper - Bounds.Lower);
  Result.MessageText := '';
  Result.BreakAge := -1;

  if (S.Kind = mkColumn) and ((S.Overflow = omBreak) or
    ((S.Overflow = omPreset) and (P.HighAction = oorBreak))) then
  begin
    // 毎フレーム同じ境界到達時刻を求め、シークしても破損状態を再現する。
    Entry := RangeEntryTime(S, Bounds, rsHigh);
    if (Entry >= 0) and (Seconds >= Entry) and
      ((Seconds > Entry) or (Result.Status = rsHigh)) then
    begin
      Result.BreakAge := Min(Seconds - Entry, 2.0);
      Result.Fraction := 1;
    end;
  end;
  if Result.Status = rsNormal then Exit;
  Action := oorClamp;
  case S.Overflow of
    omPreset:
      if Result.Status = rsLow then Action := P.LowAction else Action := P.HighAction;
    omExtend:
      begin
        Result.Display := Result.Number;
        Result.Fraction := EnsureRange((Result.Number - Bounds.Lower) /
          (Bounds.Upper - Bounds.Lower), -0.13, 1.13);
      end;
    omError: Action := oorError;
  end;
  case Action of
    oorLo: Result.MessageText := 'Lo';
    oorHi: Result.MessageText := 'Hi';
    oorL: Result.MessageText := 'L';
    oorH: Result.MessageText := 'H';
    oorError: Result.MessageText := 'Err';
    oorOL: Result.MessageText := 'OL';
  end;
end;

function FixedNumber(Value: Double; Decimals: Integer): string;
begin
  if Abs(Value) < 0.5 * IntPower(10, -Decimals) then Value := 0;
  Result := FloatToStrF(Value, ffFixed, 16, Decimals, TFormatSettings.Invariant);
end;

function DisplayDecimals(const S: TMeterSettings): Integer;
begin
  Result := Round(S.Values[mtDecimals]);
end;

function MeterTicks(const Bounds: TMeterRange; MaxIntervals: Integer): TArray<TMeterTick>;
const
  SUBDIVISIONS = 4;
var
  Span, RawStep, Power, Step, MinorStep, EndMargin, Value, Fraction: Double;
  Index, Decimals, Count: Integer;
  GridIndex: Int64;

  procedure AddTick(Number: Double; Labelled: Boolean);
  begin
    Result[Count].Fraction := (Number - Bounds.Lower) / Span;
    if Labelled then Result[Count].LabelText := FixedNumber(Number, Decimals);
    Inc(Count);
  end;

begin
  Span := Bounds.Upper - Bounds.Lower;
  RawStep := Span / MaxIntervals;
  Power := IntPower(10, Floor(Log10(RawStep)));
  Step := Power;
  if RawStep > Power then Step := 2 * Power;
  if RawStep > 2 * Power then Step := 5 * Power;
  if RawStep > 5 * Power then Step := 10 * Power;
  Decimals := EnsureRange(Ceil(-Log10(Step) - 0.00000001), 0, 6);
  // 中間目盛りが整数でも、端点の端数を落とさない。
  for Index := Decimals to 5 do
    if (Abs(Bounds.Lower - RoundTo(Bounds.Lower, -Index)) > 0.0000001) or
      (Abs(Bounds.Upper - RoundTo(Bounds.Upper, -Index)) > 0.0000001) then
      Decimals := Index + 1 else Break;
  // 端点近くはラベルを省き、補助目盛りは端数のある端点からも等間隔の格子を使う。
  MinorStep := Step / SUBDIVISIONS;
  EndMargin := Min(Span * 0.02, MinorStep * 0.49);
  SetLength(Result, MaxIntervals * SUBDIVISIONS + 3);
  Count := 0;
  AddTick(Bounds.Lower, True);
  GridIndex := Ceil((Bounds.Lower + EndMargin) / MinorStep);
  for Index := 0 to MaxIntervals * SUBDIVISIONS do
  begin
    Value := GridIndex * MinorStep;
    if Value >= Bounds.Upper - EndMargin then Break;
    Fraction := (Value - Bounds.Lower) / Span;
    AddTick(Value, (GridIndex mod SUBDIVISIONS = 0) and (Fraction > 0.105) and
      (Fraction < 0.895));
    Inc(GridIndex);
  end;
  AddTick(Bounds.Upper, True);
  SetLength(Result, Count);
end;

end.
