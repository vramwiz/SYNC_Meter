unit Meter_Analog;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 円形・扇形の文字盤を共通の座標と目盛りで描き、各計器の外装を作る。

interface

uses Meter_Canvas, Meter_Settings;

procedure DrawAnalogBase(C: TMeterCanvas; const S: TMeterSettings);
procedure DrawAnalogReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);

implementation

uses System.Math, Winapi.D2D1, Meter_Glyphs;

type
  TDial = record
    X, Y, Radius, StartAngle, Sweep, CaptionY, UnitY, AlertY: Single;
  end;

function DialLayout(Kind: TMeterKind): TDial;
var
  P: TMeterPreset;
begin
  P := METER_PRESETS[Kind];
  Result.X := P.Width * 0.5;
  Result.Y := P.Width * 0.5;
  Result.Radius := Min(P.Width, P.Height) * 0.407;
  Result.StartAngle := -2.27;
  Result.Sweep := 4.54;
  Result.CaptionY := Result.Y - 62;
  Result.UnitY := Result.Y + 49;
  Result.AlertY := Result.Y + 118;
  case Kind of
    mkBarometer:
      begin
        Result.StartAngle := -2.55;
        Result.Sweep := 5.10;
      end;
    mkSpeed:
      begin
        Result.Y := 213;
        Result.Radius := 178;
        Result.CaptionY := 143;
        Result.UnitY := 264;
        Result.AlertY := 330;
      end;
    mkPressure:
      begin
        Result.Y := 208;
        Result.CaptionY := 141;
        Result.UnitY := 255;
        Result.AlertY := 324;
      end;
    mkPower:
      begin
        Result.Y := 249;
        Result.Radius := 172;
        Result.StartAngle := -1.18;
        Result.Sweep := 2.36;
        Result.CaptionY := 184;
        Result.UnitY := 214;
        Result.AlertY := 284;
      end;
    mkFuel:
      begin
        Result.Y := 211;
        Result.Radius := 138;
        Result.StartAngle := -1.12;
        Result.Sweep := 2.24;
        Result.CaptionY := 150;
        Result.UnitY := 176;
        Result.AlertY := 242;
      end;
  end;
end;

procedure Screw(C: TMeterCanvas; X, Y: Single; Color: Cardinal);
begin
  C.Disc(X, Y, 6, 6, Shade(Color, 1.58), Color, Shade(Color, 0.66));
  C.Line(X - 2.7, Y + 2, X + 2.6, Y - 2, 1.15, Shade(Color, 0.39));
end;

procedure DialArc(C: TMeterCanvas; const D: TDial; Radius, Start, Stop, Width: Single;
  Color: Cardinal);
begin
  C.Arc(D.X, D.Y, Radius, D.StartAngle + D.Sweep * Start, D.StartAngle + D.Sweep * Stop, Width, Color);
end;

procedure RadialMark(C: TMeterCanvas; const D: TDial; Angle, Radius, Length, Width: Single;
  Color: Cardinal);
var
  Inner, Outer: TD2D1Point2F;
begin
  Outer := Polar(D.X, D.Y, Radius, Angle);
  Inner := Polar(D.X, D.Y, Radius - Length, Angle);
  C.Line(Inner.X, Inner.Y, Outer.X, Outer.Y, Width, Color);
end;

procedure DrawDialTicks(C: TMeterCanvas; const S: TMeterSettings; const D: TDial);
var
  Ticks: TArray<TMeterTick>;
  Bounds: TMeterRange;
  I, Intervals: Integer;
  Angle, TextWidth: Single;
  LabelText: string;
  P: TD2D1Point2F;
  Ink: Cardinal;
begin
  Bounds := MeterRange(S);
  Intervals := 7;
  if METER_PRESETS[S.Kind].Method = mmFan then Intervals := 5;
  if S.Kind = mkFuel then Intervals := 4;
  Ticks := MeterTicks(Bounds, Intervals);
  Ink := S.Colors[mcInk];
  for I := 0 to High(Ticks) do
  begin
    Angle := D.StartAngle + D.Sweep * Ticks[I].Fraction;
    if Ticks[I].LabelText = '' then
    begin
      RadialMark(C, D, Angle, D.Radius - 2, 8, 1.5, Ink);
      Continue;
    end;
    RadialMark(C, D, Angle, D.Radius - 1, 18, 2.6, Ink);
    P := Polar(D.X, D.Y, D.Radius - 35, Angle);
    TextWidth := 67;
    if METER_PRESETS[S.Kind].Method = mmFan then TextWidth := 36;
    LabelText := Ticks[I].LabelText;
    if (S.Kind = mkFuel) and (S.UnitText = 'E・F') then
    begin
      LabelText := '';
      if I = 0 then LabelText := 'E';
      if I = High(Ticks) then LabelText := 'F';
    end;
    MeterText(C, LabelText, P.X, P.Y, 22, TextWidth, Ink);
  end;
end;

