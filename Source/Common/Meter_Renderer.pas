unit Meter_Renderer;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 透過 Direct2D サーフェスを保持し、静的レイヤーと同一フレームを再利用する。

interface

uses Winapi.D2D1, Winapi.Wincodec, AviUtl2FilterTypes, Meter_Canvas, Meter_Settings;

type
  // エフェクトごとにサーフェス・ブラシ・RGBAバッファを所有する。
  TMeterRenderer = class
  private
    FFactory: ID2D1Factory;
    FWic: IWICImagingFactory;
    FBitmap: IWICBitmap;
    FTarget: ID2D1RenderTarget;
    FBackground: ID2D1Bitmap;
    FCanvas: TMeterCanvas;
    FComCookie: Pointer;
    FWidth, FHeight: Integer;
    // ケース、目盛り、単位、配色に関わる設定を比較して背景の更新を判断する。
    FBaseSettings: TMeterSettings;
    FReading: TMeterReading;
    FDecimals: Integer;
    FFrameReady: Boolean;
    FPixels: TArray<TPIXEL_RGBA>;
    procedure ResetTarget;
    procedure EnsureTarget(Width, Height: Integer);
    procedure EnsureBackground(const S: TMeterSettings);
    procedure CopyRGBA;
  public
    destructor Destroy; override;
    // 呼出側で直列化する。RGBA を生成し、ホストへコールバック中に転送する。
    procedure Render(const S: TMeterSettings; const Reading: TMeterReading;
      SetImage: TFILTER_SET_IMAGE_DATA);
  end;

implementation

uses System.SysUtils, System.Math, System.Win.ComObj, Winapi.Windows,
  Winapi.ActiveX, Winapi.DxgiFormat, Meter_Analog, Meter_Digital, Meter_Levels;

function CoIncrementMTAUsage(out Cookie: Pointer): HRESULT; stdcall;
  external 'ole32.dll' name 'CoIncrementMTAUsage';
function CoDecrementMTAUsage(Cookie: Pointer): HRESULT; stdcall;
  external 'ole32.dll' name 'CoDecrementMTAUsage';

destructor TMeterRenderer.Destroy;
begin
  ResetTarget;
  FFactory := nil;
  FWic := nil;
  if FComCookie <> nil then CoDecrementMTAUsage(FComCookie);
  inherited;
end;

procedure TMeterRenderer.ResetTarget;
begin
  FFrameReady := False;
  FreeAndNil(FCanvas);
  FBackground := nil;
  FTarget := nil;
  FBitmap := nil;
  FWidth := 0;
  FHeight := 0;
end;

procedure TMeterRenderer.EnsureTarget(Width, Height: Integer);
var
  Properties: TD2D1RenderTargetProperties;
begin
  if (FWidth = Width) and (FHeight = Height) then Exit;
  ResetTarget;
  if FComCookie = nil then OleCheck(CoIncrementMTAUsage(FComCookie));
  if FFactory = nil then
    OleCheck(D2D1CreateFactory(D2D1_FACTORY_TYPE_MULTI_THREADED, ID2D1Factory, nil, FFactory));
  if FWic = nil then
    OleCheck(CoCreateInstance(CLSID_WICImagingFactory, nil, CLSCTX_INPROC_SERVER,
      IID_IWICImagingFactory, FWic));

  OleCheck(FWic.CreateBitmap(Width, Height, @GUID_WICPixelFormat32bppPBGRA,
    WICBitmapCacheOnLoad, FBitmap));
  Properties := D2D1RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_SOFTWARE,
    D2D1PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_PREMULTIPLIED), 96, 96);
  OleCheck(FFactory.CreateWicBitmapRenderTarget(FBitmap, Properties, FTarget));
  FCanvas := TMeterCanvas.Create(FFactory, FTarget);
  SetLength(FPixels, Width * Height);
  FWidth := Width;
  FHeight := Height;
end;

procedure TMeterRenderer.EnsureBackground(const S: TMeterSettings);
var
  Layer: ID2D1BitmapRenderTarget;
  Base: TMeterCanvas;
  Size: TD2D1SizeF;
