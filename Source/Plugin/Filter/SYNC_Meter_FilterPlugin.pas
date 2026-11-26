unit SYNC_Meter_FilterPlugin;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// メディアオブジェクトを登録し、オブジェクトごとに映像処理を直列化する。

interface

uses AviUtl2FilterTypes;

const
  METER_REQUIRED_VERSION = 2011600;

// DLL が所有する、登録済みのテーブルを返す。
function GetMeterFilterTable: PFILTER_PLUGIN_TABLE;

implementation

uses System.SysUtils, System.SyncObjs, Winapi.Windows, PluginFilterTable,
  Meter_Settings, Meter_Renderer, Meter_Parameters, Meter_Audio;

type
  TMeterSession = class
    Renderer: TMeterRenderer;
    Lock: TCriticalSection;
    constructor Create;
    destructor Destroy; override;
  end;

var
  TableInitialized: Boolean;

constructor TMeterSession.Create;
begin
  inherited;
  Lock := TCriticalSection.Create;
  Renderer := TMeterRenderer.Create;
end;

destructor TMeterSession.Destroy;
begin
  Renderer.Free;
  Lock.Free;
  inherited;
end;

function CreateMeter(EffectID: Int64): Pointer; cdecl;
begin
  Result := nil;
  try
    Result := TMeterSession.Create;
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Meter create: ' + E.Message));
  end;
end;

procedure DestroyMeter(EffectID: Int64; UserData: Pointer); cdecl;
begin
  try
    TMeterSession(UserData).Free;
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Meter destroy: ' + E.Message));
  end;
end;

function MeterVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  Session: TMeterSession;
  S: TMeterSettings;
  Reading: TMeterReading;
begin
  Result := 0;
  if (Video = nil) or (Video^.Object_ = nil) or (Video^.UserData = nil) or
    not Assigned(Video^.SetImageData) then Exit;
  try
    S := ReadMeterSettings;
    Reading := EvaluateMeter(S, Video^.Object_^.Time);
    Session := TMeterSession(Video^.UserData);
    Session.Lock.Acquire;
    try
      Session.Renderer.Render(S, Reading, Video^.SetImageData);
      Result := 1;
    finally
      Session.Lock.Release;
    end;
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Meter video: ' + E.Message));
  end;
end;

function MeterAudio(Audio: PFILTER_PROC_AUDIO): Byte; cdecl;
begin
  Result := 0;
  if (Audio = nil) or (Audio^.Object_ = nil) or not Assigned(Audio^.SetSampleData) then Exit;
  try
    Result := RenderMeterAudio(Audio, ReadMeterSettings);
  except
    on E: Exception do OutputDebugString(PWideChar('SYNC_Meter audio: ' + E.Message));
  end;
end;

function GetMeterFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if not TableInitialized then
  begin
    SetupPluginTable(FILTER_FLAG_VIDEO or FILTER_FLAG_AUDIO or FILTER_FLAG_INPUT or
      FILTER_FLAG_USERDATA, 'メーター演出', 'SYNC', 'メーター演出 / SYNC_Meter v1.0.0',
      MeterVideo, MeterAudio);
    RegisterMeterParameters;
    GetPluginTable^.Func_Create := CreateMeter;
    GetPluginTable^.Func_Destroy := DestroyMeter;
    TableInitialized := True;
  end;
  Result := GetPluginTable;
end;

end.
