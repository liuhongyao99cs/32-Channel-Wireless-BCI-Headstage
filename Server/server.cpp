///////////////////////////////////////////////////////////////////////////////

#include <vector>
#include <algorithm>
#include <iostream>
#include "server.h"
#include <fstream>
#include <stdlib.h>
#include <stdio.h>
#include <string>
#include <cmath>
#include <bitset>
#include <cstdint>
#include <thread>
#include <chrono>
#include <atomic>
#include <iomanip>
#include <cstdio>

///////////////////////////////////////////////////////////////////////////////

using namespace std;

const int buf_size = (32 * 8 * 20 + 56) / 8 * 20; //100*1032/8
#define N	      1000 / 20

char Coding_Matrix[NumOfChannels * NumofRows];
char Huff_Length[32 * NumOfDict + MsgHdrLen];
int32_t Huff_Table[32 * NumOfDict];
char* Huff_Table_char = new char[32 * NumOfDict * 4 + MsgHdrLen];	// char array of the Huffman Table
char* rx_buf = new char[buf_size];
char* tx_buf = new char[5];

int main(void)
{

	// Server begin
	Server* server = new Server();

	// TCP Connection and training process(*)
	server->Sock_Connect();

	FILE* fp;
	errno_t err;

	// Pass the address of fp (&fp) as the first argument
	err = fopen_s(&fp, "data.bin", "wb");
	if (err != 0 || fp == nullptr) {
		std::cerr << "Open file fail" << std::endl;
		return -1;
	}

	auto start_time = std::chrono::high_resolution_clock::now();

	for (int i = 0; i < N; i++) {

		if (server->Recv(rx_buf, buf_size)) {
			for (int i = 0; i < 12; i++) {
				cout << std::hex << std::setw(2) << std::setfill('0') << static_cast<unsigned int>(static_cast<unsigned char>(rx_buf[i])) << " ";
			}
			cout << endl;
			fwrite((void*)rx_buf, 1, buf_size, fp);
		}
	}

	fclose(fp);

	auto end_time = std::chrono::high_resolution_clock::now();
	auto total_elapsed_ms = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count();
	double total_seconds = total_elapsed_ms / 1000.0;

	while (1)
		;
	return 0;
}


bool Server::Sock_Connect() {		// connect to HEADSTAGE tcp

	while (1) {
		if (handshake()) {
			break;
		};
		std::this_thread::sleep_for(std::chrono::milliseconds(800));
	}

	return true;
}

bool Server::handshake()
{
	if (estTcpConn()) {
		printf("handshake done\n");
		return true;
	}
	closesocket(tcp_sock_server);
	WSACleanup();
	printf("handshake failed\n");
	return false;
}

bool Server::estTcpConn()
{
	WSADATA wsaData;
	assert(WSAStartup(MAKEWORD(2, 2), &wsaData) == 0);
	tcp_sock_server = socket(AF_INET, SOCK_STREAM, 0);
	if (tcp_sock_server < 0) {
		printf("estTcpConn: create socket err: %d\n", errno);
		return false;
	}
	printf("estTcpConn: socket created\n");

	int err = 0;
	int val = 1;
	err = setsockopt(tcp_sock_server, IPPROTO_TCP, TCP_NODELAY, (char*)&val,
		sizeof(val));
	if (err == -1) {
		printf("estTcpConn: failed setting TCP_NODELAY\n");
		return false;
	}

	printf("estTcpConn: socket created on %s:%d\n", SERVER_IP, TCP_PORT);

	SOCKADDR_IN sa = { 0 };
	sa.sin_family = AF_INET;
	sa.sin_addr.s_addr = inet_addr(SERVER_IP);
	sa.sin_port = htons(TCP_PORT);
	if (::bind(tcp_sock_server, (SOCKADDR*)&sa, sizeof(SOCKADDR)) < 0) {
		printf("estTcpConn: bind err: %d\n", errno);
		return false;
	}
	if (listen(tcp_sock_server, 10) < 0) {
		printf("estTcpConn: listen err: %d\n", errno);
		return false;
	}

	printf("estTcpConn: waiting for client connection\n");

	SOCKADDR_IN ca = { 0 };
	int addrlen = sizeof(SOCKADDR);
	tcp_sock_headstage = accept(tcp_sock_server, (SOCKADDR*)&ca,
		&addrlen);
	if (tcp_sock_headstage < 0) {
		printf("estTcpConn: accept connection err: %d\n", errno);
		return false;
	}

	printf("estTcpConn: successfully connected\n");
	return true;
}

bool Server::sendBytesToTcp(SOCKET sock, char* p, int len)
{
	char* p_cur = p;
	char* p_end = p + len;
	while (p_cur < p_end) {
		int n = send(sock, p_cur, p_end - p_cur, 0);
		if (n <= 0) {
			printf("sendBytesToTcp err: %d\n", errno);
			return false;
		}
		p_cur += n;
	}
	return true;
}

bool Server::recvBytesFromTcp(SOCKET sock, char* p, int len)
{
	char* p_end = p + len;
	char* p_cur = p;
	while (p_cur < p_end) {
		int n = recv(sock, p_cur, p_end - p_cur, 0);
		if (n <= 0) {
			printf("recvBytesFromTcp err: %d\n", errno);
			return false;
		}
		p_cur += n;
	}
	return true;
}

char* Server::recvMsgFromTcp(SOCKET sock)
{
	char hdr[MsgHdrLen] = { 0 };
	if (!recvBytesFromTcp(sock, hdr, MsgHdrLen)) {
		printf("recv msg hdr failed\n");
		return NULL;
	}
	u32 len = getMsgLen(hdr);
	u8 code = getMsgCode(hdr);
	u32 fid = getMsgFid(hdr);
	char* msg = new char[len];
	assert(msg);
	setMsgHdr(msg, code, fid, len);
	if (!recvBytesFromTcp(sock, msg + MsgHdrLen, len - MsgHdrLen)) {
		printf("recv msg pld failed\n");
		delete[] msg;
		return NULL;
	}
	//printf("[%08ld] recved %s of %d bytes\n", getMsgFid(msg),
	//	getMsgCodeStr(msg),
	//	getMsgLen(msg));
	return msg;
}


bool Server::Recv(char* rx_buf, int len) {
	if (recvBytesFromTcp(tcp_sock_headstage, rx_buf, len)) {

		return true;
	};
}

bool Server::Send(int tx_buf_size) {
	if (sendBytesToTcp(tcp_sock_headstage, tx_buf, tx_buf_size)) {

		return true;
	};
}