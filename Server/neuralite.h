#pragma once
///////////////////////////////////////////////////////////////////////////////

#ifndef CONFIG_H
#define CONFIG_H

///////////////////////////////////////////////////////////////////////////////

#include <stdint.h>

typedef int8_t   i8;
typedef uint8_t  u8;
typedef uint16_t u16;
typedef int16_t  i16;
typedef uint32_t u32;
typedef uint64_t u64;

///////////////////////////////////////////////////////////////////////////////

#define SERVER_IP    "192.168.1.105"
#define HEADSTAGE_IP "192.168.1.106"
#define TCP_PORT     2000
#define UDP_PORT     3000

///////////////////////////////////////////////////////////////////////////////

#define FiringRateThresh 0.07

#define NumOfChannels    385
#define NumofRows		 8
#define Huffman_Depth    5
#define NumOfDict		 10
#define FrameRate        400

// consts
#define MaxNumOfChannels 4096
#define MinFrameRate     158
#define SampleRate       20000
#define SampleBitwidth   10
#define SamplesPerGrp    3 // for 32-bit RAM access
#define SampleGrpSize    4
#define SpikeLen         18 // 1.5ms
#define TrainingPeriod   1.0f // seconds

// headstage-side bufs
#define HsTxBufSize      4380
#define HsRxBufSize      1460

// define frame size
#define FrameWidth  SampleGrpSize * (int)ceil((float)NumOfChannels/SamplesPerGrp)
#define FrameHeight SampleRate / FrameRate
#define FrameSize   FrameHeight * FrameWidth

///////////////////////////////////////////////////////////////////////////////

#define MsgHdrLen 6 

//const u64 MsgHdrBitMaskCode = 0x00000000000f; //  4-bit
//const u64 MsgHdrBitMaskLen  = 0x0000000ffff0; // 16-bit
//const u64 MsgHdrBitMaskFid  = 0xfffffff00000; // 28-bit

void setMsgHdr(char* msg, u8 code, u32 fid, u32 len) {
	u64 tmp = code + (len << 4) + ((u64)fid << 20);
	memcpy(msg, (char*)&tmp, MsgHdrLen);
}
u32 getMsgFid(char* msg) {
	return (*(u32*)(msg + 2) >> 4) & 0x0fffffff;
}
u32 getMsgLen(char* msg) {
	return (*(u32*)msg >> 4) & 0x0000ffff;
}
u8 getMsgCode(char* msg) {
	return (u8)(msg[0] & 0x0f);
}

#define MSG_CODE     1
#define MSG_HUFF_LEN      2
#define MSG_HUFF_TAB  3


inline const char* getMsgCodeStr(char* msg) {
	switch (getMsgCode(msg)) {
	case MSG_CODE:			return "Code matrix";
	case MSG_HUFF_LEN:		return "Huff Length";
	case MSG_HUFF_TAB:		return "Huff Table ";
	}
	return NULL;
}

///////////////////////////////////////////////////////////////////////////////

typedef struct {
	u16 n_samples;
} SamplesHdr;

#define SamplesHdrLen 2
#define MaxSamplesPldLen HsTxBufSize-MsgHdrLen-SamplesHdrLen
#define MaxSamplesPerMsg SamplesPerGrp*MaxSamplesPldLen/SampleGrpSize

inline SamplesHdr* samplesHdr(char* msg) {
	return (SamplesHdr*)(msg + MsgHdrLen);
}

///////////////////////////////////////////////////////////////////////////////

typedef struct {
	u16 n_req_samples;
	u16 n_reqs;
	bool more;
} HdsReqHdr;

#define HdsReqHdrLen 5

typedef struct {
	i8 sample_idx;
	u16 channel;
	u8 step;
} HdsReq;

inline HdsReqHdr* hdsReqHdr(char* msg) {
	return (HdsReqHdr*)(msg + MsgHdrLen);
}

//const u32 HdsReqBitMaskSampleIdx = 0x000000ff; //  8-bit
//const u32 HdsReqBitMaskChannel   = 0x000fff00; // 12-bit
//const u32 HdsReqBitMaskStep      = 0x00f00000; //  4-bit

#define HdsReqCodeLen 3

inline void decHdsReq(char* p, HdsReq* req) {
	req->sample_idx = (i8)p[0];
	req->channel = (u16)p[1] + ((u16)(p[2] & 0x0f) << 8);
	req->step = (u8)((p[2] & 0xf0) >> 4);
}

inline void encHdsReq(char* p, HdsReq* req) {
	p[0] = (char)req->sample_idx;
	p[1] = (char)(req->channel & 0x00ff);
	p[2] = (char)((req->channel >> 8) + (req->step << 4));
}

///////////////////////////////////////////////////////////////////////////////

const u32 SampleMask = 0x000003ff;

inline void writeSample(u32* sample_buf, u16 n, i16 s) {
	u16 i = n / SamplesPerGrp;
	u8 j = (n % SamplesPerGrp) * SampleBitwidth;
	u32 mask = ~(SampleMask << j);
	u32 tmp = 512 + s;
	sample_buf[i] = (sample_buf[i] & mask) + (tmp << j);
}

inline i16 readSample(u32* sample_buf, u16 n) {
	u16 i = n / SamplesPerGrp;
	u8 j = (n % SamplesPerGrp) * SampleBitwidth;
	i16 tmp = (i16)((sample_buf[i] >> j) & SampleMask);
	return tmp - 512;
}

/*
inline u16 readSample(char* buf, u16 n) {
	u16 i = (n * SampleBitwidth) / 8;
	u16 j = (n * SampleBitwidth) % 8;
	u16 tmp = *(u16*)(buf + i) >> j;
	return (u16)(tmp & SampleMask);
}

inline void writeSample(char* buf, u16 n, u16 s) {
	u16 i = (n * SampleBitwidth) / 8;
	u16 j = (n * SampleBitwidth) % 8;
	u16 tmp = *(u16*)(buf + i);
	u16 mask = ~(SampleMask << j);
	tmp = (tmp & mask) + (s << j);
	memcpy(buf + i, &tmp, 2);
}
*/

#endif