procedure DrawDialCase(C: TMeterCanvas; const S: TMeterSettings; const D: TDial);
var
  Body, Face: Cardinal;
  R, X, Y: Single;
begin
  Body := S.Colors[mcBody];
  Face := S.Colors[mcFace];
  X := D.X;
  Y := D.Y;
  R := D.Radius + 27;
  case S.Kind of
    mkAnalogTemperature:
      begin
        C.Panel(27, 27, 386, 386, 43, Shade(Body, 1.48), Body, Shade(Body, 0.66));
        Screw(C, 48, 49, Body);
        Screw(C, 392, 49, Body);
        Screw(C, 48, 391, Body);
        Screw(C, 392, 391, Body);
        R := 191;
      end;
    mkHumidity:
      begin
        C.Panel(17, 115, 406, 210, 42, Shade(Body, 1.40), Body, Shade(Body, 0.55));
        for var I := 0 to 5 do
        begin
          C.Line(29, 167 + I * 20, 65, 167 + I * 20, 4, Shade(Body, 0.46));
          C.Line(375, 167 + I * 20, 411, 167 + I * 20, 4, Shade(Body, 0.46));
        end;
        R := 187;
      end;
    mkBarometer:
      begin
        C.BoxEdge(203, 6, 54, 41, 18, 6, Body);
        C.Disc(X, Y, 216, 216, Shade(Body, 1.63), Body, Shade(Body, 0.54));
        C.Ring(X, Y, 204, 204, 2, Shade(Body, 1.77), 0.8);
        R := 200;
      end;
    mkSpeed:
      begin
        C.Panel(20, 46, 440, 345, 90, Shade(Body, 1.28), Body, Shade(Body, 0.55));
        R := 198;
      end;
    mkTachometer:
      begin
        C.Panel(177, 369, 86, 54, 9, Shade(Body, 1.45), Body, Shade(Body, 0.43));
        R := 199;
      end;
    mkPressure:
      begin
        C.Panel(189, 355, 42, 84, 6, Shade(Body, 1.57), Body, Shade(Body, 0.44));
        C.Polygon([Pt(177, 423), Pt(242, 423), Pt(251, 437), Pt(240, 455), Pt(178, 455),
          Pt(168, 438)], Shade(Body, 1.26));
        C.Line(177, 439, 243, 439, 2, Shade(Body, 0.57), 0.55);
        R := 192;
      end;
  end;
  C.Disc(X, Y, R, R, Shade(Body, 1.55), Body, Shade(Body, 0.42));
  R := R - 9;
  C.Disc(X, Y, R, R, Shade(Face, 1.16), Face, Shade(Face, 0.84));
  C.Ring(X, Y, R, R, 2, Shade(Body, 0.43));
  C.Ring(X, Y, R - 4, R - 4, 1, Shade(Face, 1.57), 0.49);
end;

procedure DrawFanCase(C: TMeterCanvas; const S: TMeterSettings);
var
  Body, Face: Cardinal;
begin
  Body := S.Colors[mcBody];
  Face := S.Colors[mcFace];
  if S.Kind = mkFuel then
  begin
    C.Panel(15, 28, 360, 233, 58, Shade(Body, 1.42), Body, Shade(Body, 0.39));
    C.Panel(33, 45, 324, 192, 48, Shade(Face, 1.20), Face, Shade(Face, 0.81));
    C.BoxEdge(33, 45, 324, 192, 48, 1.8, Shade(Body, 0.45));
    Exit;
  end;
  C.Panel(12, 12, 426, 302, 22, Shade(Body, 1.44), Body, Shade(Body, 0.54));
  C.Panel(35, 33, 380, 234, 12, Shade(Face, 1.27), Face, Shade(Face, 0.91));
  C.BoxEdge(35, 33, 380, 234, 12, 2, Shade(Body, 0.43));
  Screw(C, 27, 289, Body);
  Screw(C, 423, 289, Body);
  C.Line(53, 279, 397, 279, 1, Shade(Body, 1.33));
end;

procedure DrawDialDetails(C: TMeterCanvas; const S: TMeterSettings; const D: TDial);
var
  Ink, Warning: Cardinal;
