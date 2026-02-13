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

/*
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
       
       localparam [31:0] trans_len  = 40+frame_len;               // 1000 bytes
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
                frame[byte_cnt*16+:16] <= rd_data;
                if (byte_cnt == frame_len/16 - 1)
                begin
                  byte_cnt <= 0;
                  frame_en <= 1;
                end
              end
            end
          end
        
          reg [15:0] frame_cnt;
          reg [15:0] spi_frame_id;
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
             
      always @(posedge clk_160mhz or posedge reset_n) begin
      
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
*/
`timescale 1ns / 1ps

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
);

    // ============================================================
    // 参数定义
    // ============================================================
    localparam SPI_IDLE          = 3'b000;
    localparam SPI_INIT          = 3'b001;
    localparam SPI_TRANSMIT      = 3'b010;
    localparam SPI_CSOFF         = 3'b011; 
    localparam SPI_LOAD          = 3'b111; 
    
    localparam [7:0] cmd         = 8'h03;        
    localparam [7:0] addr        = 8'h00;
    localparam [7:0] dummy       = 8'h00;  
    
    // 单帧数据长度
    localparam [31:0] frame_len  = 32*8*20; 
    localparam FRAME_WORDS       = frame_len / 16; 
    localparam HEADER_BITS       = 40; 
    localparam [31:0] trans_len  = HEADER_BITS + frame_len;
    
    localparam csoff_len         = 40;
    localparam en_len            = 20;

    // ============================================================
    // 1. 乒乓缓存存储阵列 (大小翻倍)
    // ============================================================
    // 我们定义 2 * FRAME_WORDS 的空间
    // 地址 0 ~ FRAME_WORDS-1 是 Bank 0
    // 地址 FRAME_WORDS ~ End   是 Bank 1
    (* ram_style = "distributed" *) reg [15:0] frame_mem [0:(FRAME_WORDS*2)-1];
    
    reg wr_bank; // 0: 写前半段, 1: 写后半段
    reg rd_bank; // 0: 读前半段, 1: 读后半段
    
    // 状态机变量
    reg [31:0] tx_cnt = 0;
    reg [15:0] csoff_tick = 0;
    reg [15:0] en_tick = 0;
    reg [2:0]  spi_state = SPI_IDLE;
    
    reg [15:0] byte_cnt; // 当前帧内的 Word 计数
    reg frame_ready_toggle; // 用于通知 SPI 有新的一帧写完了 (翻转信号)
    
    // ============================================================
    // 2. 写入逻辑 (只操作 wr_bank)
    // ============================================================
    always @(posedge clk_160mhz or posedge reset_n) begin
        if (reset_n) begin
            byte_cnt <= 0;
            wr_bank  <= 0;
            frame_ready_toggle <= 0;
        end else begin
            if (rd_data_en) begin
                // 写入地址 = (wr_bank * FRAME_WORDS) + byte_cnt
                // 利用位拼接或者简单的加法
                if (wr_bank == 0) 
                    frame_mem[byte_cnt] <= rd_data;
                else 
                    frame_mem[FRAME_WORDS + byte_cnt] <= rd_data;
                
                byte_cnt <= byte_cnt + 1;
                
                // 如果当前 Bank 写满了
                if (byte_cnt == FRAME_WORDS - 1) begin
                    byte_cnt <= 0;
                    wr_bank  <= ~wr_bank;     // 切换到另一个 Bank 去写
                    frame_ready_toggle <= ~frame_ready_toggle; // 发出"写完一帧"的信号
                end
            end
        end
    end
    
    // ============================================================
    // 3. ID 与 启动信号同步
    // ============================================================
    // 需要检测 frame_ready_toggle 的变化来判断是否有新数据
    reg frame_ready_d;
    wire new_frame_arrived = (frame_ready_d != frame_ready_toggle);
    
    reg [15:0] spi_frame_id;
    
    always @(posedge clk_160mhz or posedge reset_n) begin
        if (reset_n) begin
            frame_ready_d <= 0;
            spi_frame_id <= 0;
        end else begin
            frame_ready_d <= frame_ready_toggle;
            if (new_frame_arrived) begin
                spi_frame_id <= spi_frame_id + 1;
            end
        end
    end
    
    // ============================================================
    // 4. 发送数据选择逻辑 (核心修改：加入 rd_bank)
    // ============================================================
    reg [15:0] latched_frame_id = 0;
    
    // 拼装 Header
    wire [HEADER_BITS-1:0] header_vec = {cmd, addr, dummy, latched_frame_id};
    wire is_header_phase = (tx_cnt < HEADER_BITS);
    wire [31:0] data_offset = tx_cnt - HEADER_BITS;
    wire [31:0] word_idx = data_offset[31:4]; 
    wire [3:0]  bit_in_word = 4'd15 - data_offset[3:0];

    // 计算实际读取地址
    // 如果 rd_bank=0, 读 word_idx
    // 如果 rd_bank=1, 读 word_idx + FRAME_WORDS
    wire [31:0] mem_rd_addr = (rd_bank == 0) ? word_idx : (FRAME_WORDS + word_idx);

    wire current_tx_bit;
    
    assign current_tx_bit = (is_header_phase) ? 
                            header_vec[HEADER_BITS - 1 - tx_cnt] : 
                            frame_mem[mem_rd_addr][bit_in_word];

    // ============================================================
    // 5. 主状态机 (控制 rd_bank 切换)
    // ============================================================
    reg spi_active; // 标记 SPI 是否正在忙
    
    always @(posedge clk_160mhz or posedge reset_n) begin
        if (reset_n) begin
            spi_state        <= SPI_IDLE;
            data0            <= 1'b0;
            sclk             <= 1'b0;
            cs               <= 1'b1;
            en_tick          <= 0;
            csoff_tick       <= 0;
            tx_cnt           <= 0;
            latched_frame_id <= 0;
            rd_bank          <= 0; // 默认读 Bank 0
            spi_active       <= 0;
        end else begin
            // 只有当 SPI 不忙，且检测到新的一帧数据到达时，才启动
            if (en) begin
                case (spi_state)
                    SPI_IDLE: begin
                        data0 <= 0;
                        cs    <= 1;
                        sclk  <= 0;
                        csoff_tick <= 0;
                        tx_cnt <= 0;

                        // 简单的延时启动逻辑
                        if (en_tick < en_len) begin
                            en_tick <= en_tick + 1;
                        end else begin
                            // 检查是否有新数据
                            // 只有当 写入已经完成了某一个 Bank，我们才去读那个 Bank
                            // 逻辑：如果 wr_bank 和 rd_bank 相同，说明写指针追上了读指针(或刚复位)，
                            // 或者正在写当前块，此时不能读。
                            // 当 wr_bank != rd_bank 时，说明有一个完整的 Bank 等着被读。
                            
                            if (wr_bank != rd_bank) begin
                                // 锁定 ID
                                latched_frame_id <= spi_frame_id; // 这里其实可以用专门的 FIFO 传 ID，简化起见直接取
                                // 状态跳转
                                spi_state <= SPI_LOAD;
                            end
                        end
                    end
                    
                    SPI_LOAD: begin
                        // 准备开始发送
                        spi_state <= SPI_INIT;
                    end
     
                    SPI_INIT: begin
                        data0  <= header_vec[HEADER_BITS-1]; 
                        cs     <= 0;
                        tx_cnt <= 1;
                        spi_state <= SPI_TRANSMIT;
                    end
     
                    SPI_TRANSMIT: begin
                        sclk <= ~sclk;
                        if (sclk) begin 
                            if (tx_cnt == trans_len) begin
                                spi_state  <= SPI_CSOFF;
                            end else begin
                                data0  <= current_tx_bit;
                                tx_cnt <= tx_cnt + 1;
                            end
                        end
                    end
     
                    SPI_CSOFF: begin
                        data0 <= 0;
                        sclk  <= 0;
                        cs    <= 1;
                        csoff_tick <= csoff_tick + 1;
                        if (csoff_tick >= csoff_len) begin
                            // 发送完成！
                            // 关键步骤：切换读取 Bank
                            // 既然我们发完了 rd_bank，我们将 rd_bank 翻转，准备去读下一块
                            rd_bank   <= ~rd_bank; 
                            
                            en_tick   <= 0;
                            spi_state <= SPI_IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule