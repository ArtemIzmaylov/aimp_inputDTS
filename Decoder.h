#pragma once
#include <apiDecoders.h>
#include <apiTypes.h>
#include <apiWrappers.h>
#include <IUnknownImpl.h>
#include "Parser.h"

/* Decoder */

class Decoder : public IUnknownImpl<IAIMPAudioDecoder>
{
private:
	Buffer* buffer;
	DTSParser* parser;
	int bytesPerBlock;
	int bytesPerSecond;
	int reorderMap[6] = { 0, 1, 2, 3, 4, 5 };
	void populateBuffer(SINGLE* source);
public:
	Decoder(DTSParser* parser);
	~Decoder();
	static Decoder* tryCreate(IAIMPStream* stream);
	BOOL isOurRIID(REFIID riid);

	// IAIMPAudioDecoder
	BOOL WINAPI GetFileInfo(IAIMPFileInfo* FileInfo);
	BOOL WINAPI GetStreamInfo(INT32* SampleRate, INT32* Channels, INT32* SampleFormat);
	BOOL WINAPI IsSeekable();
	BOOL WINAPI IsRealTimeStream();
	INT64 WINAPI GetAvailableData();
	INT64 WINAPI GetSize();
	INT64 WINAPI GetPosition();
	BOOL WINAPI SetPosition(const INT64 Value);
	INT32 WINAPI Read(void* buf, INT32 count);
};
