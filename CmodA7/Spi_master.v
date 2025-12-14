`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2024 13:54:05
// Design Name: 
// Module Name: top
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
/////////////////////////////////////////////////////////////

/*module Spi_master (
    input   wire clk,
    input   wire clk_160mhz,
    input   wire reset_n,
    input   wire en,
    output  reg  cs,
    output  reg  sclk,
    output  reg  data0,
    output  reg  data1,
    output  reg  data2,
    output  reg  data3,
    
    input wire [15:0] rd_data,
    input wire rd_data_en

    //input  wire spi_en,
    //input  wire [32*16*200-1:0] frame,
    //input  wire [31:0] spi_frame_id
);

       localparam Hdr_Len = 32;       
       localparam SPI_IDLE          = 3'b000;
       localparam SPI_INIT          = 3'b001;
       localparam SPI_TRANSMIT      = 3'b010;
       localparam SPI_CSOFF         = 3'b011; 
       localparam SPI_LOAD          = 3'b111; 
       localparam SPI_LOAD1         = 3'b110; 
       localparam SPI_LOAD2         = 3'b100; 
       
       localparam [7:0] cmd         = 8'h03;        
       localparam [7:0] addr        = 8'h00;
       localparam [7:0] dummy       = 8'h00;  
       localparam [31:0] frame_len  = 32*8*50;//11496;                         // content
       
       localparam [31:0] trans_len  = 56+frame_len;               // 1000 bytes
       localparam csoff_len         = 120*1;//160*30;
       localparam en_len            = 120*1;//160;
       
        reg [7:0] seq = 0;
        //reg [trans_len-1:0] tx_buf = 0;
        reg [31:0] tx_cnt = 0;
        reg [15:0] csoff_tick = 0;
        reg [15:0] en_tick = 0;
        reg [2:0]  spi_state = SPI_IDLE;
        reg [15:0] off_cnt = 0;
        
        reg frame_enable;
        reg spi_flag = 0;
        integer i;
        
          //reg [32*8*150-1:0] frame;
          
          reg ping_pong_flag;
          (* ram_style = "block" *) reg [7:0] frame1 [frame_len/8-1:0];
          (* ram_style = "block" *) reg [7:0] frame2 [frame_len/8-1:0];
          
          reg [15:0] byte_cnt;
          reg frame_en;
          always @(posedge clk or posedge reset_n)
          begin
            if (reset_n)
            begin
              byte_cnt <= 0;
              frame_en <= 0;
              ping_pong_flag <= 0;
            end
            else
            begin
              frame_en <= 0;
              if (rd_data_en)
              begin
                byte_cnt <= byte_cnt + 1;
                //frame[byte_cnt*8+:8] <= 8'hab; // rd_data[15:7];
                if (ping_pong_flag == 0)
                    frame1[byte_cnt] <= 8'hab;
                else
                    frame2[byte_cnt] <= 8'hab;
                    
                if (byte_cnt == frame_len / 8 - 1)
                begin
                  byte_cnt <= 0;
                  frame_en <= 1;
                  ping_pong_flag <= ~ping_pong_flag;
                end
              end
            end
          end
        
          reg [31:0] frame_cnt;
          reg [31:0] spi_frame_id;
          always @(posedge clk or posedge reset_n)
          begin
            if (reset_n)
            begin
              frame_cnt <= 0;
              spi_frame_id <= 0;
            end
            else if (frame_en)
            begin
              frame_cnt <= frame_cnt + 1;
              spi_frame_id <= spi_frame_id + 1;
            end
          end
          
          reg spi_en;
          always @(posedge clk or posedge reset_n)
          begin
            if (reset_n)begin
              spi_en <= 0;
            end else if (frame_en) begin
              spi_en <= 1;
            end
          end
                
       // sender 
       reg [31:0] prev_frame_id = 0;
       reg [15:0] bit_len = 0;
       reg [15:0] spi_frame_cnt = 0;
       reg [15:0] tx_buf_cnt;
       integer i;
       
       reg [7:0] current_byte;
        reg [31:0] frame_idx;
       
       wire [7:0] header [0:6];
        assign header[0] = cmd;
        assign header[1] = addr;
        assign header[2] = dummy;
        assign header[3] = spi_frame_id[31:24];
        assign header[4] = spi_frame_id[23:16];
        assign header[5] = spi_frame_id[15:8];
        assign header[6] = spi_frame_id[7:0];
             
      always @(posedge clk_160mhz) begin
      
      if (reset_n) begin
        spi_state     <= SPI_IDLE;
        data0         <= 1'b0;
        data1         <= 1'b0;
        data2         <= 1'b0;
        data3         <= 1'b0;
        sclk          <= 1'b0;
        cs            <= 1'b1;
        en_tick       <= 0;
        csoff_tick    <= 0;
        tx_cnt        <= 0;
        prev_frame_id <= 0;
        //tx_buf        <= 0;
      end else begin
      
          if ( spi_en ) begin
            case (spi_state)
                SPI_IDLE: begin
                    data0 <= 0;
                    data1 <= 0;
                    data2 <= 0;
                    data3 <= 0;
                    sclk <= 0;
                    cs <= 1;
           
                    if (!en) begin
                        en_tick <= 0;
                    end else begin
                        if (en_tick < en_len) begin
                            en_tick <= en_tick + 1;
                        end else begin
                            prev_frame_id <= spi_frame_id;
                            //tx_buf <= {cmd,addr,dummy,spi_frame_id,frame};
                            spi_state <= (prev_frame_id==spi_frame_id) ? SPI_IDLE : SPI_LOAD;
                             //  spi_state <= SPI_LOAD;
                        end
                    end
                end
                
                SPI_LOAD : begin
    
                    spi_state <= SPI_INIT;
                end
     
                SPI_INIT: begin
                    // 发送 tx_buf[0] 的最高位 (Bit 7)
                    // 注意：原代码 tx_buf[trans_len-1] 是错误的，应该从第0个字节开始发
                    data0     <= header[0][7]; 
                    data1     <= 0;
                    data2     <= 0;
                    data3     <= 0;
                    cs        <= 0;
                    tx_cnt    <= 1; // 已经发了1个bit，计数器置1
                    spi_state <= SPI_TRANSMIT;
                end

                SPI_TRANSMIT: begin
                    sclk <= ~sclk; 
                    
                    if (sclk) begin // sclk negedge (数据改变时刻)
                        if (tx_cnt >= trans_len) begin
                            // 数据发送完毕
                            csoff_tick <= 0;
                            spi_state  <= SPI_CSOFF;
                        end else begin
                            // 核心修改逻辑：
                            // 1. tx_cnt >> 3 : 算出当前是第几个字节 (Byte Index)
                            // 2. tx_cnt & 7  : 算出当前是第几位 (0-7)
                            // 3. 7 - (...)   : 实现 MSB First (先发Bit 7，最后发Bit 0)
                            if ((tx_cnt >> 3) < 7) begin
                                data0 <= header[tx_cnt >> 3][3'd7 - (tx_cnt & 3'd7)];
                            end else begin
                                if (ping_pong_flag == 0)    
                                    data0  <= frame1[tx_cnt >> 3][3'd7 - (tx_cnt & 3'd7)];
                                else
                                    data0  <= frame2[tx_cnt >> 3][3'd7 - (tx_cnt & 3'd7)]; 
                            end   
                            
                            data1  <= 0;
                            data2  <= 0;
                            data3  <= 0;
                            tx_cnt <= tx_cnt + 1;
                        end
                    end
                end
    
                SPI_CSOFF: begin
                    data0 <= 0;
                    data1 <= 0;
                    data2 <= 0;
                    data3 <= 0;
                    sclk <= 0;
                    cs <= 1;
                    csoff_tick <= csoff_tick + 1;
                    if ( (csoff_tick >= csoff_len)) begin
                        en_tick <= 0;
                        spi_state <= SPI_IDLE;
                    end
                end
            endcase
            end
        end
    end

endmodule*/


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.05.2024 13:54:05
// Design Name: 
// Module Name: top
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
/////////////////////////////////////////////////////////////


module Spi_master (
    input   wire clk,
    input   wire clk_160mhz,
    input   wire reset_n,
    input   wire en,
    output  reg  cs,
    output  reg  sclk,
    output  reg  data0,
    output  reg  data1,
    output  reg  data2,
    output  reg  data3,
    
    input wire [15:0] rd_data,
    input wire rd_data_en

    //input  wire spi_en,
    //input  wire [32*16*200-1:0] frame,
    //input  wire [31:0] spi_frame_id
);

       localparam Hdr_Len = 32;       
       localparam SPI_IDLE          = 3'b000;
       localparam SPI_INIT          = 3'b001;
       localparam SPI_TRANSMIT      = 3'b010;
       localparam SPI_CSOFF         = 3'b011; 
       localparam SPI_LOAD          = 3'b111; 
       localparam SPI_LOAD1         = 3'b110; 
       localparam SPI_LOAD2         = 3'b100; 
       
       localparam [7:0] cmd         = 8'h03;        
       localparam [7:0] addr        = 8'h00;
       localparam [7:0] dummy       = 8'h00;  
       localparam [31:0] frame_len  = 32*8*20;//11496;                         // content
       
       localparam [31:0] trans_len  = 56+frame_len;               // 1000 bytes
       localparam csoff_len         = 40;//160*30;
       localparam en_len            = 20;//160;
       
        reg [7:0] seq = 0;
        reg [trans_len-1:0] tx_buf = 0;
        reg [31:0] tx_cnt = 0;
        reg [15:0] csoff_tick = 0;
        reg [15:0] en_tick = 0;
        reg [2:0]  spi_state = SPI_IDLE;
        reg [15:0] off_cnt = 0;
        
        reg frame_enable;
        reg spi_flag = 0;
        integer i;
        
          reg [frame_len-1:0] frame;
                    
          reg [15:0] byte_cnt;
          reg frame_en;
          always @(posedge clk_160mhz or posedge reset_n)
          begin
            if (reset_n)
            begin
              byte_cnt <= 0;
              frame_en <= 0;
                
            end
            else
            begin
              frame_en <= 0;
              if (rd_data_en)
              begin
                byte_cnt <= byte_cnt + 1;
                frame[byte_cnt*16+:16] <= rd_data[15:0];
                if (byte_cnt == frame_len/16 - 1)
                begin
                  byte_cnt <= 0;
                  frame_en <= 1;
                end
              end
            end
          end
        
          reg [31:0] frame_cnt;
          reg [31:0] spi_frame_id;
          always @(posedge clk_160mhz or posedge reset_n)
          begin
            if (reset_n)
            begin
              frame_cnt <= 0;
              spi_frame_id <= 0;
            end
            else if (frame_en)
            begin
              frame_cnt <= frame_cnt + 1;
              spi_frame_id <= spi_frame_id + 1;
            end
          end
          
          reg spi_en;
          always @(posedge clk_160mhz or posedge reset_n)
          begin
            if (reset_n)begin
              spi_en <= 0;
            end else if (frame_en) begin
              spi_en <= 1;
            end
          end
       
       // sender 
       reg [31:0] prev_frame_id = 0;
       reg [15:0] bit_len = 0;
       reg [15:0] spi_frame_cnt = 0;
       reg [15:0] tx_buf_cnt;
             
      always @(posedge clk_160mhz) begin
      
      if (reset_n) begin
        spi_state     <= SPI_IDLE;
        data0         <= 1'b0;
        data1         <= 1'b0;
        data2         <= 1'b0;
        data3         <= 1'b0;
        sclk          <= 1'b0;
        cs            <= 1'b1;
        en_tick       <= 0;
        csoff_tick    <= 0;
        tx_cnt        <= 0;
        prev_frame_id <= 0;
        tx_buf        <= 0;
      end else begin
      
          if ( spi_en ) begin
            case (spi_state)
                SPI_IDLE: begin
                    data0 <= 0;
                    data1 <= 0;
                    data2 <= 0;
                    data3 <= 0;
                    sclk <= 0;
                    cs <= 1;
           
                    if (!en) begin
                        en_tick <= 0;
                    end else begin
                        if (en_tick < en_len) begin
                            en_tick <= en_tick + 1;
                        end else begin
                            prev_frame_id <= spi_frame_id;
                            tx_buf <= {cmd,addr,dummy,spi_frame_id,frame};                           
                            spi_state <= (prev_frame_id==spi_frame_id) ? SPI_IDLE : SPI_LOAD;
                             //  spi_state <= SPI_LOAD;
                        end
                    end
                end
                
                SPI_LOAD : begin
    
                    spi_state <= SPI_INIT;
                end
     
                SPI_INIT: begin
                    data0 <= tx_buf[trans_len-1];
                    data1 <= 0;
                    data2 <= 0;
                    data3 <= 0;
                    cs <= 0;
                    tx_cnt <= 1;
                    spi_state <= SPI_TRANSMIT;
                end
    
                SPI_TRANSMIT: begin
                    sclk <= ~sclk;
                    if (sclk) begin // sclk negedge
                        if (tx_cnt == trans_len) begin
                            csoff_tick <= 0;
                            spi_state <= SPI_CSOFF;
                        end else begin
                            data0 <=tx_buf[trans_len-tx_cnt-1];
                            data1 <= 0;
                            data2 <= 0;
                            data3 <= 0;
                            tx_cnt <= tx_cnt+1;
                        end
                    end
                end
    
                SPI_CSOFF: begin
                    data0 <= 0;
                    data1 <= 0;
                    data2 <= 0;
                    data3 <= 0;
                    sclk <= 0;
                    cs <= 1;
                    csoff_tick <= csoff_tick + 1;
                    if ( (csoff_tick >= csoff_len)) begin
                        en_tick <= 0;
                        spi_state <= SPI_IDLE;
                    end
                end
            endcase
            end
        end
    end

endmodule
