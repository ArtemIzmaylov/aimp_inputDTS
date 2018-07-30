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

unit AIMP.InputDTS.LibDCA;

{$I AIMP.InputDTS.inc}

interface

const
  MM_ACCEL_DEFAULT = 0;
  MM_ACCEL_X86_MMX = $80000000;
  MM_ACCEL_X86_3DNOW  = $40000000;
  MM_ACCEL_X86_MMXEXT	= $20000000;

  DCA_MONO    = 0; // Mono
  DCA_CHANNEL = 1; // Stereo
  DCA_STEREO  = 2;
  DCA_STEREO_SUMDIFF = 3;
  DCA_STEREO_TOTAL   = 4;
  DCA_3F   =   5; // 3 front channels (left, center, right)
  DCA_2F1R =   6; // 2 front, 1 rear surround channel (L, R, S)
  DCA_3F1R =   7; // 3 front, 1 rear surround channel (L, C, R, S)
  DCA_2F2R =   8; // 2 front, 2 rear surround channels (L, R, LS, RS)
  DCA_3F2R =   9; // 3 front, 2 rear surround channels (C, L, R, LS, RS)
  DCA_4F2R =  10;
  DCA_LFE  = $80; // Low frequency effects channel. Normally used to connect a subwoofer.
                  // Can be combined with any of the above channels.
                  // For example: DCA_3F2R | DCA_LFE -> 3 front, 2 rear, 1 LFE (5.1)

  DCA_ADJUST_LEVEL = $100;
  DCA_CHANNEL_MAX = DCA_3F2R;
  DCA_CHANNEL_BITS = 6;
  DCA_CHANNEL_MASK = $3f;

  DCA_MAX_FRAME = 4096;
  DCA_MAX_SAMPLES_PER_BLOCK = 256;
  DCA_MAX_SEEKING_FRAME = 2 * DCA_MAX_FRAME;
  DCA_MAX_SEEKING = 8; // For Nero Images

const
  LibDCA = 'libdca.dll';

type
  TLevel = Single;
  TDCAState = Pointer;

  TSample32 = Single;
  PSample32 = ^TSample32;

function dca_block(AState: TDCAState): Integer; cdecl; external LibDCA;
function dca_blocks_num(AState: TDCAState): Integer; cdecl; external LibDCA;
function dca_frame(AState: TDCAState; ABuf: PByte; var AFlags: Integer; var ALevel: TLevel; var ABias: TSample32): Integer; cdecl; external LibDCA;
function dca_init(AMMAccel: LongWord): TDCAState; cdecl; external LibDCA;
function dca_samples(AState: TDCAState): PSample32; cdecl; external LibDCA;
function dca_syncinfo(AState: TDCAState; ABuf: PByte; var AFlags, ASampleRate, ABitRate, AFrameLength: Integer): Integer; cdecl; external LibDCA;
procedure dca_free(AState: TDCAState); cdecl; external LibDCA;
implementation

end.
