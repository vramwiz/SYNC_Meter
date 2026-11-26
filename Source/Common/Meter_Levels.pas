unit Meter_Levels;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 液柱、残量バー、水位表示を描画する。破損は発生からの経過秒だけで再現する。

interface

uses Meter_Canvas, Meter_Settings;

// 外装と目盛りを描く。計測値や破損の進行に依存しない静的レイヤー。
procedure DrawLevelBase(C: TMeterCanvas; const S: TMeterSettings);
// 液面・残量と警告を既存の外装に合成する。破損の進行は発生からの経過秒で指定する。
procedure DrawLevelReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);

implementation

uses System.Math, Winapi.D2D1, Meter_Glyphs;

const
  TUBE_X = 156;
  SCALE_TOP = 196;
  SCALE_BOTTOM = 511;
  BULB_Y = 550;
  BREAK_Y = 228;
  SHATTER_TIME = 0.19;
  TANK_TOP = 116;
  TANK_BOTTOM = 382;
  BATTERY_CELLS = 9;

function LevelY(Fraction, Top, Bottom: Single): Single;
begin
  Result := Bottom - (Bottom - Top) * Fraction;
end;

procedure Alert(C: TMeterCanvas; const S: TMeterSettings; const Reading: TMeterReading;
  X, Y: Single);
begin
  if Reading.MessageText = '' then Exit;
  C.Box(X - 47, Y - 16, 94, 32, 7, Shade(S.Colors[mcFace], 0.88));
  MeterText(C, Reading.MessageText, X, Y, 23, 75, S.Colors[mcWarning], mdSegment);
end;

procedure DrawLevelScale(C: TMeterCanvas; const S: TMeterSettings; Top, Bottom, TickX,
  LabelX: Single);
var
  Ticks: TArray<TMeterTick>;
  Y: Single;
  I: Integer;
  Ink: Cardinal;
begin
  Ink := S.Colors[mcInk];
  Ticks := MeterTicks(MeterRange(S), 8);
  for I := 0 to High(Ticks) do
  begin
    Y := LevelY(Ticks[I].Fraction, Top, Bottom);
    if Ticks[I].LabelText = '' then
    begin
      C.Line(TickX, Y, TickX + 7, Y, 1.2, Ink, 0.63);
      Continue;
    end;
    C.Line(TickX, Y, TickX + 13, Y, 2.2, Ink);
    MeterText(C, Ticks[I].LabelText, LabelX, Y, 15, 49, Ink);
  end;
end;

procedure DrawColumnBase(C: TMeterCanvas; const S: TMeterSettings);
var
  Body, Face, Ink: Cardinal;
begin
  Body := S.Colors[mcBody];
  Face := S.Colors[mcFace];
  Ink := S.Colors[mcInk];
  C.BoxEdge(161, 85, 38, 35, 13, 5, Shade(Body, 1.28));
  C.Panel(84, 104, 192, 504, 48, Shade(Body, 1.58), Body, Shade(Body, 0.49));
  C.Panel(97, 116, 166, 475, 38, Shade(Face, 1.30), Face, Shade(Face, 0.86));
  C.BoxEdge(97, 116, 166, 475, 38, 1.5, Shade(Body, 0.55), 0.55);
  C.Box(115, 163, 78, 407, 34, Shade(Body, 0.60), 0.16);
  C.Line(185, SCALE_TOP, 185, SCALE_BOTTOM, 1.2, Ink, 0.48);
  DrawLevelScale(C, S, SCALE_TOP, SCALE_BOTTOM, 185, 229);
  MeterText(C, string(METER_PRESETS[S.Kind].Caption), 180, 137, 16, 135, Ink);
  MeterText(C, S.UnitText, 225, 170, 20, 53, Ink);
end;

procedure GlassTube(C: TMeterCanvas; Y, Bottom: Single; const S: TMeterSettings);
var
  Glass, Edge: Cardinal;
