unit Meter_Canvas;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 時計演出の Direct2D キャンバスを流用し、計測器の共通図形を描画する。

interface

uses Winapi.D2D1;

type
  TMeterCanvas = class
  private
    FFactory: ID2D1Factory;
    FTarget: ID2D1RenderTarget;
    FBrush: ID2D1SolidColorBrush;
    FRound: ID2D1StrokeStyle;
    procedure SetColor(Color: Cardinal; Alpha: Single);
    function Gradient(X, Y, W, H: Single; Color1, Color2, Color3: Cardinal;
      Alpha1, Alpha2, Alpha3: Single): ID2D1LinearGradientBrush;
    function Outline(const Points: array of TD2D1Point2F; Filled, Closed: Boolean): ID2D1PathGeometry;
  public
    constructor Create(const Factory: ID2D1Factory; const Target: ID2D1RenderTarget);
    procedure Arc(X, Y, Radius, Start, Stop, Width: Single; Color: Cardinal);
    procedure PushClip(X, Y, W, H: Single);
    procedure PopClip;
    procedure Line(X1, Y1, X2, Y2, Stroke: Single; Color: Cardinal; Alpha: Single = 1);
    procedure Oval(X, Y, RX, RY: Single; Color: Cardinal; Alpha: Single = 1);
    procedure Ring(X, Y, RX, RY, Stroke: Single; Color: Cardinal; Alpha: Single = 1);
    procedure Box(X, Y, W, H, Radius: Single; Color: Cardinal; Alpha: Single = 1);
    procedure BoxEdge(X, Y, W, H, Radius, Stroke: Single; Color: Cardinal; Alpha: Single = 1);
    procedure Panel(X, Y, W, H, Radius: Single; Color1, Color2, Color3: Cardinal);
    procedure Disc(X, Y, RX, RY: Single; Color1, Color2, Color3: Cardinal);
    procedure Polygon(const Points: array of TD2D1Point2F; Color: Cardinal; Alpha: Single = 1);
    procedure StrokePath(const Points: array of TD2D1Point2F; Width: Single;
      Color: Cardinal; Alpha: Single = 1; Closed: Boolean = False);
  end;

function Shade(Color: Cardinal; Factor: Single): Cardinal;
function Mix(First, Second: Cardinal; Weight: Single): Cardinal;
function Pt(X, Y: Single): TD2D1Point2F; inline;
function Polar(X, Y, Radius, Angle: Single): TD2D1Point2F;

implementation

uses System.Math, System.Win.ComObj;

function Pt(X, Y: Single): TD2D1Point2F;
begin
  Result := D2D1PointF(X, Y);
end;

function Polar(X, Y, Radius, Angle: Single): TD2D1Point2F;
begin
  Result := Pt(X + Sin(Angle) * Radius, Y - Cos(Angle) * Radius);
end;

function Mix(First, Second: Cardinal; Weight: Single): Cardinal;
var
  Shift: Integer;
  A, B: Cardinal;
begin
  Result := 0;
  for Shift in [0, 8, 16] do
  begin
    A := (First shr Shift) and 255;
    B := (Second shr Shift) and 255;
    Result := Result or (Cardinal(Round(A * (1 - Weight) + B * Weight)) shl Shift);
  end;
end;

function Shade(Color: Cardinal; Factor: Single): Cardinal;
begin
  if Factor <= 1 then Result := Mix(0, Color, Max(0.0, Factor))
  else Result := Mix(Color, $FFFFFF, Min(1.0, Factor - 1));
end;

function RGBA(Color: Cardinal; Alpha: Single): TD2D1ColorF;
begin
  Result := D2D1ColorF(((Color shr 16) and 255) / 255,
    ((Color shr 8) and 255) / 255, (Color and 255) / 255, Alpha);
end;

function Rounded(X, Y, W, H, Radius: Single): TD2D1RoundedRect;
begin
  Radius := Min(Radius, Min(W, H) * 0.5);
  Result := D2D1RoundedRect(D2D1RectF(X, Y, X + W, Y + H), Radius, Radius);
end;

constructor TMeterCanvas.Create(const Factory: ID2D1Factory; const Target: ID2D1RenderTarget);
var
  Properties: TD2D1StrokeStyleProperties;
begin
  inherited Create;
  FFactory := Factory;
  FTarget := Target;
  OleCheck(FTarget.CreateSolidColorBrush(RGBA(0, 1), nil, FBrush));
  Properties := D2D1StrokeStyleProperties(D2D1_CAP_STYLE_ROUND, D2D1_CAP_STYLE_ROUND,
    D2D1_CAP_STYLE_ROUND, D2D1_LINE_JOIN_ROUND);
  OleCheck(FFactory.CreateStrokeStyle(Properties, nil, 0, FRound));
end;

procedure TMeterCanvas.Arc(X, Y, Radius, Start, Stop, Width: Single; Color: Cardinal);
var
  Points: array[0..36] of TD2D1Point2F;
  I, Steps: Integer;
begin
  Steps := EnsureRange(Ceil(Abs(Stop - Start) * 10), 2, High(Points));
  for I := 0 to Steps do
    Points[I] := Polar(X, Y, Radius, Start + (Stop - Start) * I / Steps);
  StrokePath(Slice(Points, Steps + 1), Width, Color);
end;

