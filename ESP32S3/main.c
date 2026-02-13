///////////////////////////////////////////////////////////
#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "esp_heap_caps.h"
#include "spi_interface.h"
#include "wifi.h"
#include "tcp.h"
///////////////////////////////////////////////////////////

const int SPI_FRAME_BITLEN = 32*8*20 + 16;
const int SPI_FRAME_SIZE = SPI_FRAME_BITLEN/8;
const int WIFI_FRAME = 20; // 16 spi frames forms a spi frame
const int WIFI_LEN = 4096*2;

#define N  1000
#define EXPECTED_FRAMES 300

char seq_log[N] = {0};
uint64_t time_log[N] = {0};
uint64_t cnt = 0;

char* spi_buf = NULL;
char* wifi_buf = NULL;
char* tmp_buf = NULL;
char* send_buf = NULL;
TaskHandle_t h_wifi_task = NULL;
TaskHandle_t h_spi_task = NULL;
bool spi_frame_rdy;
char* request = NULL;
char* response = NULL;

void wifiTask();
void spiTask();
inline void swap(char** a, char** b) 
{
    char* tmp = *a;
    *a = *b;
    *b = tmp;
}

///////////////////////////////////////////////////////////
#define Nx 40000
#define Ny 5
#define PACKET_SIZE 1440*6


void app_main(void)
{  
    initWiFi();
    initTCP();
    initSPI();

    spi_buf  = heap_caps_malloc(SPI_FRAME_SIZE, MALLOC_CAP_DMA);
    wifi_buf = heap_caps_malloc(SPI_FRAME_SIZE, MALLOC_CAP_DMA);
    send_buf  = heap_caps_malloc(SPI_FRAME_SIZE*WIFI_FRAME, MALLOC_CAP_DMA);
    

    /*
    for (int j=0;j<N;j++) {
    //while (true) {
        recvFromSPI(spi_buf,SPI_FRAME_SIZE); 
        for (int k=0;k<12;k++){
            printf("%d ", spi_buf[k]);
        }
        swap(&spi_buf, &wifi_buf);
        printf("\n");
        //xTaskNotifyGive(h_spi_task);
    }
    */

    // wifi variation 
    // for ( int i=0; i < WIFI_LEN; i = i + 1){
    //    send_buf[i] = 12;
    //}
    /*
    while (true) {
        uint64_t start = esp_timer_get_time();
        uint64_t i = 0;
        while ( true ){
            sendToTcp(send_buf,WIFI_LEN);
            uint64_t end = esp_timer_get_time();
            i = i + WIFI_LEN*8;
            if ( (end-start) > 1e6 ) {
                printf("Wifi rate: %.4f Mbps\n", (double)((i)/(end-start)));
                break;
            }
        }
    }*/

    // spi 
    
    assert(xTaskCreatePinnedToCore(spiTask,
                                   "spiTask",
                                   4096,
                                   NULL,
                                   10,
                                   &h_spi_task,
                                   1)
    == pdPASS);

    assert(xTaskCreatePinnedToCore(wifiTask,
                                   "wifiTask",
                                   4096,
                                   NULL,
                                   10,
                                   &h_wifi_task,
                                   0)
    == pdPASS);
    
    
    while (true) {
        vTaskDelay(500/portTICK_PERIOD_MS);
    }
    
}

void wifiTask()
{
    
    xTaskNotifyGive(h_spi_task);
    int n_repeat = 0;
    int n_seq_err = 0;
    int n_data_err = 0;
    uint64_t start = esp_timer_get_time();
    uint64_t last_seq = 0;
    uint8_t prev_id = 0;
    uint8_t err = 0;
    //uint8_t id_arr[N] = {0};
    //for (int j=0;j<N;j++) {
    int j = 0;
    while (true) {
        // 1. Wait for SPI reception completion signal
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        
        // 2. Swap pointers to retrieve data, and immediately notify the SPI task to continue collecting the next frame
        // Giving the signal early reduces the SPI task's wait time and improves throughput
        swap(&spi_buf, &wifi_buf);
        xTaskNotifyGive(h_spi_task);
        
        // 3. Copy the received wifi_buf data to the corresponding position in send_buf
        // Here, j represents the current packet index (starting from 0)
        int buf_offset = j * SPI_FRAME_SIZE;
        memcpy(send_buf + buf_offset, wifi_buf, SPI_FRAME_SIZE);
        
        // 4. Increment counter
        j++;
        
        // 5. Check if WIFI_FRAME packets have been collected
        if (j >= WIFI_FRAME) {
            
            // Full, send the entire large packet
            sendToTcp(send_buf, SPI_FRAME_SIZE * WIFI_FRAME);
            
            // Debug print (optional)
            // printf("Sent %d frames to TCP\n", j);

            // 6. Reset counter, prepare for the next round of collection
            j = 0;
        }
    }
    uint64_t end = esp_timer_get_time();
    //printf("\n");
    //printf("bit rate  = %.2f Mbps\n", (double)(N*SPI_FRAME_BITLEN)/(end-start));
    //for ( int i=0;i<SPI_FRAME_BITLEN/8;i++)
    //    printf("byte  = %d\n", wifi_buf[i]);
    /*printf("Running time: %.4f\n",(double)(end-start)*1e-6);
    printf("n_repeat  = %d\n", n_repeat);
    printf("n_seq_err = %d\n", n_seq_err);
    printf("n_pld_err = %d\n", n_data_err);*/
    printf("\n");

    while (true){
         vTaskDelay(500/portTICK_PERIOD_MS);
    }
}

/*
void spiTask() 
{

    for (int i=0;i<N;i++) {
        //ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        if(i%16==0){
                ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
                recvFromSPI(spi_buf,SPI_FRAME_SIZE); 
        }
        recvFromSPI(spi_buf,SPI_FRAME_SIZE); 
        //xTaskNotifyGive(h_wifi_task);
        memcpy(tmp_buf+(i%WIFI_FRAME)*SPI_FRAME_SIZE,spi_buf,SPI_FRAME_SIZE);
        if(i%16==15){
            printf("Assemble frame %d\n",(int)(i+1)/16);
            xTaskNotifyGive(h_wifi_task);
            //ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        }
    }
    
    while (true){
         vTaskDelay(500/portTICK_PERIOD_MS);
    }
}*/

void spiTask() 
{
    
    
    //for (int i=0;i<N;i++) {
    while ( true ){
        ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        recvFromSPI(spi_buf,SPI_FRAME_SIZE); 
        xTaskNotifyGive(h_wifi_task);
    }
    
    while (true){
         vTaskDelay(500/portTICK_PERIOD_MS);
    }
}