begin
  Glass := Mix(S.Colors[mcFace], $D1F2FA, 0.70);
  Edge := Mix(S.Colors[mcBody], $6C899A, 0.38);
  C.Box(TUBE_X - 15, Y, 30, Bottom - Y, 15, Glass, 0.8);
  C.BoxEdge(TUBE_X - 15, Y, 30, Bottom - Y, 15, 2.2, Edge);
end;

procedure DrawCracks(C: TMeterCanvas; const S: TMeterSettings; Age: Single);
var
  Spread: Single;
  Ink: Cardinal;
begin
  Spread := EnsureRange(0.28 + Age / SHATTER_TIME, 0.0, 1.0);
  Ink := Shade(S.Colors[mcInk], 0.55);
  C.StrokePath([Pt(TUBE_X - 15, BREAK_Y - 8 * Spread), Pt(TUBE_X - 4, BREAK_Y),
    Pt(TUBE_X + 4, BREAK_Y - 8 * Spread), Pt(TUBE_X + 15, BREAK_Y + 4 * Spread)], 1.6, Ink);
  C.StrokePath([Pt(TUBE_X - 4, BREAK_Y), Pt(TUBE_X - 5, BREAK_Y + 14 * Spread),
    Pt(TUBE_X - 15, BREAK_Y + 25 * Spread)], 1.25, Ink);
  C.StrokePath([Pt(TUBE_X + 4, BREAK_Y - 8 * Spread), Pt(TUBE_X + 7, BREAK_Y - 23 * Spread),
    Pt(TUBE_X + 14, BREAK_Y - 29 * Spread)], 1.25, Ink);
end;

// 粒子番号と成分番号ごとに固定の値を得る。発生順や前フレームに依存しない。
function ParticleFactor(Index, Salt: Integer): Single;
begin
  Result := ((Index * 167 + Salt * 389 + Index * Index * (Salt + 5) * 37) mod 1013) / 1013;
end;

procedure DrawShatter(C: TMeterCanvas; const S: TMeterSettings; Age: Single);
var
  X, Y, A, R, T, SpeedX, SpeedY, Alpha: Single;
  I: Integer;
  Liquid: Cardinal;
begin
  Liquid := S.Colors[mcReading];
  Age := Age - SHATTER_TIME;
  if Age < 0.62 then
  begin
    X := TUBE_X - 134 * Age;
    Y := BREAK_Y - 269 * Age + 360 * Age * Age;
    A := Age * 5.8 - 0.45;
    Alpha := 1 - Age / 0.62;
    C.Polygon([Polar(X, Y, 21, A), Polar(X, Y, 16, A + 0.66),
      Polar(X, Y, 17, A + 3.38), Polar(X, Y, 15, A + 3.87)],
      Mix(S.Colors[mcFace], $CDEEF0, 0.74), Alpha);
  end;
  for I := 1 to 34 do
  begin
    T := Age - 0.12 * ParticleFactor(I, 1);
    if T < 0 then Continue;
    Alpha := EnsureRange(1.30 - 1.05 * T, 0.0, 1.0);
    if Alpha <= 0 then Continue;
    SpeedX := (ParticleFactor(I, 2) - 0.5) * 560;
    SpeedY := 142 + ParticleFactor(I, 3) * 267;
    X := TUBE_X + SpeedX * T;
    Y := BREAK_Y - SpeedY * T + 420 * T * T;
    if (X < 8) or (X > 352) or (Y < 8) or (Y > 632) then Continue;
    R := 2.1 + ParticleFactor(I, 4) * 5.2;
    if I <= 12 then
    begin
      A := I * 1.63 + T * (3 + I * 0.32);
      C.Polygon([Polar(X, Y, R * 1.45, A), Polar(X, Y, R * 0.9, A + 1.7),
        Polar(X, Y, R, A + 4)], Mix(S.Colors[mcFace], $BAEBF5, 0.7), Alpha);
      C.Line(X, Y, X + R * 0.53, Y - R * 0.51, 1.15, $FFFFFF, Alpha);
    end
    else
      C.Oval(X, Y, R * 0.75, R * 1.14, Liquid, Alpha);
  end;
end;

procedure DrawColumnReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);
var
  Y, GlassTop, Age: Single;
  Liquid, Edge: Cardinal;
