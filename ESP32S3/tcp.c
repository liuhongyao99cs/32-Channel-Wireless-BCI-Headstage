////////////////////////////////////////////////////////////////

#include <assert.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <errno.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <dirent.h>
#include <math.h>
#include "esp_system.h"
#include "esp_types.h"
#include "esp_timer.h"
#include "esp_sleep.h"
#include "esp_mac.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_netif.h"
#include "esp_attr.h"
#include "esp_log.h"
#include "esp_vfs_fat.h"
#include "sdmmc_cmd.h"
#include "driver/sdmmc_host.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "nvs_flash.h"
#include "lwip/api.h"
#include "lwip/opt.h"
#include "lwip/ip_addr.h"
#include "lwip/netif.h"
#include "lwip/netbuf.h"
#include "lwip/err.h"
#include "lwip/sys.h"
#include "esp_task.h"

#include "config.h"
#include "tcp.h"

////////////////////////////////////////////////////////////////

int tcp_sock;
bool estTcpConn();

////////////////////////////////////////////////////////////////

bool initTCP()
{
    while (!estTcpConn()) {
        vTaskDelay(1000/portTICK_PERIOD_MS);
    }
    return true;
}

int sendtcp(void *p, int len,int flags){
    int n = send(tcp_sock, p, len, 0);
    return n;
}

bool sendToTcp(char* p, int len) 
{
    char* p_cur = p;
    char* p_end = p+len;
    while (p_cur != p_end) {
        int n = send(tcp_sock, p_cur, p_end-p_cur, 0);
        if (n <= 0) {
            ESP_LOGE("sendToTCP", "send err: %d", errno);
            return false;
        }
        p_cur += n;
    }
    return true;
}

bool recvFromTcp(char* buffer, int len) {
    char* p_cur = buffer;
    char* p_end = buffer + len;
    
    while (p_cur < p_end) {
        int n = recv(tcp_sock, p_cur, p_end - p_cur, 0);
        p_cur += n;
    }
    return true;
}

bool estTcpConn() 
{
    tcp_sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (tcp_sock == -1) {
        ESP_LOGE("estTcpConn", "create socket err: %d", errno);
        return false;
    }
    ESP_LOGI("estTcpConn", "socket created");

    int err = 0;
    int val = 1;
    err = setsockopt(tcp_sock, IPPROTO_TCP, TCP_NODELAY, (char*)&val, sizeof(val));
    if (err == -1) {
        ESP_LOGE("estTcpConn", "failed setting TCP_NODELAY");
        close(tcp_sock);
        return false;
    }

    ESP_LOGI("estTcpConn", "connecting to %s:%d", TCP_SERVER_IP, TCP_SERVER_PORT);

    struct sockaddr_in sa = {0};
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = inet_addr(TCP_SERVER_IP);
    sa.sin_port = htons(TCP_SERVER_PORT);
    err = connect(tcp_sock, (struct sockaddr*)&sa, sizeof(sa));
    if (err == -1) {
        ESP_LOGE("estTcpConn", "connect err: %d", errno);
        close(tcp_sock);
        return false;
    }

    ESP_LOGI("estTcpConn", "successfully connected");
    return true;
}