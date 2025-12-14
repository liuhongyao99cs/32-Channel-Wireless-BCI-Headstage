#pragma once
///////////////////////////////////////////////////////////////////////

#pragma once

///////////////////////////////////////////////////////////////////////

#include <iostream>
#include <fstream>
#include <thread>
#include <winsock.h>
#include <cstdio>
#include <cstdint>
#include <cassert>
#include <chrono>
#include <algorithm>
#include <deque>
#include <cmath>
#include "neuralite.h"

#pragma comment (lib, "ws2_32.lib")

using namespace std;
using namespace chrono;

///////////////////////////////////////////////////////////////////////

class Server {
protected:
	SOCKET tcp_sock_server = 0;
	SOCKET tcp_sock_headstage = 0;
	SOCKADDR_IN udp_addr_headstage;
	SOCKET udp_sock_tx = 0;
	SOCKET udp_sock_rx = 0;

	bool  estUdpConn();
	bool  estTcpConn();
	bool  training();
	bool  setupFrameBuffer();
	bool  setupLrsMap();
	bool  handshake();
	bool  recvBytesFromTcp(SOCKET, char*, int);
	bool  sendBytesToTcp(SOCKET, char*, int);
	bool  sendMsgToTcp(SOCKET, char*);
	bool  sendBytesToUdp(SOCKET, sockaddr_in*, char*, int);
	bool  sendMsgToUdp(SOCKET, sockaddr_in*, char*);
	char* recvMsgFromTcp(SOCKET);
	bool  recvBytesFromUdp(SOCKET, char*, int);
	char* recvMsgFromUdp(SOCKET);

public:
	Server() {};
	~Server() { WSACleanup(); };

	bool Sock_Connect();
	bool streamer();
	bool Mindzip_Server_Matlab();
	bool Mindzip_Init(const char*, const char*, const char*);
	bool Mindzip_Send(SOCKET, char*, int);
	bool  Recv(char*, int);
	bool  Send(int);
};

