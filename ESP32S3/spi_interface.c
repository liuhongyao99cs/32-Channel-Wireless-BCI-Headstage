////////////////////////////////////////////////////////////////

#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_private/periph_ctrl.h"
#include "esp_rom_gpio.h"
#include "driver/gpio.h"
#include "hal/gpio_ll.h"
#include "soc/spi_periph.h"
#include "hal/spi_ll.h"
#include "soc/gdma_periph.h"
#include "soc/gdma_channel.h"
#include "hal/gdma_ll.h"
#include "spi_interface.h"
#include "config.h"

////////////////////////////////////////////////////////////////

lldesc_t   *dma_desc;
gdma_dev_t *dma_dev;
spi_dev_t  *spi_dev;

////////////////////////////////////////////////////////////////

bool initSPI()
{
    printf("Start DMA for spi...\n");
    spi_dev = (SPI_DEV==1) ? &GPSPI2:&GPSPI3;
    dma_dev = &GDMA;
    // enable periph
    periph_module_enable(PERIPH_GDMA_MODULE);
    periph_module_enable(spi_periph_signal[SPI_DEV].module);
    // alloc dmadesc
    dma_desc = heap_caps_malloc(sizeof(lldesc_t), MALLOC_CAP_DMA);
    // init DMA
    dma_dev->misc_conf.clk_en = 1;
    dma_dev->channel[DMA_CHAN].in.conf0.in_rst = 1;
    dma_dev->channel[DMA_CHAN].in.conf0.in_rst = 0;
    dma_dev->channel[DMA_CHAN].in.int_ena.in_done = 1;
    switch (SPI_DEV) {
    case SPI2_HOST: dma_dev->channel[DMA_CHAN].in.peri_sel.sel = 0; break;
    case SPI3_HOST: dma_dev->channel[DMA_CHAN].in.peri_sel.sel = 1; break;
    default: ESP_LOGE("", "unkown spi dev"); return false;
    }
    // init pins
    gpio_set_direction(GPIO_SPI_EN, GPIO_MODE_OUTPUT);
    gpio_set_level(GPIO_SPI_EN, 0);
    gpio_set_direction(GPIO_SPI_CS, GPIO_MODE_INPUT);
    esp_rom_gpio_connect_in_signal(GPIO_SPI_CS, spi_periph_signal[SPI_DEV].spics_in, false);
    gpio_ll_iomux_func_sel(GPIO_PIN_MUX_REG[GPIO_SPI_CS], PIN_FUNC_GPIO);
    gpio_set_direction(GPIO_SPI_SCLK, GPIO_MODE_INPUT);
    esp_rom_gpio_connect_in_signal(GPIO_SPI_SCLK, spi_periph_signal[SPI_DEV].spiclk_in, false);
    gpio_ll_iomux_func_sel(GPIO_PIN_MUX_REG[GPIO_SPI_SCLK], PIN_FUNC_GPIO);
    gpio_set_direction(GPIO_SPI_DATA0, GPIO_MODE_INPUT);
    esp_rom_gpio_connect_in_signal(GPIO_SPI_DATA0, spi_periph_signal[SPI_DEV].spid_in, false);
    gpio_ll_iomux_func_sel(GPIO_PIN_MUX_REG[GPIO_SPI_DATA0], PIN_FUNC_GPIO);
    gpio_set_direction(GPIO_SPI_DATA1, GPIO_MODE_INPUT);
    esp_rom_gpio_connect_in_signal(GPIO_SPI_DATA1, spi_periph_signal[SPI_DEV].spiq_in, false);
    gpio_ll_iomux_func_sel(GPIO_PIN_MUX_REG[GPIO_SPI_DATA1], PIN_FUNC_GPIO);
    gpio_set_direction(GPIO_SPI_DATA2, GPIO_MODE_INPUT);
    esp_rom_gpio_connect_in_signal(GPIO_SPI_DATA2, spi_periph_signal[SPI_DEV].spiwp_in, false);
    gpio_ll_iomux_func_sel(GPIO_PIN_MUX_REG[GPIO_SPI_DATA2], PIN_FUNC_GPIO);
    gpio_set_direction(GPIO_SPI_DATA3, GPIO_MODE_INPUT);
    esp_rom_gpio_connect_in_signal(GPIO_SPI_DATA3, spi_periph_signal[SPI_DEV].spihd_in, false);
    gpio_ll_iomux_func_sel(GPIO_PIN_MUX_REG[GPIO_SPI_DATA3], PIN_FUNC_GPIO);
    // init spi slave
    spi_ll_slave_hd_init(spi_dev);
    spi_ll_slave_set_mode(spi_dev, 0, true);
    spi_ll_enable_int(spi_dev);
    return true;
}

void recvFromSPI(char* buf, int buf_size)
{
    lldesc_setup_link(dma_desc, buf, buf_size, true);
    dma_dev->channel[DMA_CHAN].in.conf0.in_rst = 1;
    dma_dev->channel[DMA_CHAN].in.conf0.in_rst = 0;
    dma_dev->channel[DMA_CHAN].in.link.addr = (uint32_t)dma_desc;
    dma_dev->channel[DMA_CHAN].in.int_clr.in_done = 1;
    dma_dev->channel[DMA_CHAN].in.link.start = 1;
    spi_ll_dma_rx_fifo_reset(spi_dev);
    spi_ll_slave_reset(spi_dev);
    spi_ll_dma_rx_enable(spi_dev, true);
    spi_ll_clear_int_stat(spi_dev);
    spi_ll_user_start(spi_dev);

    gpio_set_level(GPIO_SPI_EN, 1);
    while (!spi_ll_usr_is_done(spi_dev))
        ;
    gpio_set_level(GPIO_SPI_EN, 0);
    while (!dma_dev->channel[DMA_CHAN].in.int_raw.in_done)
        ;
}

