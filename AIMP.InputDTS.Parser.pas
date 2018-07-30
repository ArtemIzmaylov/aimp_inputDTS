{******************************************************************}
{*                                                                *}
{*               DTS Decoder Plugin for AIMP 3.60                 *}
{*                  (Last Changes: 03.03.2016)                    *}
{*                                                                *}
{*                Artem Izmaylov (artem@aimp.ru)                  *}
{*                         www.aimp.ru                            *}
{*                                                                *}
{* Based on libdca, a free DTS Coherent Acoustics stream decoder. *}
{* See http://www.videolan.org/developers/libdca.html for more    *}
{* information and updates.                                       *}
{*                                                                *}
{* libdca is distributed in the hope that it will be useful, but  *}
{* WITHOUT ANY WARRANTY; without even the implied warranty of     *}
{* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the   *}
{* GNU General Public License for more details.                   *}
{*                                                                *}
{******************************************************************}

unit AIMP.InputDTS.Parser;

{$I AIMP.InputDTS.inc}

interface

uses
  Windows, apiObjects, AIMP.InputDTS.LibDCA;

type

  { TDCABuffer }

  TDCABuffer = class(TObject)
  strict private
    FData: PByte;
    FSize: Integer;
    FUsed: Integer;
  public
    constructor Create(ASize: Integer);
    destructor Destroy; override;
    procedure Remove(ACount: Cardinal);
    //
    property Data: PByte read FData;
    property Size: Integer read FSize;
    property Used: Integer read FUsed write FUsed;
  end;

  { TDCAParser }

  TDCAParser = class(TObject)
  strict private
    FBitrate: Integer;
    FBlockCount, FBlockIndex: Integer;
    FBuffer: TDCABuffer;
    FChannels: Integer;
    FChannelsFlags: Integer;
    FContentOffset: Int64;
    FDuration: Single;
    FHandle: TDCAState;
    FSampleRate: Integer;
    FSource: IAIMPStream;

    function GetPosition: Single;
    procedure PopuplateBuffer; inline;
    procedure SetPosition(AValue: Single);
  protected
    function InitializeChannelsConfiguration: Boolean;
    function IsValidFrameSize(AFrameSize: Integer): Boolean; inline;
    function ReadFrame(var AFlags, AFrameSize, BR, SR: Integer): Boolean;
  public
    constructor Create(ASource: IAIMPStream);
    destructor Destroy; override;
    function ExtractBlock: PSample32;
    function HasData: Boolean;
    function Initialize: Boolean;
    function PrepareNextFrame: Boolean;
    //
    property Bitrate: Integer read FBitrate;
    property BlockCount: Integer read FBlockCount;
    property BlockIndex: Integer read FBlockIndex;
    property Buffer: TDCABuffer read FBuffer;
    property Channels: Integer read FChannels;
    property ChannelsFlags: Integer read FChannelsFlags;
    property ContentOffset: Int64 read FContentOffset;
    property Duration: Single read FDuration;
    property Handle: TDCAState read FHandle;
    property Position: Single read GetPosition write SetPosition;
    property SampleRate: Integer read FSampleRate;
    property Source: IAIMPStream read FSource;
  end;

  { TDCADecoder }

  TDCADecoder = class(TObject)
  strict private
    FBuffer: TDCABuffer;
    FBytesPerSecond: Integer;
    FParser: TDCAParser;
    FReorderMap: array[0..5] of Integer;

    procedure InitializeReoderMap;
    procedure PopulateBuffer(ASource: PSample32);
    //
    function GetBitrate: Integer;
    function GetChannels: Integer;
    function GetDuration: Single;
    function GetRawPosition: Int64;
    function GetRawSize: Int64;
    function GetSampleRate: Integer;
    function GetStreamSize: Int64;
    procedure SetRawPosition(const Value: Int64);
  protected
    property Buffer: TDCABuffer read FBuffer;
    property Parser: TDCAParser read FParser;
  public
    constructor Create(AParser: TDCAParser); virtual;
    destructor Destroy; override;
    function Read(ABuffer: PByte; ABufferSize: Integer): Integer;
    //
    property Bitrate: Integer read GetBitrate;
    property Channels: Integer read GetChannels;
    property Duration: Single read GetDuration;
    property SampleRate: Integer read GetSampleRate;
    property StreamSize: Int64 read GetStreamSize;
    //
    property RawPosition: Int64 read GetRawPosition write SetRawPosition;
    property RawSize: Int64 read GetRawSize;
  end;

function CreateDCADecoder(Stream: IAIMPStream; out Decoder: TDCADecoder): Boolean;
implementation

uses
  Math, SysUtils;

function CreateDCADecoder(Stream: IAIMPStream; out Decoder: TDCADecoder): Boolean;
var
  AParser: TDCAParser;
begin
  Result := False;
  AParser := TDCAParser.Create(Stream);
  try
    Result := AParser.Initialize;
    if Result then
      Decoder := TDCADecoder.Create(AParser)
    else
      AParser.Free;
  except
    AParser.Free;
  end;
end;

{ TDCABuffer }

constructor TDCABuffer.Create(ASize: Integer);
begin
  inherited Create;
  FSize := ASize;
  FData := AllocMem(ASize);
end;

destructor TDCABuffer.Destroy;
begin
  FreeMem(Data, Size);
  inherited Destroy;
end;

procedure TDCABuffer.Remove(ACount: Cardinal);
begin
  ACount := Min(ACount, Used);
  Dec(FUsed, ACount);
  if Used > 0 then
    Move(PByte(NativeUInt(Data) + ACount)^, Data^, Used);
end;

{ TDCAParser }

constructor TDCAParser.Create(ASource: IAIMPStream);
begin
  inherited Create;
  FSource := ASource;
  FHandle := dca_init(MM_ACCEL_DEFAULT);
  FBuffer := TDCABuffer.Create(DCA_MAX_SEEKING_FRAME);
end;

destructor TDCAParser.Destroy;
begin
  dca_free(FHandle);
  FreeAndNil(FBuffer);
  inherited Destroy;
end;

function TDCAParser.ExtractBlock: PSample32;
begin
  dca_block(Handle);
  Result := dca_samples(Handle);
  Inc(FBlockIndex);
end;

function TDCAParser.HasData: Boolean;
begin
  Result := BlockIndex < BlockCount;
end;

function TDCAParser.Initialize: Boolean;
var
  AFrameSize: Integer;
begin
  Result := False;
  if ReadFrame(FChannelsFlags, AFrameSize, FBitrate, FSampleRate) then
  begin
    if IsValidFrameSize(AFrameSize) and InitializeChannelsConfiguration then
    begin
      if Bitrate <= 3 then //todo: variable bitrate
        FBitrate := 1411200; // std;
      FContentOffset := Source.GetPosition;
      FDuration := (Source.GetSize - ContentOffset) / (Bitrate / 8);
      Result := PrepareNextFrame;
    end;
  end;
end;

function TDCAParser.PrepareNextFrame: Boolean;
var
  AFlags, B: Integer;
  AFrameSize: Integer;
  ALevel, ABias: Single;
begin
  Result := ReadFrame(AFlags, AFrameSize, B, FSampleRate);
  if Result then
  begin
    ABias := 0;
    ALevel := 1;
    AFlags := ChannelsFlags or DCA_ADJUST_LEVEL;
    if dca_frame(Handle, Buffer.Data, AFlags, ALevel, ABias) = 0 then
    begin
      FBlockCount := dca_blocks_num(Handle);
      FBlockIndex := 0;
    end;
    Source.Seek(AFrameSize, AIMP_STREAM_SEEKMODE_FROM_CURRENT);
  end;
  Result := Result and HasData;
end;

function TDCAParser.InitializeChannelsConfiguration: Boolean;
begin
  case FChannelsFlags and DCA_CHANNEL_MASK of
    DCA_MONO:
      begin
        FChannelsFlags := DCA_MONO;
        FChannels := 1;
      end;

    DCA_3F2R, DCA_4F2R:
      begin
        FChannelsFlags := DCA_3F2R or DCA_LFE;
        FChannels := 6;
      end;

    else
      begin
        FChannelsFlags := DCA_STEREO;
        FChannels := 2;
      end;
  end;
  Result := True;
end;

function TDCAParser.IsValidFrameSize(AFrameSize: Integer): Boolean;
begin
  Result := (AFrameSize > 0) and (AFrameSize <= DCA_MAX_FRAME);
end;

function TDCAParser.ReadFrame(var AFlags, AFrameSize, BR, SR: Integer): Boolean;
var
  AFrameLength: Integer;
  AFramePos: Int64;
  AScan: PByte;
  ABytesLeft: Integer;
  I: Integer;
begin
  AFrameSize := 0;
  for I := 0 to DCA_MAX_SEEKING - 1 do
  begin
    AFramePos := Source.GetPosition;
    PopuplateBuffer;
    if Buffer.Used = 0 then //EOF
      Break;

    AScan := Buffer.Data;
    ABytesLeft := Buffer.Used;
    while ABytesLeft > 0 do
    begin
      AFrameSize := dca_syncinfo(Handle, AScan, AFlags, SR, BR, AFrameLength);
      if IsValidFrameSize(AFrameSize) then
        Break;
      Dec(ABytesLeft);
      Inc(AFramePos);
      Inc(AScan);
    end;
    Buffer.Remove(Buffer.Used - ABytesLeft);

    if AFrameSize > 0 then
    begin
      if Buffer.Used < AFrameSize then
      begin
        Source.Seek(AFramePos, AIMP_STREAM_SEEKMODE_FROM_BEGINNING);
        PopuplateBuffer;
      end;
      Source.Seek(AFramePos, AIMP_STREAM_SEEKMODE_FROM_BEGINNING);
      Break;
    end;
    // For fast scan data in Disk Images
    Source.Seek(MaxWord, AIMP_STREAM_SEEKMODE_FROM_CURRENT);
  end;
  Result := AFrameSize > 0;
end;

procedure TDCAParser.PopuplateBuffer;
begin
  Buffer.Used := Source.Read(Buffer.Data, Buffer.Size);
end;

function TDCAParser.GetPosition: Single;
begin
  Result := Max(0, Source.GetPosition - ContentOffset) / (Bitrate / 8);
end;

procedure TDCAParser.SetPosition(AValue: Single);
begin
  Source.Seek(ContentOffset + Trunc((Bitrate / 8) * AValue), AIMP_STREAM_SEEKMODE_FROM_BEGINNING);
end;

{ TDCADecoder }

constructor TDCADecoder.Create(AParser: TDCAParser);
var
  ABytesPerBlock: Integer;
begin
  inherited Create;
  FParser := AParser;
  ABytesPerBlock := Parser.Channels * SizeOf(TSample32);
  FBytesPerSecond := Parser.SampleRate * ABytesPerBlock;
  FBuffer := TDCABuffer.Create(DCA_MAX_SAMPLES_PER_BLOCK * ABytesPerBlock);
  InitializeReoderMap;
end;

destructor TDCADecoder.Destroy;
begin
  FreeAndNil(FParser);
  FreeAndNil(FBuffer);
  inherited Destroy;
end;

function TDCADecoder.Read(ABuffer: PByte; ABufferSize: Integer): Integer;
var
  ABytes: Integer;
begin
  Result := 0;
  while ABufferSize > 0 do
  begin
    if Buffer.Used > 0 then
    begin
      ABytes := Min(Buffer.Used, ABufferSize);
      Move(Buffer.Data^, ABuffer^, ABytes);
      Buffer.Remove(ABytes);
      Dec(ABufferSize, ABytes);
      Inc(ABuffer, ABytes);
      Inc(Result, ABytes);
    end
    else
      if Parser.HasData or Parser.PrepareNextFrame then
        PopulateBuffer(Parser.ExtractBlock)
      else
        Break;
  end;
end;

procedure TDCADecoder.InitializeReoderMap;
var
  I: Integer;
begin
  if Parser.Channels = 6 {5.1} then
  begin
    // DTS: C, L, R, LS, RS, SW
    // 5.1: L, R, C, SW, LS, RS
    FReorderMap[0] := 2;
    FReorderMap[1] := 0;
    FReorderMap[2] := 1;
    FReorderMap[3] := 4;
    FReorderMap[4] := 5;
    FReorderMap[5] := 3;
  end
  else
    for I := 0 to Parser.Channels - 1 do
      FReorderMap[I] := I;
end;

procedure TDCADecoder.PopulateBuffer(ASource: PSample32);
var
  ABuffer: PSample32;
  AChannelIndex: Integer;
  ASampleIndex: Integer;
begin
  Buffer.Used := Buffer.Size;
  for AChannelIndex := 0 to Parser.Channels - 1 do
  begin
    ABuffer := PSample32(Buffer.Data);
    Inc(ABuffer, FReorderMap[AChannelIndex]);
    for ASampleIndex := 0 to DCA_MAX_SAMPLES_PER_BLOCK - 1 do
    begin
      ABuffer^ := ASource^;
      Inc(ABuffer, Parser.Channels);
      Inc(ASource);
    end;
  end;
end;

function TDCADecoder.GetBitrate: Integer;
begin
  Result := Parser.Bitrate div 1000;
end;

function TDCADecoder.GetChannels: Integer;
begin
  Result := Parser.Channels;
end;

function TDCADecoder.GetDuration: Single;
begin
  Result := Parser.Duration;
end;

function TDCADecoder.GetRawPosition: Int64;
begin
  Result := Trunc(Parser.Position * FBytesPerSecond);
end;

function TDCADecoder.GetRawSize: Int64;
begin
  Result := Trunc(Parser.Duration * FBytesPerSecond);
end;

function TDCADecoder.GetSampleRate: Integer;
begin
  Result := Parser.SampleRate;
end;

function TDCADecoder.GetStreamSize: Int64;
begin
  Result := Parser.Source.GetSize;
end;

procedure TDCADecoder.SetRawPosition(const Value: Int64);
begin
  Parser.Position := Value / FBytesPerSecond;
end;

end.
