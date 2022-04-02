 library aimp_InputDTS;

{$I AIMP.InputDTS.inc}

uses
  apiPlugin, AIMP.InputDTS.Plugin;

function AIMPPluginGetHeader(out Header: IAIMPPlugin): HRESULT; stdcall;
begin
  try
    Header := TAIMPDCAPlugin.Create;
    Result := S_OK;
  except
    Result := E_UNEXPECTED;
  end;
end;

exports
  AIMPPluginGetHeader;

begin
end.
