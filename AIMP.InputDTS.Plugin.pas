{******************************************************************}
{*                                                                *}
{*               DTS Decoder Plugin for AIMP 3.60                 *}
{*                  (Last Changes: 24.03.2014)                    *}
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

unit AIMP.InputDTS.Plugin;

{$I AIMP.InputDTS.inc}

interface

uses
  Windows, apiObjects, apiPlugin, apiCore, apiFileManager, apiDecoders, AIMPCustomPlugin, AIMP.InputDTS.Parser;

type
  TAIMPDCAPlugin = class;

  { TAIMPDCADecoder }

  TAIMPDCADecoder = class(TInterfacedObject, IAIMPAudioDecoder)
  strict private
    FDecoder: TDCADecoder;
  public
    constructor Create(ADecoder: TDCADecoder);
    destructor Destroy; override;

    // IAIMPAudioDecoder
    function GetFileInfo(FileInfo: IAIMPFileInfo): LongBool; stdcall;
    function GetStreamInfo(out SampleRate, Channels, SampleFormat: Integer): LongBool; stdcall;

    function IsSeekable: LongBool; stdcall;
    function IsRealTimeStream: LongBool; stdcall;

    function GetAvailableData: Int64; stdcall;
    function GetSize: Int64; stdcall;
    function GetPosition: Int64; stdcall;
    function SetPosition(const Value: Int64): LongBool; stdcall;

    function Read(Buffer: PByte; Count: Integer): Integer; stdcall;
  end;

  { TAIMPDCADecoderExtension }

  TAIMPDCADecoderExtension = class(TInterfacedObject, IAIMPExtensionAudioDecoder)
  strict private
    FOwner: TAIMPDCAPlugin;
  public
    constructor Create(AOwner: TAIMPDCAPlugin);
    // IAIMPExtensionAudioDecoder
    function CreateDecoder(Stream: IAIMPStream; Flags: DWORD;
      ErrorInfo: IAIMPErrorInfo; out Decoder: IAIMPAudioDecoder): HRESULT; stdcall;
  end;

  { TAIMPDCAFileFormat }

  TAIMPDCAFileFormat = class(TInterfacedObject, IAIMPExtensionFileFormat)
  strict private
    FOwner: TAIMPDCAPlugin;
  public
    constructor Create(AOwner: TAIMPDCAPlugin);
    // IAIMPExtensionFileFormat
    function GetDescription(out S: IAIMPString): HRESULT; stdcall;
    function GetExtList(out S: IAIMPString): HRESULT; stdcall;
    function GetFlags(out Flags: Cardinal): HRESULT; stdcall;
  end;

  { TAIMPDCAPlugin }

  TAIMPDCAPlugin = class(TAIMPCustomPlugin)
  protected
    function InfoGet(Index: Integer): PWideChar; override; stdcall;
    function InfoGetCategories: Cardinal; override; stdcall;
    function Initialize(Core: IAIMPCore): HRESULT; override; stdcall;
  end;

implementation

uses
  apiWrappers, SysUtils;

{ TAIMPDCADecoder }

constructor TAIMPDCADecoder.Create(ADecoder: TDCADecoder);
begin
  inherited Create;
  FDecoder := ADecoder;
end;

destructor TAIMPDCADecoder.Destroy;
begin
  FreeAndNil(FDecoder);
  inherited Destroy;
end;

function TAIMPDCADecoder.GetFileInfo(FileInfo: IAIMPFileInfo): LongBool;
begin
  if FileInfo <> nil then
  begin
    FileInfo.SetValueAsFloat(AIMP_FILEINFO_PROPID_DURATION, FDecoder.Duration);
    FileInfo.SetValueAsInt32(AIMP_FILEINFO_PROPID_BITRATE, FDecoder.Bitrate);
    FileInfo.SetValueAsInt32(AIMP_FILEINFO_PROPID_CHANNELS, FDecoder.Channels);
    FileInfo.SetValueAsInt32(AIMP_FILEINFO_PROPID_SAMPLERATE, FDecoder.SampleRate);
    FileInfo.SetValueAsInt64(AIMP_FILEINFO_PROPID_FILESIZE, FDecoder.StreamSize);
  end;
  Result := True;
