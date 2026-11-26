unit Meter_Glyphs;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 時計演出の数字を流用し、計測表示の英字と単位記号を追加する。

interface

uses Meter_Canvas;

type
  TMeterDisplay = (mdVector, mdSegment);

// 字形の左上とサイズをピクセルで受け取り、対象キャンバスへ描く。
procedure Glyph(Canvas: TMeterCanvas; Ch: Char; X, Y, W, H: Single;
  Color: Cardinal; Display: TMeterDisplay; Unlit: Boolean = False);
// 内蔵字形を指定幅に収める。座標はテキストの中心。
procedure MeterText(Canvas: TMeterCanvas; const Text: string; CenterX, CenterY,
  Height, MaxWidth: Single; Color: Cardinal; Display: TMeterDisplay = mdVector);

implementation

uses System.Math, System.SysUtils, Winapi.D2D1;

const
  // 各座標は 0～9 の格子上の XY。/ はペンを離す位置。
  DIGITS: array['0'..'9'] of string = (
    '30608193968869391806031130',
    '225059/2989',
    '0211306081938465370999',
    '013060819284644464859697793908',
    '79700696',
    '90100443749688693908',
    '8050210406183969889684633305',
    '009039',
    '44231221406081928364351607297998966444',
    '9466361503113060819396784919');
  MASKS: array['0'..'9'] of Byte = ($3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$6F);
function StrokeData(Ch: Char): string;
begin
  if (Ch >= '0') and (Ch <= '9') then Exit(DIGITS[Ch]);
  case Ch of
    'A': Result := '095099/2565';
    'B': Result := '09006081736404748687689909';
    'C': Result := '902001062898';
    'D': Result := '090050829386589909';
    'E': Result := '90000999/0474';
    'F': Result := '090090/0474';
    'G': Result := '9020010829999565';
    'H': Result := '0009/9099/0494';
    'I': Result := '1090/5059/1999';
    'J': Result := '0090/8087290717';
    'K': Result := '0009/900499';
    'L': Result := '000999';
    'M': Result := '0900559099';
    'N': Result := '09009990';
    'O': Result := DIGITS['0'];
    'P': Result := '09006081836404';
    'Q': Result := DIGITS['0'] + '/5599';
    'R': Result := '09006081836404/5499';
    'S': Result := '9020010323739698791908';
    'T': Result := '0090/5059';
    'U': Result := '000729798790';
    'V': Result := '005990';
    'W': Result := '0029557990';
    'X': Result := '0099/9009';
    'Y': Result := '005490/5459';
    'Z': Result := '00900999';
    'a': Result := '1343839599/955506084999';
    'b': Result := '000934739498693909';
    'c': Result := '932303082999';
    'd': Result := '909944231408397999';
    'e': Result := '069683632313082999';
    'f': Result := '39517090/1383';
    'g': Result := '936323040627679693/9698792918';
    'h': Result := '000934739499';
    'i': Result := '5051/5359';
    'j': Result := '7071/73782918';
    'k': Result := '1019/931699';
    'l': Result := '40483959';
    'm': Result := '030934445559/5474849599';
    'n': Result := '030934739499';
    'o': Result := '23237394987929080423';
    'p': Result := '090333739497674307';
    'q': Result := '999373230407276797';
    'r': Result := '0309245384';
    's': Result := '932304156697783909';
    't': Result := '41482969/1373';
    'u': Result := '030829799993';
    'v': Result := '035993';
    'w': Result := '0329567993';
    'x': Result := '0399/9309';
    'y': Result := '034793/4719';
    'z': Result := '03930999';
    '-', '−': Result := '1474';
    '+': Result := '1484/4247';
    '/': Result := '0990';
    '%': Result := '0990/1012222010/7797997977';
    'μ', 'µ': Result := '1319/1637779693/9699';
    'Ω': Result := '092904126282947999';
    ' ': Result := '';
    else Result := '00909909/0990';
  end;
end;

procedure VectorGlyph(Canvas: TMeterCanvas; Ch: Char; X, Y, W, H: Single; Color: Cardinal);
var
  Data: string;
  P: array[0..23] of TD2D1Point2F;
  Index, Count: Integer;
  Stroke: Single;
begin
  Stroke := W * 0.14;
  if Ch = '°' then
  begin
    Canvas.Ring(X + W * 0.50, Y + H * 0.25, W * 0.24, W * 0.24, Stroke, Color);
    Exit;
  end;
  if Ch = ':' then
  begin
    Canvas.Oval(X + W * 0.5, Y + H * 0.32, Stroke, Stroke, Color);
    Canvas.Oval(X + W * 0.5, Y + H * 0.72, Stroke, Stroke, Color);
    Exit;
  end;
  if Ch = '・' then
  begin
    Canvas.Oval(X + W * 0.5, Y + H * 0.50, Stroke, Stroke, Color);
    Exit;
  end;
  if Ch = '.' then
  begin
    Canvas.Oval(X + W * 0.5, Y + H * 0.92, Stroke, Stroke, Color);
    Exit;
  end;
  Data := StrokeData(Ch);
  Count := 0;
  Index := 1;
  while Index < Length(Data) do
  begin
    if Data[Index] = '/' then
    begin
      Canvas.StrokePath(Slice(P, Count), Stroke, Color);
      Count := 0;
      Inc(Index);
      Continue;
    end;
    P[Count] := Pt(X + W * (0.1 + 0.8 * (Ord(Data[Index]) - Ord('0')) / 9),
      Y + H * (0.07 + 0.86 * (Ord(Data[Index + 1]) - Ord('0')) / 9));
    Inc(Count);
    Inc(Index, 2);
  end;
  Canvas.StrokePath(Slice(P, Count), Stroke, Color);
