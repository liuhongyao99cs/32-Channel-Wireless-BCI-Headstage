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
#include "wifi.h"

////////////////////////////////////////////////////////////////

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT      BIT1
void wifiStaEventHandler(void*, esp_event_base_t, int32_t, void*);
static EventGroupHandle_t wifi_event_group;

////////////////////////////////////////////////////////////////

bool initWiFi() 
{
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES
     || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);
    ESP_LOGI("initWiFi", "ESP_WIFI_MODE_STA");
    wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    esp_event_handler_instance_t instance_any_id;
    esp_event_handler_instance_t instance_got_ip;
    ESP_ERROR_CHECK(
        esp_event_handler_instance_register(WIFI_EVENT,
                                            ESP_EVENT_ANY_ID,
                                            &wifiStaEventHandler,
                                            NULL,
                                            &instance_any_id));
    ESP_ERROR_CHECK(
        esp_event_handler_instance_register(IP_EVENT,
                                            IP_EVENT_STA_GOT_IP,
                                            &wifiStaEventHandler,
                                            NULL,
                                            &instance_got_ip));
    wifi_config_t wifi_config = {
        .sta = {
            .ssid = WIFI_SSID,
            .password = WIFI_PASSWORD,
            .threshold.authmode = WIFI_AUTH_WPA2_PSK,
        },
    };
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));
    // 设置 STA 的协议为 802.11bgn
    uint8_t protocol = WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N;
    ESP_ERROR_CHECK(esp_wifi_set_protocol(WIFI_IF_STA, protocol));

    // 设置 STA 的带宽为 40 MHz
    ESP_ERROR_CHECK(esp_wifi_set_bandwidth(WIFI_IF_STA, WIFI_BW_HT40));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_LOGI("initWiFi", "wifi_init_sta finished.");
    EventBits_t bits =
        xEventGroupWaitBits(wifi_event_group,
                            WIFI_CONNECTED_BIT|WIFI_FAIL_BIT,
                            pdFALSE, pdFALSE,
                            portMAX_DELAY);

    if (bits & WIFI_CONNECTED_BIT) {
        ESP_LOGI("initWiFi", "connected to SSID: %s password: %s", 
                 WIFI_SSID, WIFI_PASSWORD);
        return true;
    }
    if (bits & WIFI_FAIL_BIT) {
        ESP_LOGI("initWiFi", "failed to connect SSID: %s, password: %s", 
                 WIFI_SSID, WIFI_PASSWORD);
    }
    else {
        ESP_LOGE("initWiFi", "unexpected event");
    }
    return false;
}

void wifiStaEventHandler(void* arg,
                         esp_event_base_t event_base,
                         int32_t event_id,
                         void* event_data)
{
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    }
    else if (event_base == WIFI_EVENT
          && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        xEventGroupSetBits(wifi_event_group, WIFI_FAIL_BIT);
        ESP_LOGI("wifiStaEventHandler", "connect to the AP fail");
    }
    else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*)event_data;
        ESP_LOGI("wifiStaEventHandler", "got ip:" IPSTR, IP2STR(&event->ip_info.ip));
        xEventGroupSetBits(wifi_event_group, WIFI_CONNECTED_BIT);
    }
}