begin
  Age := Reading.BreakAge;
  Liquid := S.Colors[mcReading];
  Edge := Shade(S.Colors[mcBody], 0.58);
  GlassTop := 156;
  Y := LevelY(Reading.Fraction, SCALE_TOP, SCALE_BOTTOM);
  if Age >= SHATTER_TIME then
  begin
    GlassTop := BREAK_Y;
    Y := BREAK_Y + Min(1.0, (Age - SHATTER_TIME) / 0.73) * 112;
    C.Polygon([Pt(TUBE_X - 15, BREAK_Y + 10), Pt(TUBE_X - 15, BREAK_Y - 6),
      Pt(TUBE_X - 5, BREAK_Y + 4), Pt(TUBE_X + 4, BREAK_Y - 7),
      Pt(TUBE_X + 15, BREAK_Y + 4), Pt(TUBE_X + 15, BREAK_Y + 12)],
      Mix(S.Colors[mcFace], $CDEEF0, 0.74));
  end;
  GlassTube(C, GlassTop, BULB_Y, S);
  // 液柱を先に描き、球部で下端をつなぐ。
  C.Line(TUBE_X, Y, TUBE_X, BULB_Y, 10, Liquid);
  C.Line(TUBE_X - 2, Y + 1, TUBE_X - 2, BULB_Y - 9, 2.1, Shade(Liquid, 1.49), 0.86);
  C.Disc(TUBE_X, BULB_Y, 24, 24, Shade(Liquid, 1.60), Liquid, Shade(Liquid, 0.63));
  C.Ring(TUBE_X, BULB_Y, 24, 24, 2.4, Edge);
  C.Line(TUBE_X - 9, GlassTop + 12, TUBE_X - 9, BULB_Y - 25, 2, $FFFFFF, 0.73);
  C.Oval(TUBE_X - 8, BULB_Y - 8, 6.5, 4.3, $FFFFFF, 0.53);
  if Age >= SHATTER_TIME then
  begin
    C.StrokePath([Pt(TUBE_X - 15, BREAK_Y + 2), Pt(TUBE_X - 5, BREAK_Y + 12),
      Pt(TUBE_X + 4, BREAK_Y - 1), Pt(TUBE_X + 15, BREAK_Y + 7)], 1.8, Edge);
    DrawShatter(C, S, Age);
  end
  else if Age >= 0 then DrawCracks(C, S, Age);
  Alert(C, S, Reading, 224, 558);
end;

procedure DrawBatteryBase(C: TMeterCanvas; const S: TMeterSettings);
var
  Body, Face, Ink: Cardinal;
  I: Integer;
begin
  Body := S.Colors[mcBody];
  Face := S.Colors[mcFace];
  Ink := S.Colors[mcInk];
  C.Panel(418, 86, 32, 53, 8, Shade(Body, 1.50), Body, Shade(Body, 0.52));
  C.Panel(16, 22, 420, 186, 35, Shade(Body, 1.57), Body, Shade(Body, 0.43));
  C.Panel(30, 40, 392, 149, 24, Shade(Face, 1.22), Face, Shade(Face, 0.72));
  C.BoxEdge(30, 40, 392, 149, 24, 1.4, Shade(Body, 0.38));
  C.Polygon([Pt(66, 52), Pt(54, 71), Pt(64, 71), Pt(59, 86), Pt(79, 65),
    Pt(68, 65), Pt(72, 52)], Ink);
  MeterText(C, 'BATTERY', 125, 68, 15, 83, Ink);
  for I := 0 to BATTERY_CELLS - 1 do
    C.Box(49 + I * 40, 98, 34, 50, 5, Mix(Face, S.Colors[mcReading], 0.17));
  C.Line(51, 161, 400, 161, 1, Ink, 0.23);
end;

procedure DrawBatteryReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);
var
  Color: Cardinal;
  Fill, X: Single;
  I: Integer;
