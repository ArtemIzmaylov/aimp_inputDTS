#include <apiDecoders.h>
#include <apiPlugin.h>
#include <apiTypes.h>
#include <apiWrappers.h>
#include <IUnknownImpl.h>
#include "Decoder.h"

static const TChar Author[] = TEXT("Artem Izmaylov");
static const TChar Name[] = TEXT("Digital Theater System (DTS) v1.30");
static const TChar Description[] = TEXT("Based on the libdca by VideoLAN");
static const TChar DescriptionFull[] = TEXT("*.dts;*.wav;\nhttp://www.videolan.org/developers/libdca.html");

class FileFormatExtension : public IUnknownImpl<IAIMPExtensionFileFormat>
{
private:
    IAIMPCore* core;
public:
    FileFormatExtension(IAIMPCore* core)
    {
        this->core = core;
    }

    virtual BOOL isOurRIID(REFIID riid)
    {
        return EqualGUID(riid, IID_IAIMPExtensionFileFormat);
    }

    HRESULT WINAPI GetDescription(IAIMPString** S)
    {
        (*S) = MakeString(core, TEXT("Digital Theater System (DTS)"));
        return S_OK;
    }
    
    HRESULT WINAPI GetExtList(IAIMPString** S)
    {
        (*S) = MakeString(core, TEXT("*.dts;*.wav;"));
        return S_OK;
    }
    
    HRESULT WINAPI GetFlags(DWORD* S)
    {
        (*S) = AIMP_SERVICE_FILEFORMATS_CATEGORY_AUDIO;
        return S_OK;
    }
};

class DecoderExtension : public IUnknownImpl<IAIMPExtensionAudioDecoder>
{
public:
    HRESULT WINAPI CreateDecoder(IAIMPStream* stream, DWORD Flags, IAIMPErrorInfo* ErrorInfo, IAIMPAudioDecoder** out)
    {
        Decoder* decoder = Decoder::tryCreate(stream);
        if (decoder != nullptr)
        {
            (*out) = decoder;
            (*out)->AddRef();
            return S_OK;
        }
        return E_FAIL;
    }

    virtual BOOL isOurRIID(REFIID riid)
    {
        return EqualGUID(riid, IID_IAIMPExtensionAudioDecoder);
    }
};

class Plugin : public IUnknownImpl<IAIMPPlugin>
{
public:
    PChar WINAPI InfoGet(int Index)
    {
        switch (Index)
        {
        case AIMP_PLUGIN_INFO_NAME:
            return const_cast<PChar>(Name);
        case AIMP_PLUGIN_INFO_AUTHOR:
            return const_cast<PChar>(Author);
        case AIMP_PLUGIN_INFO_SHORT_DESCRIPTION:
            return const_cast<PChar>(Description);
        case AIMP_PLUGIN_INFO_FULL_DESCRIPTION:
            return const_cast<PChar>(DescriptionFull);
        }
        return nullptr;
    }

    DWORD WINAPI InfoGetCategories()
    {
        return AIMP_PLUGIN_CATEGORY_DECODERS;
    }

    HRESULT WINAPI Initialize(IAIMPCore* Core)
    {
        Core->RegisterExtension(IID_IAIMPServiceAudioDecoders, new DecoderExtension());
        Core->RegisterExtension(IID_IAIMPServiceFileFormats, new FileFormatExtension(Core));
        return S_OK;
    }

    HRESULT WINAPI Finalize()
    {
        return S_OK;
    }

    void WINAPI SystemNotification(int NotifyID, IUnknown* Data) {}
};

extern "C" {
HRESULT EXPORT WINAPI AIMPPluginGetHeader(IAIMPPlugin** Header)
{
    (*Header) = new Plugin();
    (*Header)->AddRef();
    return S_OK;
}
}

#ifdef _WIN32
BOOL APIENTRY DllMain(HMODULE m, DWORD r, LPVOID x)
{
    return TRUE;
}
#endif

