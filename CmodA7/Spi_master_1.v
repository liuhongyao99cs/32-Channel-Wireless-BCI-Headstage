`timescale 1ns / 1ps

module Spi_master_1 (
    input  wire clk,            // 写数据时钟
    input  wire clk_160mhz,     // SPI 发送时钟
    input  wire reset_n,
    input  wire en,
    output reg  cs,
    output reg  sclk,
    output reg  data0,
    output reg  data1, output reg data2, output reg data3,
    
    input  wire [15:0] rd_data, // 来自外部的数据输入
    input  wire rd_data_en      // 数据有效信号
);

    //==========================================================================
    // 参数计算
    //==========================================================================
    localparam PAYLOAD_WORDS = 32 * 100;           // 3200 个 16-bit 字
    localparam PAYLOAD_BYTES = PAYLOAD_WORDS * 2;  // 6400 字节
    localparam HEADER_BYTES  = 7;                  // 56 bits = 7 字节
    localparam TOTAL_BYTES   = HEADER_BYTES + PAYLOAD_BYTES; // 6407 字节

    // 协议常量
    localparam [7:0] CMD_VAL   = 8'h03;
    localparam [7:0] ADDR_VAL  = 8'h00;
    localparam [7:0] DUMMY_VAL = 8'h00;

    //==========================================================================
    // 1. 统一的大容量存储器 (BRAM)
    //    地址 0~6    : 存放 Header
    //    地址 7~End  : 存放 Payload
    //==========================================================================
    reg [7:0] frame_mem [0:TOTAL_BYTES-1];

    reg [15:0] write_addr_offset; // 仅用于 Payload 写入的偏移量计数
    reg        frame_full_flag;
    reg [31:0] spi_frame_id;      // 帧计数 ID
    reg [31:0] prev_frame_id;

    //==========================================================================
    // 2. 数据写入逻辑 (clk 域)
    //    这里不仅要存 Payload，还要在每帧开始前把 Header 刷进去
    //==========================================================================
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            write_addr_offset <= 0;
            frame_full_flag   <= 0;
            spi_frame_id      <= 0;
            // 可以在这里初始化 Header 的静态部分，或者在每次帧结束更新
            frame_mem[0]      <= CMD_VAL;
            frame_mem[1]      <= ADDR_VAL;
            frame_mem[2]      <= DUMMY_VAL;
        end else begin
            frame_full_flag <= 0; // 脉冲复位

            if (rd_data_en) begin
                // 1. 写入 Payload (注意大小端，这里假设先发高字节)
                // 如果 rd_data 是 16bit (例如 0xABCD)，我们要存成两个字节
                // 地址映射: Base(7) + offset*2
                frame_mem[HEADER_BYTES + write_addr_offset*2]     <= rd_data[15:8]; // 高字节
                frame_mem[HEADER_BYTES + write_addr_offset*2 + 1] <= rd_data[7:0];  // 低字节

                // 2. 判断是否写满一帧
                if (write_addr_offset == PAYLOAD_WORDS - 1) begin
                    write_addr_offset <= 0;
                    frame_full_flag   <= 1; // 触发发送标志
                    
                    // 3. 更新下一帧的 Header (ID 部分)
                    // 下一帧的数据即将到来，我们提前把 ID 填入 Header区域 (地址 3,4,5,6)
                    // ID 更新：spi_frame_id + 1
                    frame_mem[0]      <= CMD_VAL;
                    frame_mem[1]      <= ADDR_VAL;
                    frame_mem[2]      <= DUMMY_VAL;
                    frame_mem[3] <= (spi_frame_id + 1) >> 24;
                    frame_mem[4] <= (spi_frame_id + 1) >> 16;
                    frame_mem[5] <= (spi_frame_id + 1) >> 8;
                    frame_mem[6] <= (spi_frame_id + 1); // 低位
                    
                    spi_frame_id <= spi_frame_id + 1;
                end else begin
                    write_addr_offset <= write_addr_offset + 1;
                end
            end
            
            // 首次复位后的特殊处理：确保第一帧的 ID 是 0
            // 可以在 reset 块里做，这里为了逻辑严谨补充一下：
            // 实际应用中建议由状态机控制 Header 的装载，简化起见这里用简单的覆盖逻辑
        end
    end

    //==========================================================================
    // 3. SPI 发送逻辑 (clk_160mhz 域)
    //    逻辑极其简单：读一个字节 -> 发8位 -> 读下一个字节
    //==========================================================================
    
    // 跨时钟域握手
    reg frame_ready_sync1, frame_ready_sync2;
    always @(posedge clk_160mhz or negedge reset_n) begin
        if(!reset_n) {frame_ready_sync2, frame_ready_sync1} <= 0;
        else {frame_ready_sync2, frame_ready_sync1} <= {frame_ready_sync1, frame_full_flag};
    end

    localparam SPI_IDLE     = 2'd0;
    localparam SPI_PREP     = 2'd1;
    localparam SPI_TRANSMIT = 2'd2;
    localparam SPI_CSOFF    = 2'd3;

    reg [1:0]   state;
    reg [15:0]  tx_byte_idx; // 当前发送到第几个字节 (0 ~ 6406)
    reg [2:0]   bit_cnt;     // 当前字节发到第几位 (7 ~ 0)
    reg [7:0]   shift_byte;  // 当前正在发的字节缓存
    reg [15:0]  wait_tick;
    reg         sending_flag; // 用于防止 IDLE 期间重复触发
    reg [15:0] en_tick = 0;
    
    reg spi_en;
    always @(posedge clk or posedge reset_n)
      begin
        if (reset_n)begin
          spi_en <= 0;
        end else if (frame_full_flag) begin
          spi_en <= 1;
        end
      end
    

    always @(posedge clk_160mhz or negedge reset_n) begin
        if (!reset_n) begin
            state        <= SPI_IDLE;
            cs           <= 1'b1;
            sclk         <= 1'b0;
            data0        <= 1'b0;
            data1<=0; data2<=0; data3<=0;
            
            tx_byte_idx  <= 0;
            bit_cnt      <= 0;
            shift_byte   <= 0;
            sending_flag <= 0;
            wait_tick    <= 0;
        end else begin
          if (spi_en) begin
            case (state)
                SPI_IDLE: begin
                    cs    <= 1'b1;
                    sclk  <= 1'b0;
                    data0 <= 1'b0;

                    if (!en) begin
                        en_tick <= 0;
                    end else begin
                        if (en_tick < 160) begin
                            en_tick <= en_tick + 1;
                        end else begin
                            prev_frame_id <= spi_frame_id;
                            state <= (prev_frame_id==spi_frame_id) ? SPI_IDLE : SPI_PREP;
                             //  spi_state <= SPI_LOAD;
                        end
                    end
                end

                SPI_PREP: begin
                    cs          <= 1'b0;
                    tx_byte_idx <= 0;
                    
                    // === 预读取第一个字节 (Header[0]) ===
                    shift_byte  <= frame_mem[0]; 
                    
                    // 准备发 Bit 7
                    bit_cnt     <= 7;
                    data0       <= frame_mem[0][7]; // 提前把数据放到线上
                    
                    state       <= SPI_TRANSMIT;
                end

                SPI_TRANSMIT: begin
                    sclk <= ~sclk; // 翻转产生时钟

                    if (sclk) begin // sclk 下降沿更新数据
                        if (bit_cnt == 0) begin
                            // === 当前字节发完了 ===
                            if (tx_byte_idx == TOTAL_BYTES - 1) begin
                                // 全部字节都发完了
                                state <= SPI_CSOFF;
                            end else begin
                                // 加载下一个字节
                                tx_byte_idx <= tx_byte_idx + 1;
                                shift_byte  <= frame_mem[tx_byte_idx + 1]; // 读 RAM
                                data0       <= frame_mem[tx_byte_idx + 1][7]; // 输出 MSB
                                bit_cnt     <= 7; // 重置位计数
                            end
                        end else begin
                            // === 字节内移位 ===
                            shift_byte <= {shift_byte[6:0], 1'b0}; // 左移
                            data0      <= shift_byte[6];           // 输出下一位
                            bit_cnt    <= bit_cnt - 1;
                        end
                    end
                end

                SPI_CSOFF: begin
                    cs   <= 1'b1;
                    sclk <= 1'b0;
                    wait_tick <= wait_tick + 1;
                    if (wait_tick >= 160*5) begin // CSOFF Delay
                        wait_tick <= 0;
                        state     <= SPI_IDLE;
                    end
                end
            endcase
          end
        end
    end

endmodule