begin
  Color := S.Colors[mcReading];
  if Reading.Fraction < 0.19 then Color := S.Colors[mcWarning];
  for I := 0 to BATTERY_CELLS - 1 do
  begin
    Fill := EnsureRange(Reading.Fraction * BATTERY_CELLS - I, 0.0, 1.0);
    if Fill < 0.001 then Break;
    X := 49 + I * 40;
    C.Panel(X, 98, 34 * Fill, 50, 5, Shade(Color, 1.50), Color, Shade(Color, 0.66));
  end;
  if Reading.Fraction < 0 then C.Box(36, 107, 8, 32, 4, S.Colors[mcWarning]);
  if Reading.Fraction > 1 then C.Box(405, 107, 10, 32, 4, S.Colors[mcWarning]);
  if Reading.MessageText <> '' then Alert(C, S, Reading, 315, 67)
  else MeterText(C, FixedNumber(Reading.Display, DisplayDecimals(S)) + ' ' + S.UnitText,
    225, 174, 17, 300, S.Colors[mcInk]);
end;

procedure DrawWaterBase(C: TMeterCanvas; const S: TMeterSettings);
var
  Body, Face, Ink: Cardinal;
begin
  Body := S.Colors[mcBody];
  Face := S.Colors[mcFace];
  Ink := S.Colors[mcInk];
  C.Box(124, 10, 80, 31, 7, Shade(Body, 0.71));
  C.Panel(22, 28, 284, 413, 31, Shade(Body, 1.58), Body, Shade(Body, 0.51));
  C.Panel(37, 45, 254, 378, 22, Shade(Face, 1.26), Face, Shade(Face, 0.82));
  C.BoxEdge(37, 45, 254, 378, 22, 2, Shade(Body, 0.49));
  C.Box(67, 79, 133, 341, 13, Shade(Face, 0.63));
  C.BoxEdge(67, 79, 133, 341, 13, 1.7, Ink, 0.52);
  DrawLevelScale(C, S, TANK_TOP, TANK_BOTTOM, 206, 254);
  MeterText(C, 'WATER LEVEL', 164, 63, 16, 175, Ink);
  MeterText(C, S.UnitText, 250, 91, 17, 60, Ink);
  C.Line(97, 436, 233, 436, 2.3, Shade(Body, 1.28), 0.78);
end;

procedure DrawWaterReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);
var
  Points: array[0..14] of TD2D1Point2F;
  Y, X: Single;
  Color: Cardinal;
  I: Integer;
begin
  Color := S.Colors[mcReading];
  Y := LevelY(Reading.Fraction, TANK_TOP, TANK_BOTTOM);
  if Reading.Fraction <> 0 then
  begin
    // 上限を超えるモードでも、液面と反射をタンク内に収める。
    C.PushClip(69, 81, 129, 336);
    try
      if Reading.Fraction > 0 then
      begin
        for I := 0 to 12 do
        begin
          X := 69 + I * 10.75;
          Points[I] := Pt(X, Y + Sin(I * 0.60 + Reading.Fraction * 9) * 3.1);
        end;
        Points[13] := Pt(198, TANK_BOTTOM);
        Points[14] := Pt(69, TANK_BOTTOM);
        C.Polygon(Points, Color, 0.86);
        C.StrokePath(Slice(Points, 13), 3.1, Shade(Color, 1.63), 0.86);
      end
      else C.Line(74, Y, 192, Y, 2.1, S.Colors[mcWarning]);
      C.Line(79, 96, 79, 402, 4.1, $FFFFFF, 0.16);
      C.Line(188, 96, 188, 402, 2.1, $FFFFFF, 0.14);
    finally
      C.PopClip;
    end;
  end;
  Alert(C, S, Reading, 133, 235);
end;

procedure DrawLevelBase(C: TMeterCanvas; const S: TMeterSettings);
begin
  case S.Kind of
    mkColumn: DrawColumnBase(C, S);
    mkBattery: DrawBatteryBase(C, S);
    mkWater: DrawWaterBase(C, S);
  end;
end;

procedure DrawLevelReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);
begin
  case S.Kind of
    mkColumn: DrawColumnReading(C, S, Reading);
    mkBattery: DrawBatteryReading(C, S, Reading);
    mkWater: DrawWaterReading(C, S, Reading);
  end;
end;

end.