end;

procedure SegmentedGlyph(Canvas: TMeterCanvas; Ch: Char; X, Y, W, H: Single;
  Color: Cardinal; Unlit: Boolean);
var
  Mask: Byte;
  T, Mid: Single;
  procedure Segment(Index: Integer; X1, Y1, X2, Y2: Single);
  var
    Alpha: Single;
  begin
    Alpha := 1;
    if Mask and (1 shl Index) = 0 then
    begin
      if not Unlit then Exit;
      Alpha := 0.14;
    end;
    if X1 = X2 then
      Canvas.Polygon([Pt(X1, Y1), Pt(X1 + T, Y1 + T), Pt(X2 + T, Y2 - T), Pt(X2, Y2),
        Pt(X2 - T, Y2 - T), Pt(X1 - T, Y1 + T)], Color, Alpha)
    else
      Canvas.Polygon([Pt(X1, Y1), Pt(X1 + T, Y1 + T), Pt(X2 - T, Y2 + T), Pt(X2, Y2),
        Pt(X2 - T, Y2 - T), Pt(X1 + T, Y1 - T)], Color, Alpha);
  end;
begin
  case Ch of
    '0'..'9': Mask := MASKS[Ch];
    'E': Mask := $79;
    'H': Mask := $76;
    'L': Mask := $38;
    'O': Mask := $3F;
    'o': Mask := $5C;
    'r': Mask := $50;
    '-', '−': Mask := $40;
    else
    begin
      VectorGlyph(Canvas, Ch, X, Y, W, H, Color);
      Exit;
    end;
  end;
  T := Min(W * 0.092, H * 0.085);
  Mid := Y + H / 2;
  Segment(0, X + T * 2, Y + T, X + W - T * 2, Y + T);
  Segment(1, X + W - T, Y + T * 2, X + W - T, Mid - T);
  Segment(2, X + W - T, Mid + T, X + W - T, Y + H - T * 2);
  Segment(3, X + T * 2, Y + H - T, X + W - T * 2, Y + H - T);
  Segment(4, X + T, Mid + T, X + T, Y + H - T * 2);
  Segment(5, X + T, Y + T * 2, X + T, Mid - T);
  Segment(6, X + T * 2, Mid, X + W - T * 2, Mid);
end;

procedure Glyph(Canvas: TMeterCanvas; Ch: Char; X, Y, W, H: Single;
  Color: Cardinal; Display: TMeterDisplay; Unlit: Boolean);
begin
  case Display of
    mdVector: VectorGlyph(Canvas, Ch, X, Y, W, H, Color);
    mdSegment: SegmentedGlyph(Canvas, Ch, X, Y, W, H, Color, Unlit);
  end;
end;

function WidthFactor(Ch: Char): Single;
begin
  case Ch of
    '.', '°', '・', ' ': Result := 0.44;
    else Result := 1;
  end;
end;

procedure MeterText(Canvas: TMeterCanvas; const Text: string; CenterX, CenterY,
  Height, MaxWidth: Single; Color: Cardinal; Display: TMeterDisplay);
var
  Ch: Char;
  Expanded: string;
  Total, ShapeWidth, Advance, X: Single;
begin
  if Text = '' then Exit;
  // 合字を度記号と英字に分け、単位も数字と同じ内蔵字形で描く。
  Expanded := StringReplace(Text, '℃', '°C', [rfReplaceAll]);
  Expanded := StringReplace(Expanded, '℉', '°F', [rfReplaceAll]);
  Total := 0;
  for Ch in Expanded do Total := Total + WidthFactor(Ch);
  ShapeWidth := Height * 0.57;
  if Display = mdSegment then ShapeWidth := Height * 0.59;
  ShapeWidth := Min(ShapeWidth, MaxWidth / (Total * 1.18));
  Height := Min(Height, ShapeWidth / 0.48);
  X := CenterX - Total * ShapeWidth * 1.18 * 0.5;
  for Ch in Expanded do
  begin
    Advance := ShapeWidth * WidthFactor(Ch);
    Glyph(Canvas, Ch, X + Advance * 0.09, CenterY - Height * 0.5, Advance,
      Height, Color, Display);
    X := X + Advance * 1.18;
  end;
end;
end.