begin
  if (FBackground <> nil) and (FBaseSettings.Kind = S.Kind) and
    (FBaseSettings.UnitText = S.UnitText) and
    (FBaseSettings.Values[mtMinimum] = S.Values[mtMinimum]) and
    (FBaseSettings.Values[mtMaximum] = S.Values[mtMaximum]) and
    CompareMem(@FBaseSettings.Colors, @S.Colors, SizeOf(TMeterColors)) then Exit;
  FFrameReady := False;
  FBackground := nil;
  Size := D2D1SizeF(FWidth, FHeight);
  OleCheck(FTarget.CreateCompatibleRenderTarget(@Size, nil, nil,
    D2D1_COMPATIBLE_RENDER_TARGET_OPTIONS_NONE, Layer));
  Base := TMeterCanvas.Create(FFactory, Layer);
  try
    Layer.BeginDraw;
    try
      Layer.Clear(D2D1ColorF(0, 0, 0, 0));
      case METER_PRESETS[S.Kind].Method of
        mmColumn, mmBar: DrawLevelBase(Base, S);
        mmDial, mmFan: DrawAnalogBase(Base, S);
        mmDigital: DrawDigitalBase(Base, S);
      end;
    finally
      OleCheck(Layer.EndDraw);
    end;
    OleCheck(Layer.GetBitmap(FBackground));
    FBaseSettings := S;
  finally
    Base.Free;
  end;
end;

// Direct2D の乗算済み BGRA を、ホストへ渡すストレートアルファの RGBA に戻す。
procedure TMeterRenderer.CopyRGBA;
var
  I, Alpha: Integer;
  Raw: TPIXEL_RGBA;

  function Straight(Value: Byte): Byte;
  begin
    Result := Min(255, (Integer(Value) * 255 + Alpha div 2) div Alpha);
  end;

begin
  OleCheck(FBitmap.CopyPixels(nil, FWidth * 4, Length(FPixels) * 4, @FPixels[0]));
  for I := 0 to High(FPixels) do
  begin
    Raw := FPixels[I];
    Alpha := Raw.A;
    if Alpha = 0 then FPixels[I] := Default(TPIXEL_RGBA)
    else if Alpha = 255 then
    begin
      FPixels[I].R := Raw.B;
      FPixels[I].B := Raw.R;
    end
    else
    begin
      FPixels[I].R := Straight(Raw.B);
      FPixels[I].G := Straight(Raw.G);
      FPixels[I].B := Straight(Raw.R);
    end;
  end;
end;

procedure TMeterRenderer.Render(const S: TMeterSettings; const Reading: TMeterReading;
  SetImage: TFILTER_SET_IMAGE_DATA);
var
  P: TMeterPreset;
  Area: TD2D1RectF;
  Status: HRESULT;
begin
  P := METER_PRESETS[S.Kind];
  EnsureTarget(P.Width, P.Height);
  EnsureBackground(S);
  if not FFrameReady or (FReading.Fraction <> Reading.Fraction) or
    (FReading.Display <> Reading.Display) or (FReading.MessageText <> Reading.MessageText) or
    (FReading.BreakAge <> Reading.BreakAge) or (FDecimals <> DisplayDecimals(S)) then
  begin
    FFrameReady := False;
    Area := D2D1RectF(0, 0, FWidth, FHeight);
    FTarget.BeginDraw;
    try
      FTarget.Clear(D2D1ColorF(0, 0, 0, 0));
      FTarget.DrawBitmap(FBackground, @Area);
      case P.Method of
        mmColumn, mmBar: DrawLevelReading(FCanvas, S, Reading);
        mmDial, mmFan: DrawAnalogReading(FCanvas, S, Reading);
        mmDigital: DrawDigitalReading(FCanvas, S, Reading);
      end;
    finally
      Status := FTarget.EndDraw;
      if Failed(Status) then ResetTarget;
      OleCheck(Status);
    end;
    CopyRGBA;
    FReading := Reading;
    FDecimals := DisplayDecimals(S);
    FFrameReady := True;
  end;
  // ポインターの借用は SetImage 呼び出し中だけ。バッファは次の描画で再利用する。
  SetImage(@FPixels[0], FWidth, FHeight);
end;

end.
