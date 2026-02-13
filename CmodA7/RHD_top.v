`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.07.2024 16:28:49
// Design Name: 
// Module Name: RHD_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RHD_top(
    
    input           sysclk,
    input           reset_n,   
    
    // for esp spi communication port
    
    input  wire ESP32_EN,
    output wire ESP32_CS,
    output wire ESP32_SCLK,
    
    
    output wire ESP32_DATA0,
    output wire ESP32_DATA1,
    output wire ESP32_DATA2,
    output wire ESP32_DATA3,
    
    // RHD signals
    input  wire  rhd_miso,
    output  rhd_mosi,
    output  rhd_cs,
    output  rhd_sck,
    
    output          led,
    output          led1
    
);
    
    
    
    // select a 20MHz clock to drive the Intan chip
    wire clk, clk50, clk160;
    clk_wiz_0   clk_wiz_inst(
    .clk_in1       ( sysclk    ),
    .clk_out1      ( clk       ),
    .clk_out2      ( clk160    )
    );
    
    // rhd signal select
     wire            rhd_init;
     wire   [15:0]     rd_data;
     wire              rd_data_en;
    
    wire rd_data_en;
    
    RHD RHD_inst (
        .CLK_16mhz(clk),
        .reset_n(reset_n),
        .rhd_miso(rhd_miso),
        .rhd_mosi(rhd_mosi),
        .rhd_cs(rhd_cs),
        .rhd_sck(rhd_sck),
        .rd_data(rd_data),
        .rd_data_en(rd_data_en),
        //.rhd_init(rhd_init),
        .led(led)
      );
     /*
     RHD_init                 RHD_init_inst      (
        .clk                     (   clk            ),
        .rhd_miso                (   rhd_miso       ),
        .rhd_mosi                (   rhd_mosi       ),
        .rhd_cs                  (   rhd_cs         ),
        .rhd_sck                 (   rhd_sck        ),
        .rhd_init                (   rhd_init       ),
        .rhd_data                (   rd_data        ),
        .rhd_data_en             (   rd_data_en     ),
        .led                     (    led           )
        );
    */
    // Encode signal
    


    
        Spi_master spi(

        .clk                    (clk                    ),
        .clk_160mhz             (clk160                 ),
        .reset_n                (reset_n                ),
        //.spi_en                 (spi_en                 ),
        
        .en                     (ESP32_EN               ),
        .cs                     (ESP32_CS               ),
        .sclk                   (ESP32_SCLK             ),
        .data0                  (ESP32_DATA0            ),
        .data1                  (ESP32_DATA1            ),
        .data2                  (ESP32_DATA2            ),
        .data3                  (ESP32_DATA3            ),
        .rd_data                (rd_data                ),
        .rd_data_en             (rd_data_en             )
        
        //.frame                  (spi_frame              ),
        //.spi_frame_id           (spi_f_cnt              ) 

        ); 
        
endmodule
