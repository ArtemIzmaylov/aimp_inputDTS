#pragma once
#include <apiTypes.h>
#include <apiObjects.h>

extern "C" 
{
	#include <inttypes.h>
	#include <dca.h>
}

const int MM_ACCEL_DEFAULT = 0;
const int DCA_MAX_FRAME = 4096;
const int DCA_MAX_SAMPLES_PER_BLOCK = 256;
const int DCA_MAX_SEEKING_FRAME = 2 * DCA_MAX_FRAME;
const int DCA_MAX_SEEKING = 8; // For Nero Images

class Buffer
{
public:
	BYTE* data;
	int size; // readonly
	int used;
	Buffer(int size);
	~Buffer();
	int extract(BYTE* target, int maxTarget);
};

class DTSParser
{
private:
	const int NumberOfFramesToCheckTheStream = 3;
private:
	Buffer* buffer;
	int blockCount;
	int blockIndex;
	int channelsFlags;
	int channels;
	int bitrate; 
	int sampleRate;
	SINGLE duration;
	dca_state_t* state;
	IAIMPStream* stream;
	INT64 contentOffset;

	BOOL initializeChannelsLayout();
	BOOL isValidFrameSize(int size);
	BOOL readFrame(int* flags, int* frameSize, int* br, int* sr);
public:
	DTSParser(IAIMPStream* stream);
	~DTSParser();
	BOOL initialize();

	INT32 getBitrate()		{ return bitrate; };
	INT32 getChannels()		{ return channels; };
	INT32 getSampleRate()	{ return sampleRate; };
	INT64 getStreamSize()	{ return stream->GetSize(); };
	SINGLE getDuration()		{ return duration; }
	SINGLE getPosition();
	void setPosition(SINGLE seconds);

	SINGLE* extractBlock();
	bool hasData();
	bool prepareNextFrame();
};
