unit Meter_Audio;

// Copyright (c) 2026 VRAMの魔術師
// SPDX-License-Identifier: GPL-3.0-only
// 絶対サンプル位置から合成した電子音を、ホストの音声チャンネルに渡す。

interface

uses AviUtl2FilterTypes, Meter_Settings;

// Scene のサンプルレートとオブジェクト先頭からのサンプル位置を使う。
// ホストが要求した区間を、電子音または無音の32-bit PCMで埋める。
function RenderMeterAudio(Audio: PFILTER_PROC_AUDIO; const S: TMeterSettings): Byte;

implementation

uses System.Math;

type
  TBeep = record
    Time, Frequency, Duration, Amplitude: Double;
  end;

function RenderMeterAudio(Audio: PFILTER_PROC_AUDIO; const S: TMeterSettings): Byte;
var
  Obj: POBJECT_INFO;
  Bounds: TMeterRange;
  Beeps: TBeepKinds;
  Events: array[0..3] of TBeep;
  Channel, Count, I, J, First, Last, Rate: Integer;
  Samples: TArray<Single>;
  Time, Gain, Attack, Release, Origin, EventStart: Double;

  procedure Schedule(When, Frequency, Duration, Amplitude: Double);
  begin
    Events[Count].Time := When;
    Events[Count].Frequency := Frequency;
    Events[Count].Duration := Duration;
    Events[Count].Amplitude := Amplitude;
    Inc(Count);
  end;

begin
  Result := 0;
  Obj := Audio^.Object_;
  if (Obj^.SampleNum <= 0) or (Obj^.SampleNum > 1000000) or
    (Obj^.ChannelNum <= 0) or (Obj^.ChannelNum > 32) then Exit;
  SetLength(Samples, Obj^.SampleNum);
  Beeps := METER_PRESETS[S.Kind].Beeps;
  if S.Sound and (Beeps <> []) and (Audio^.Scene <> nil) and (S.Values[mtVolume] > 0) then
  begin
    Rate := Audio^.Scene^.SampleRate;
    if Rate > 0 then
    begin
      Count := 0;
      if (bkStart in Beeps) and ((S.Values[mtDuration] > 0) or not (bkFinish in Beeps)) then
        Schedule(S.Values[mtDelay], 820, 0.085, 0.28);
      if bkFinish in Beeps then
        Schedule(S.Values[mtDelay] + S.Values[mtDuration], 1540, 0.16, 0.38);
      if bkWarning in Beeps then
      begin
        Bounds := MeterRange(S);
        for var Side in [rsLow, rsHigh] do
        begin
          EventStart := RangeEntryTime(S, Bounds, Side);
          if EventStart >= 0 then
            Schedule(EventStart, 520, 0.26, 0.48);
        end;
      end;
      // ブロックと重なる音だけを生成し、分割位置にかかわらず同じ位相にする。
      Origin := Obj^.SampleIndex;
      Gain := S.Values[mtVolume] * 0.006;
      for J := 0 to Count - 1 do
      begin
        EventStart := Events[J].Time * Rate - Origin;
        if (EventStart >= Length(Samples)) or (EventStart + Events[J].Duration * Rate < 0) then Continue;
        First := Max(0, Ceil(EventStart));
        Last := Min(High(Samples), Floor(EventStart + Events[J].Duration * Rate));
        for I := First to Last do
        begin
          Time := (I - EventStart) / Rate;
          Attack := Min(1.0, Time / 0.007);
          Release := Min(1.0, (Events[J].Duration - Time) / 0.035);
          Samples[I] := Samples[I] + Sin(2 * Pi * Min(Events[J].Frequency, Rate * 0.40) * Time) *
            Attack * Release * Events[J].Amplitude * Gain;
        end;
      end;
    end;
  end;
  // サンプルバッファはこのコールバックが所有し、ホストへチャンネルごとに渡す。
  for Channel := 0 to Obj^.ChannelNum - 1 do
    Audio^.SetSampleData(@Samples[0], Channel);
  Result := 1;
end;

end.