end;

function TAIMPDCADecoder.GetStreamInfo(out SampleRate, Channels, SampleFormat: Integer): LongBool;
begin
  Channels := FDecoder.Channels;
  SampleRate := FDecoder.SampleRate;
  SampleFormat := AIMP_DECODER_SAMPLEFORMAT_32BITFLOAT;
  Result := True;
end;

function TAIMPDCADecoder.IsRealTimeStream: LongBool;
begin
  Result := False;
end;

function TAIMPDCADecoder.IsSeekable: LongBool;
begin
  Result := True;
end;

function TAIMPDCADecoder.GetAvailableData: Int64;
begin
  Result := GetSize - GetPosition;
end;

function TAIMPDCADecoder.GetPosition: Int64;
begin
  Result := FDecoder.RawPosition
end;

function TAIMPDCADecoder.GetSize: Int64;
begin
  Result := FDecoder.RawSize;
end;

function TAIMPDCADecoder.SetPosition(const Value: Int64): LongBool;
begin
  FDecoder.RawPosition := Value;
  Result := True;
end;

function TAIMPDCADecoder.Read(Buffer: PByte; Count: Integer): Integer;
begin
  Result := FDecoder.Read(Buffer, Count);
end;

{ TAIMPDCADecoderExtension }

constructor TAIMPDCADecoderExtension.Create(AOwner: TAIMPDCAPlugin);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TAIMPDCADecoderExtension.CreateDecoder(Stream: IAIMPStream;
  Flags: DWORD; ErrorInfo: IAIMPErrorInfo; out Decoder: IAIMPAudioDecoder): HRESULT;
var
  ADCADecoder: TDCADecoder;
begin
  if CreateDCADecoder(Stream, ADCADecoder) then
  begin
    Decoder := TAIMPDCADecoder.Create(ADCADecoder);
    Result := S_OK;
  end
  else
    Result := E_FAIL;
end;

{ TAIMPDCAFileFormat }

constructor TAIMPDCAFileFormat.Create(AOwner: TAIMPDCAPlugin);
begin
  inherited Create;
  FOwner := AOwner;
end;

function TAIMPDCAFileFormat.GetDescription(out S: IAIMPString): HRESULT;
begin
  S := MakeString('Digital Theater System (DTS)');
  Result := S_OK;
end;

function TAIMPDCAFileFormat.GetExtList(out S: IAIMPString): HRESULT;
begin
  S := MakeString('*.dts;*.wav;');
  Result := S_OK;
end;

function TAIMPDCAFileFormat.GetFlags(out Flags: Cardinal): HRESULT;
begin
  Flags := AIMP_SERVICE_FILEFORMATS_CATEGORY_AUDIO;
  Result := S_OK;
end;

{ TAIMPDCAPlugin }

function TAIMPDCAPlugin.InfoGet(Index: Integer): PWideChar;
begin
  case Index of
    AIMP_PLUGIN_INFO_NAME:
      Result := 'Digital Theater System (DTS) v1.23';
    AIMP_PLUGIN_INFO_AUTHOR:
      Result := 'Artem Izmaylov';
    AIMP_PLUGIN_INFO_SHORT_DESCRIPTION:
      Result := 'Based on the libdca.dll';
    AIMP_PLUGIN_INFO_FULL_DESCRIPTION:
      Result := 'Refer to the www.videolan.org/developers/libdca.html for more information';
  else
    Result := nil;
  end;
end;

function TAIMPDCAPlugin.InfoGetCategories: Cardinal;
begin
  Result := AIMP_PLUGIN_CATEGORY_DECODERS;
end;

function TAIMPDCAPlugin.Initialize(Core: IAIMPCore): HRESULT;
begin
  Result := inherited Initialize(Core);
  if Succeeded(Result) then
  begin
    Core.RegisterExtension(IID_IAIMPServiceAudioDecoders, TAIMPDCADecoderExtension.Create(Self));
    Core.RegisterExtension(IID_IAIMPServiceFileFormats, TAIMPDCAFileFormat.Create(Self));
  end;
end;

end.
