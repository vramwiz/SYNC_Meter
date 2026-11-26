unit Meter_Digital;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 共通のセグメント液晶と、測定器ごとの外装・操作部を描く。

interface

uses Meter_Canvas, Meter_Settings;

// 計器の外装、操作部、液晶の背景を描く。表示値は別の描画処理で重ねる。
procedure DrawDigitalBase(C: TMeterCanvas; const S: TMeterSettings);
// LCD に現在値または異常表示を描き、対応する計器では補助バーも更新する。
procedure DrawDigitalReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);

implementation

uses System.Math, Winapi.D2D1, Meter_Glyphs;

type
  TDisplay = record
    X, Y, W, H: Single;
  end;

const
  // 外装と表示の両方から参照する LCD のピクセル座標。アナログ計器には使わない。
  DISPLAYS: array[mkDigitalTemperature..mkLight] of TDisplay = (
    (X:79; Y:91; W:260; H:97),  // 温度
    (X:230; Y:66; W:183; H:77), // 体温
    (X:0; Y:0; W:0; H:0), (X:0; Y:0; W:0; H:0),
    (X:0; Y:0; W:0; H:0), (X:0; Y:0; W:0; H:0),
    (X:0; Y:0; W:0; H:0),
    (X:68; Y:66; W:224; H:112), // 電圧
    (X:82; Y:210; W:216; H:96), // 電流
    (X:0; Y:0; W:0; H:0), (X:0; Y:0; W:0; H:0),
    (X:124; Y:56; W:200; H:103), // 体重
    (X:127; Y:210; W:206; H:76), // はかり
    (X:62; Y:184; W:200; H:102), // 騒音
    (X:63; Y:85; W:248; H:115),  // 放射線
    (X:67; Y:173; W:200; H:105)); // 照度

procedure Key(C: TMeterCanvas; X, Y, Radius: Single; Body, Ink: Cardinal);
begin
  C.Disc(X, Y, Radius, Radius, Shade(Body, 1.43), Body, Shade(Body, 0.43));
  C.Ring(X, Y, Radius, Radius, 1, Shade(Body, 0.40));
  C.Line(X, Y - Radius * 0.43, X, Y + Radius * 0.04, 1.8, Ink);
end;

procedure Vents(C: TMeterCanvas; X, Y, W, Step: Single; Count: Integer; Color: Cardinal);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do C.Box(X, Y + I * Step, W, 3, 1.5, Color);
end;

procedure RadiationSymbol(C: TMeterCanvas; X, Y, R: Single; Color: Cardinal);
var
  I, J: Integer;
  A: Single;
  P: array[0..7] of TD2D1Point2F;
begin
  for I := 0 to 2 do
  begin
    A := I * 2 * Pi / 3 - Pi / 6;
    for J := 0 to 3 do
    begin
      P[J] := Polar(X, Y, R, A + J * Pi / 9);
      P[7-J] := Polar(X, Y, R * 0.37, A + J * Pi / 9);
    end;
    C.Polygon(P, Color);
  end;
  C.Oval(X, Y, R * 0.24, R * 0.24, Color);
end;

procedure DrawDigitalCase(C: TMeterCanvas; const S: TMeterSettings);
var
  Body, Face, Ink, Light, Dark, Accent: Cardinal;
  TitleX, TitleY, TitleWidth: Single;
  I: Integer;