begin
  Ink := S.Colors[mcInk];
  Warning := S.Colors[mcWarning];
  case S.Kind of
    mkAnalogTemperature:
      begin
        DialArc(C, D, D.Radius + 5, 0, 0.23, 3, Mix(S.Colors[mcBody], $199DB1, 0.64));
        DialArc(C, D, D.Radius + 5, 0.76, 1, 3, Warning);
      end;
    mkHumidity:
      begin
        DialArc(C, D, D.Radius + 3, 0.41, 0.67, 4.5, S.Colors[mcReading]);
        C.Polygon([Pt(D.X, D.Y + 77), Pt(D.X - 7, D.Y + 89),
          Pt(D.X - 4, D.Y + 94), Pt(D.X + 4, D.Y + 94), Pt(D.X + 7, D.Y + 89)], Ink);
      end;
    mkBarometer:
      begin
        C.Line(D.X - 67, D.Y - 33, D.X + 67, D.Y - 33, 1, Ink, 0.56);
        MeterText(C, 'RAIN', D.X - 63, D.Y + 86, 13, 40, Ink);
        MeterText(C, 'FAIR', D.X + 63, D.Y + 86, 13, 40, Ink);
      end;
    mkSpeed:
      begin
        DialArc(C, D, D.Radius + 7, 0, 1, 2, S.Colors[mcReading]);
        C.Box(191, 310, 98, 36, 8, Shade(S.Colors[mcFace], 0.59));
        C.BoxEdge(191, 310, 98, 36, 8, 1, Ink, 0.22);
      end;
    mkTachometer:
      begin
        DialArc(C, D, D.Radius + 4, 0.72, 1, 6.5, Warning);
        for var I := 0 to 4 do
          C.Box(D.X - 38 + I * 16, D.Y + 90, 12, 4, 2, Warning, 0.34 + I * 0.14);
      end;
    mkPressure:
      begin
        DialArc(C, D, D.Radius + 3, 0.82, 1, 4, Warning);
        Screw(C, D.X, D.Y + 93, S.Colors[mcBody]);
      end;
    mkPower: DialArc(C, D, D.Radius + 4, 0, 1, 1.8, Ink);
    mkFuel:
      begin
        DialArc(C, D, D.Radius + 3, 0, 0.16, 5, Warning);
        C.BoxEdge(D.X - 7, D.Y - 96, 11, 13, 2, 1.7, Ink);
        C.Line(D.X - 10, D.Y - 82, D.X + 7, D.Y - 82, 1.6, Ink);
        C.StrokePath([Pt(D.X + 4, D.Y - 86), Pt(D.X + 11, D.Y - 88),
          Pt(D.X + 11, D.Y - 94), Pt(D.X + 8, D.Y - 97)], 1.5, Ink);
      end;
  end;
end;

procedure DrawAnalogBase(C: TMeterCanvas; const S: TMeterSettings);
var
  D: TDial;
  Ink: Cardinal;
begin
  D := DialLayout(S.Kind);
  Ink := S.Colors[mcInk];
  if METER_PRESETS[S.Kind].Method = mmFan then DrawFanCase(C, S)
  else DrawDialCase(C, S, D);
  DrawDialDetails(C, S, D);
  DrawDialTicks(C, S, D);
  MeterText(C, string(METER_PRESETS[S.Kind].Caption), D.X, D.CaptionY, 17, 128, Ink);
  if (S.Kind <> mkFuel) or (S.UnitText <> 'E・F') then
    MeterText(C, S.UnitText, D.X, D.UnitY, 26, 114, Ink);
end;

procedure DrawAnalogReading(C: TMeterCanvas; const S: TMeterSettings;
  const Reading: TMeterReading);
var
  D: TDial;
  A, L, TailLength: Single;
  Tip, Tail, LeftSide, RightSide: TD2D1Point2F;
  Needle, Face: Cardinal;
begin
  D := DialLayout(S.Kind);
  Face := S.Colors[mcFace];
  Needle := S.Colors[mcReading];
  if Reading.MessageText <> '' then Needle := S.Colors[mcWarning];
  A := D.StartAngle + D.Sweep * Reading.Fraction;
  L := D.Radius - 14;
  TailLength := 22;
  if S.Kind in [mkFuel, mkPower] then TailLength := 11;
  Tip := Polar(D.X, D.Y, L, A);
  Tail := Polar(D.X, D.Y, -TailLength, A);
  LeftSide := Polar(D.X, D.Y, 5, A - Pi / 2);
  RightSide := Polar(D.X, D.Y, 5, A + Pi / 2);
  C.Line(Tail.X + 2, Tail.Y + 3, Tip.X + 2, Tip.Y + 3, 5.2, Shade(Face, 0.2), 0.32);
  C.Polygon([Tip, LeftSide, Tail, RightSide], Needle);
  C.Line(D.X, D.Y, Tip.X, Tip.Y, 1.4, Shade(Needle, 1.64), 0.66);
  C.Disc(D.X, D.Y, 13, 13, Shade(S.Colors[mcBody], 1.55), S.Colors[mcBody], Shade(S.Colors[mcBody], 0.52));
  C.Oval(D.X, D.Y, 4.2, 4.2, Needle);
  if Reading.MessageText <> '' then
  begin
    C.Box(D.X - 43, D.AlertY - 15, 86, 30, 6, Face);
    MeterText(C, Reading.MessageText, D.X, D.AlertY, 23, 70, S.Colors[mcWarning], mdSegment);
  end
  else if S.Kind = mkSpeed then
    MeterText(C, FixedNumber(Reading.Display, DisplayDecimals(S)), D.X, D.AlertY - 2,
      22, 79, S.Colors[mcReading], mdSegment);
end;

end.