procedure TMeterCanvas.PushClip(X, Y, W, H: Single);
begin
  FTarget.PushAxisAlignedClip(D2D1RectF(X, Y, X + W, Y + H), D2D1_ANTIALIAS_MODE_ALIASED);
end;

procedure TMeterCanvas.PopClip;
begin
  FTarget.PopAxisAlignedClip;
end;

procedure TMeterCanvas.SetColor(Color: Cardinal; Alpha: Single);
begin
  FBrush.SetColor(RGBA(Color, Alpha));
end;

procedure TMeterCanvas.Line(X1, Y1, X2, Y2, Stroke: Single; Color: Cardinal; Alpha: Single);
begin
  SetColor(Color, Alpha);
  FTarget.DrawLine(Pt(X1, Y1), Pt(X2, Y2), FBrush, Stroke, FRound);
end;

procedure TMeterCanvas.Oval(X, Y, RX, RY: Single; Color: Cardinal; Alpha: Single);
begin
  SetColor(Color, Alpha);
  FTarget.FillEllipse(D2D1Ellipse(Pt(X, Y), RX, RY), FBrush);
end;

procedure TMeterCanvas.Ring(X, Y, RX, RY, Stroke: Single; Color: Cardinal; Alpha: Single);
begin
  SetColor(Color, Alpha);
  FTarget.DrawEllipse(D2D1Ellipse(Pt(X, Y), RX, RY), FBrush, Stroke, nil);
end;

procedure TMeterCanvas.Box(X, Y, W, H, Radius: Single; Color: Cardinal; Alpha: Single);
begin
  SetColor(Color, Alpha);
  FTarget.FillRoundedRectangle(Rounded(X, Y, W, H, Radius), FBrush);
end;

procedure TMeterCanvas.BoxEdge(X, Y, W, H, Radius, Stroke: Single; Color: Cardinal; Alpha: Single);
begin
  SetColor(Color, Alpha);
  FTarget.DrawRoundedRectangle(Rounded(X, Y, W, H, Radius), FBrush, Stroke, nil);
end;

function TMeterCanvas.Gradient(X, Y, W, H: Single; Color1, Color2, Color3: Cardinal;
  Alpha1, Alpha2, Alpha3: Single): ID2D1LinearGradientBrush;
var
  Stops: array[0..2] of TD2D1GradientStop;
  Collection: ID2D1GradientStopCollection;
begin
  Stops[0] := D2D1GradientStop(0, RGBA(Color1, Alpha1));
  Stops[1] := D2D1GradientStop(0.45, RGBA(Color2, Alpha2));
  Stops[2] := D2D1GradientStop(1, RGBA(Color3, Alpha3));
  OleCheck(FTarget.CreateGradientStopCollection(@Stops[0], Length(Stops), D2D1_GAMMA_2_2,
    D2D1_EXTEND_MODE_CLAMP, Collection));
  OleCheck(FTarget.CreateLinearGradientBrush(D2D1LinearGradientBrushProperties(
    Pt(X, Y), Pt(X + W * 0.35, Y + H)), nil, Collection, Result));
end;

procedure TMeterCanvas.Panel(X, Y, W, H, Radius: Single; Color1, Color2, Color3: Cardinal);
begin
  FTarget.FillRoundedRectangle(Rounded(X, Y, W, H, Radius),
    Gradient(X, Y, W, H, Color1, Color2, Color3, 1, 1, 1));
end;

procedure TMeterCanvas.Disc(X, Y, RX, RY: Single; Color1, Color2, Color3: Cardinal);
begin
  FTarget.FillEllipse(D2D1Ellipse(Pt(X, Y), RX, RY),
    Gradient(X - RX, Y - RY, RX * 2, RY * 2, Color1, Color2, Color3, 1, 1, 1));
end;

function TMeterCanvas.Outline(const Points: array of TD2D1Point2F;
  Filled, Closed: Boolean): ID2D1PathGeometry;
var
  Sink: ID2D1GeometrySink;
  BeginMode: TD2D1FigureBegin;
  EndMode: D2D1_FIGURE_END;
begin
  OleCheck(FFactory.CreatePathGeometry(Result));
  OleCheck(Result.Open(Sink));
  BeginMode := D2D1_FIGURE_BEGIN_HOLLOW;
  if Filled then BeginMode := D2D1_FIGURE_BEGIN_FILLED;
  EndMode := D2D1_FIGURE_END_OPEN;
  if Closed then EndMode := D2D1_FIGURE_END_CLOSED;
  Sink.BeginFigure(Points[0], BeginMode);
  Sink.AddLines(@Points[1], High(Points));
  Sink.EndFigure(EndMode);
  OleCheck(Sink.Close);
end;

procedure TMeterCanvas.Polygon(const Points: array of TD2D1Point2F; Color: Cardinal; Alpha: Single);
begin
  if Length(Points) < 3 then Exit;
  SetColor(Color, Alpha);
  FTarget.FillGeometry(Outline(Points, True, True), FBrush, nil);
end;

procedure TMeterCanvas.StrokePath(const Points: array of TD2D1Point2F; Width: Single;
  Color: Cardinal; Alpha: Single; Closed: Boolean);
begin
  if Length(Points) < 2 then Exit;
  SetColor(Color, Alpha);
  FTarget.DrawGeometry(Outline(Points, False, Closed), FBrush, Width, FRound);
end;

end.