begin
  Body := S.Colors[mcBody];
  Face := S.Colors[mcFace];
  Ink := S.Colors[mcInk];
  Light := Shade(Body, 1.50);
  Dark := Shade(Body, 0.46);
  Accent := S.Colors[mcWarning];
  TitleX := METER_PRESETS[S.Kind].Width * 0.5;
  TitleY := 54;
  TitleWidth := 180;
  case S.Kind of
    mkDigitalTemperature:
      begin
        C.Panel(24, 26, 372, 219, 38, Light, Body, Dark);
        C.Panel(38, 40, 344, 195, 26, Shade(Light, 1.20), Body, Shade(Body, 0.78));
        C.BoxEdge(38, 40, 344, 195, 26, 1.2, Light, 0.72);
        C.Box(121, 203, 64, 18, 8, Dark);
        C.Box(232, 203, 64, 18, 8, Dark);
        C.Line(139, 211, 167, 211, 1.5, Face);
        C.Line(250, 211, 278, 211, 1.5, Face);
        TitleY := 64;
        Ink := Shade(Face, 1.40);
      end;
    mkClinical:
      begin
        C.Panel(17, 89, 92, 22, 9, $E7EEF0, $AAB9BF, $647481);
        C.Panel(77, 77, 129, 46, 17, Light, Body, Dark);
        C.Panel(160, 45, 325, 111, 48, Light, Body, Dark);
        C.Line(173, 58, 220, 58, 1.6, Light);
        Key(C, 450, 101, 16, Mix(Body, Ink, 0.61), Face);
        TitleX := 192;
        TitleY := 100;
        TitleWidth := 50;
      end;
    mkVoltage:
      begin
        C.Panel(27, 19, 306, 381, 42, Light, Body, Dark);
        C.Panel(48, 43, 264, 331, 25, Shade(Ink, 1.50), Ink, Shade(Ink, 0.48));
        C.Disc(180, 256, 54, 54, Shade(Ink, 1.55), Ink, Shade(Ink, 0.36));
        C.Ring(180, 256, 58, 58, 2, Light, 0.66);
        C.Box(162, 211, 36, 90, 13, Body);
        C.Line(180, 221, 180, 238, 4.5, Face);
        for I := 0 to 2 do
        begin
          C.Oval(121 + I * 59, 340, 13, 13, Shade(Ink, 0.42));
          C.Ring(121 + I * 59, 340, 11, 11, 2.4, Accent);
        end;
        TitleY := 195;
        Ink := Face;
      end;
    mkCurrent:
      begin
        C.Ring(190, 97, 51, 51, 2, Shade(Body, 0.43));
        // 2つの半円で顎を作り、中央を透明に残す。
        C.Arc(190, 97, 60, -1.58, 1.54, 21, Light);
        C.Arc(190, 97, 60, 1.63, 4.64, 21, Body);
        C.Panel(67, 149, 246, 288, 32, Light, Body, Dark);
        C.Panel(75, 177, 230, 242, 24, Shade(Ink, 1.48), Ink, Shade(Ink, 0.51));
        C.Box(43, 182, 33, 71, 8, Shade(Body, 0.61));
        Key(C, 190, 362, 27, Body, Face);
        C.Box(108, 340, 34, 12, 5, Accent);
        C.Box(238, 340, 34, 12, 5, Accent);
        TitleY := 324;
        Ink := Face;
      end;
    mkBodyScale:
      begin
        C.Panel(15, 24, 418, 368, 47, Light, Body, Dark);
        C.Panel(23, 30, 402, 351, 39, Shade(Body, 1.32), Body, Shade(Body, 0.72));
        C.BoxEdge(24, 30, 400, 349, 39, 1.5, Shade(Body, 1.72), 0.68);
        for I := 0 to 1 do
        begin
          C.Panel(55 + I * 240, 174, 98, 159, 27, Light, Mix(Body, Face, 0.30), Dark);
          Vents(C, 70 + I * 240, 208, 68, 15, 6, Shade(Body, 0.64));
        end;
        TitleY := 355;
      end;
    mkScale:
      begin
        C.Panel(22, 127, 416, 175, 31, Light, Body, Dark);
        C.Polygon([Pt(51, 35), Pt(409, 35), Pt(440, 136), Pt(418, 166), Pt(42, 166),
          Pt(20, 136)], Dark);
        C.Polygon([Pt(56, 35), Pt(404, 35), Pt(427, 129), Pt(33, 129)], Light);
        C.Polygon([Pt(71, 48), Pt(390, 48), Pt(408, 115), Pt(52, 115)], Shade(Body, 1.30));
        C.Line(38, 142, 421, 142, 2, Shade(Body, 1.64), 0.68);
        C.Box(49, 226, 58, 44, 12, Dark);
        C.Box(353, 226, 58, 44, 12, Dark);
        MeterText(C, 'ZERO', 78, 247, 12, 42, Face);
        MeterText(C, 'TARE', 382, 247, 12, 42, Face);
        TitleY := 188;
        Ink := Face;
      end;
    mkSound:
      begin
        C.Panel(110, 29, 104, 128, 44, Shade(Ink, 1.32), Ink, Shade(Ink, 0.39));
        Vents(C, 124, 51, 76, 11, 6, Shade(Ink, 0.52));
        C.Panel(28, 129, 268, 307, 45, Light, Body, Dark);
        C.BoxEdge(39, 141, 246, 284, 37, 1.5, Light, 0.61);
        Key(C, 162, 358, 24, Shade(Body, 1.18), Face);
        C.Box(74, 341, 44, 17, 7, Dark);
        C.Box(206, 341, 44, 17, 7, Dark);
        C.Line(103, 401, 221, 401, 3, Light, 0.60);
        TitleY := 157;
        Ink := Face;
      end;
    mkRadiation:
      begin
        C.Panel(24, 24, 326, 330, 34, Light, Body, Dark);
        C.BoxEdge(36, 37, 302, 305, 24, 1.5, Light, 0.82);
        RadiationSymbol(C, 187, 263, 33, Ink);
        Vents(C, 56, 246, 68, 9, 5, Dark);
        Vents(C, 250, 246, 68, 9, 5, Dark);
        C.Box(130, 314, 114, 10, 4, Dark);
        TitleY := 60;
      end;
    mkLight:
      begin
        C.Panel(33, 98, 268, 310, 52, Light, Body, Dark);
        C.Disc(167, 78, 64, 61, Light, Body, Dark);
        C.Disc(167, 78, 48, 48, $FAFBED, $EAF2DF, $A5BED1);
        C.Ring(167, 78, 49, 49, 3, Dark);
        C.Oval(156, 66, 24, 18, $FFFFFF, 0.42);
        for I := -1 to 1 do Key(C, 167 + 58 * I, 338, 17, Body, Face);
        TitleY := 149;
        Ink := Face;
      end;
  end;
  MeterText(C, string(METER_PRESETS[S.Kind].Caption), TitleX, TitleY, 15, TitleWidth, Ink);
