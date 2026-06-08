#include "Decoder.h"

Decoder::Decoder(DTSParser* parser)
{
	this->parser = parser;
	bytesPerBlock = parser->getChannels() * sizeof(SINGLE);
	bytesPerSecond = parser->getSampleRate() * bytesPerBlock;
	buffer = new Buffer(DCA_MAX_SAMPLES_PER_BLOCK * bytesPerBlock);

	if (parser->getChannels() == 6/*5.1*/)
	{
		// DTS: C, L, R, LS, RS, SW
		// 5.1: L, R, C, SW, LS, RS
		reorderMap[0] = 2;
		reorderMap[1] = 0;
		reorderMap[2] = 1;
		reorderMap[3] = 4;
		reorderMap[4] = 5;
		reorderMap[5] = 3;
	}
}

Decoder::~Decoder()
{
	delete buffer;
	delete parser;
}

BOOL Decoder::isOurRIID(REFIID riid)
{
	return EqualGUID(riid, IID_IAIMPAudioDecoder);
}

BOOL WINAPI Decoder::GetFileInfo(IAIMPFileInfo* FileInfo)
{
	if (FileInfo != nullptr) 
	{
		FileInfo->SetValueAsFloat(AIMP_FILEINFO_PROPID_DURATION, parser->getDuration());
		FileInfo->SetValueAsInt32(AIMP_FILEINFO_PROPID_BITRATE, parser->getBitrate() / 1000);
		FileInfo->SetValueAsInt32(AIMP_FILEINFO_PROPID_CHANNELS, parser->getChannels());
		FileInfo->SetValueAsInt32(AIMP_FILEINFO_PROPID_SAMPLERATE, parser->getSampleRate());
		FileInfo->SetValueAsInt64(AIMP_FILEINFO_PROPID_FILESIZE, parser->getStreamSize());
	}
	return true;
}

BOOL WINAPI Decoder::GetStreamInfo(INT32* SampleRate, INT32* Channels, INT32* SampleFormat)
{
	(*Channels) = parser->getChannels();
	(*SampleRate) = parser->getSampleRate();
	(*SampleFormat) = AIMP_DECODER_SAMPLEFORMAT_32BITFLOAT;
	return true;
}

BOOL WINAPI Decoder::IsSeekable()
{
	return true;
}

BOOL WINAPI Decoder::IsRealTimeStream()
{
	return false;
}

INT64 WINAPI Decoder::GetAvailableData()
{
	return GetSize() - GetPosition();
}

INT64 WINAPI Decoder::GetSize()
{
	return (INT64)(parser->getDuration() * bytesPerSecond);
}

INT64 WINAPI Decoder::GetPosition()
{
	return (INT64)(parser->getPosition() * bytesPerSecond);
}

BOOL WINAPI Decoder::SetPosition(const INT64 Value)
{
	parser->setPosition((SINGLE)Value / bytesPerSecond);
	return true;
}

INT32 WINAPI Decoder::Read(void* buf, INT32 count)
{
	INT32 result = 0;
	BYTE* target = (BYTE*)buf;
	while (count > 0) 
	{
		if (buffer->used > 0)
		{
			int size = buffer->extract(target, count);
			target += size;
			result += size;
			count -= size;
		}
		else
			if (parser->hasData() || parser->prepareNextFrame())
				populateBuffer(parser->extractBlock());
			else
				break;
	}
	return result;
}

void Decoder::populateBuffer(SINGLE* source)
{
	int channels = parser->getChannels();
	buffer->used = buffer->size;
	for (int channel = 0; channel < channels; channel++)
	{
		SINGLE* target = (SINGLE*)(buffer->data);
		target += reorderMap[channel];
		for (int sample = 0; sample < DCA_MAX_SAMPLES_PER_BLOCK; sample++) 
		{
			(*target) = (*source);
			target += channels;
			source++;
		}
	}
}

Decoder* Decoder::tryCreate(IAIMPStream* stream)
{
	DTSParser* parser = new DTSParser(stream);
	if (parser->initialize())
		return new Decoder(parser);
	delete parser;
	return nullptr;
}
