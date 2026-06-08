#include "Parser.h"

Buffer::Buffer(int size)
{
    this->used = 0;
    this->size = size;
    this->data = (BYTE*)malloc(size);
}

Buffer::~Buffer()
{
    free(data);
}

int Buffer::extract(BYTE* target, int maxTarget)
{
    int copy = maxTarget > used ? used : maxTarget;
    if (target)
        memcpy(target, data, copy);
    if (copy < used)
        memcpy(&data[0], &data[copy], used - copy);
    used -= copy;
    return copy;
}

/* DTSParser */

DTSParser::DTSParser(IAIMPStream* stream)
{
    this->blockCount = 0;
    this->blockIndex = 0;
    this->bitrate = 0;
    this->sampleRate = 0;
    this->contentOffset = 0;
    this->channels = 0;
    this->channelsFlags = 0;
    this->duration = 0;
    this->stream = stream;
    this->stream->AddRef();
    this->buffer = new Buffer(DCA_MAX_SEEKING_FRAME);
    this->state = dca_init(MM_ACCEL_DEFAULT);
}

DTSParser::~DTSParser()
{
    dca_free(state);
    stream->Release();
    delete buffer;
}

SINGLE* DTSParser::extractBlock()
{
    blockIndex++;
    dca_block(state);
    return dca_samples(state);
}

bool DTSParser::hasData()
{
    return blockIndex < blockCount;
}

SINGLE DTSParser::getPosition()
{
    SINGLE offset = (SINGLE)(stream->GetPosition() - contentOffset);
    if (offset < 0)
        offset = 0;
    return offset / (bitrate / 8.0f);
}

BOOL DTSParser::initialize()
{
    int frameSize = 0;
    if (readFrame(&channelsFlags, &frameSize, &bitrate, &sampleRate))
    {
        if (isValidFrameSize(frameSize) && initializeChannelsLayout())
        {
            if (bitrate <= 3) // todo: variable bitrate
                bitrate = 1411200; // some standard one
            contentOffset = stream->GetPosition();
            duration = (SINGLE)(getStreamSize() - contentOffset) / (bitrate / 8.0f);
            
            // check few frames to ensure the stream is a real DTS stream
            for (int i = 0; i < NumberOfFramesToCheckTheStream; i++) 
            {
                if (!prepareNextFrame())
                    return false;
            }

            // rollback to first frame
            stream->Seek(contentOffset, AIMP_STREAM_SEEKMODE_FROM_BEGINNING);
            return prepareNextFrame();
        }
    }
    return false;
}

BOOL DTSParser::initializeChannelsLayout()
{
    switch (channelsFlags & DCA_CHANNEL_MASK) 
    {
        case DCA_MONO:
            channelsFlags = DCA_MONO;
            channels = 1;
            return true;

        case DCA_3F2R:
        case DCA_4F2R:
            channelsFlags = DCA_3F2R | DCA_LFE;
            channels = 6;
            return true;

        default:
            channelsFlags = DCA_STEREO;
            channels = 2;
            return true;
    }
}

BOOL DTSParser::isValidFrameSize(int size)
{
    return size > 0 && size <= DCA_MAX_FRAME;
}

bool DTSParser::prepareNextFrame()
{
    int flags = 0;
    int frameSize = 0;
    int unused = 0;
    if (readFrame(&flags, &frameSize, &unused, &sampleRate)) 
    {
        sample_t bias = 0.0f;
        level_t level = 1.0f;
        flags = channelsFlags | DCA_ADJUST_LEVEL;

        if (dca_frame(state, (uint8_t*)buffer->data, &flags, &level, bias) == 0) 
        {
            blockCount = dca_blocks_num(state);
            blockIndex = 0;
        }

        stream->Seek(frameSize, AIMP_STREAM_SEEKMODE_FROM_CURRENT);
        return hasData();
    }
    return false;
}

BOOL DTSParser::readFrame(int* flags, int* frameSize, int* br, int* sr)
{
    (*frameSize) = 0;
    INT64 framePos = 0;
    INT32 frameLength = 0;
    for (int i = 0; i < DCA_MAX_SEEKING; i++) 
    {
        framePos = stream->GetPosition();
        buffer->used = stream->Read(buffer->data, buffer->size);
        if (buffer->used == 0) break; // EOF

        uint8_t* scan = (uint8_t*)buffer->data;
        int scanLeft  = buffer->used;
        while (scanLeft > 0) 
        {
            *frameSize = dca_syncinfo(state, scan, flags, sr, br, &frameLength);
            if (isValidFrameSize(*frameSize)) break;
            framePos++;
            scanLeft--;
            scan++;
        }
        buffer->extract(nullptr, buffer->used - scanLeft);

        if (*frameSize > 0)
        {
            if (buffer->used < *frameSize)
            {
                stream->Seek(framePos, AIMP_STREAM_SEEKMODE_FROM_BEGINNING);
                buffer->used = stream->Read(buffer->data, buffer->size);
            }
            stream->Seek(framePos, AIMP_STREAM_SEEKMODE_FROM_BEGINNING);
            return true;
        }

        // for fast scan data in Disk Images (ISO)
        stream->Seek(64 * 1024, AIMP_STREAM_SEEKMODE_FROM_CURRENT);
    }

    return false;
}

void DTSParser::setPosition(SINGLE seconds)
{
    stream->Seek(contentOffset + (INT64)(seconds * bitrate / 8.0f), AIMP_STREAM_SEEKMODE_FROM_BEGINNING);
}