end;

procedure DrawDigitalBase(C: TMeterCanvas; const S: TMeterSettings);
var
  D: TDisplay;
  Face: Cardinal;
begin
  D := DISPLAYS[S.Kind];
  Face := S.Colors[mcFace];
  DrawDigitalCase(C, S);
  C.Box(D.X - 5, D.Y - 5, D.W + 10, D.H + 10, 12, Shade(S.Colors[mcBody], 0.40));
  C.Panel(D.X, D.Y, D.W, D.H, 8, Shade(Face, 1.20), Face, Shade(Face, 0.83));
  C.BoxEdge(D.X + 2, D.Y + 2, D.W - 4, D.H - 4, 6, 1, Shade(Face, 1.51), 0.65);
end;

procedure DrawDigitalReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);
var
  D: TDisplay;
  LabelText: string;
  Color: Cardinal;
  ValueY, ValueHeight, UnitY, CellWidth, Fill, X, Y: Single;
  I: Integer;
begin
  D := DISPLAYS[S.Kind];
  LabelText := Reading.MessageText;
  Color := S.Colors[mcWarning];
  if LabelText = '' then
  begin
    Color := S.Colors[mcReading];
    LabelText := FixedNumber(Reading.Display, DisplayDecimals(S));
  end;
  ValueY := 0.43;
  if S.UnitText = '' then ValueY := 0.50;
  ValueHeight := 0.60;
  UnitY := 0.85;
  if S.Kind in [mkVoltage, mkCurrent, mkRadiation] then
  begin
    // OL が表示されても下段のバーは上限を示す。
    ValueY := 0.38;
    if S.UnitText = '' then ValueY := 0.45;
    ValueHeight := 0.52;
    UnitY := 0.73;
    CellWidth := (D.W - 44) / 12;
    Y := D.Y + D.H * 0.88;
    for I := 0 to 11 do
    begin
      X := D.X + 22 + I * CellWidth;
      C.Box(X, Y, CellWidth - 2, D.H * 0.045, 1, S.Colors[mcReading], 0.18);
      Fill := EnsureRange(Reading.Fraction * 12 - I, 0.0, 1.0);
      if Fill > 0 then C.Box(X, Y, (CellWidth - 2) * Fill, D.H * 0.045, 1, Color);
    end;
    if Reading.Fraction < 0 then C.Box(D.X + 13, Y, 5, D.H * 0.045, 1, S.Colors[mcWarning]);
    if Reading.Fraction > 1 then C.Box(D.X + D.W - 18, Y, 5, D.H * 0.045, 1, S.Colors[mcWarning]);
  end;
  MeterText(C, LabelText, D.X + D.W * 0.5, D.Y + D.H * ValueY, D.H * ValueHeight,
    D.W - 21, Color, mdSegment);
  MeterText(C, S.UnitText, D.X + D.W * 0.5, D.Y + D.H * UnitY, D.H * 0.16,
    D.W - 32, S.Colors[mcReading]);
end;

end.
