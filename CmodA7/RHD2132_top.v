`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.06.2024 20:32:44
// Design Name: 
// Module Name: RHD2132_top
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

`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////

// Company: 

// Engineer: 

// 

// Create Date: 22.06.2024 20:32:44

// Design Name: 

// Module Name: RHD2132_top

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

module RHD2132_top(
    input    sysclk,
    input    reset_n,
    input    rhd_miso,    

    output  reg   rhd_cs,
    output        rhd_sck,
    output  reg   rhd_mosi,
    
    // for esp spi communication port
    
    input  wire ESP32_EN,
    output wire ESP32_CS,
    output wire ESP32_SCLK,
    output wire ESP32_DATA0,
    output wire ESP32_DATA1,
    output wire ESP32_DATA2,
    output wire ESP32_DATA3,

    output  led,
    output  led1    
);

    wire clk25;

    clk_wiz_0   clk_wiz_inst1(

    .clk_in1       ( sysclk    ),

    .clk_out1      ( clk25     ),
    
    .clk_out2      ( clk80     )

    );
    
    
    parameter     MSG_REG0_WRITE  = 16'b10000000_11011110; 
                   
    parameter     MSG_REG1_WRITE  = 16'b10000001_00000100;       // ADC Buffer bias 4
    parameter     MSG_REG2_WRITE  = 16'b10000010_00010010;       // MUX bias 18
    
    // parameter     MSG_REG1_WRITE  = 16'b10000001_00000011; 
    // parameter     MSG_REG2_WRITE  = 16'b10000010_00000111;
    
    parameter     MSG_REG3_WRITE  = 16'b10000011_00000000;       
    parameter     MSG_REG4_WRITE  = 16'b10000100_10000000;       // DSP cut-off -> 8
    
    parameter     MSG_REG5_WRITE  = 16'b10000101_00000000;
    parameter     MSG_REG6_WRITE  = 16'b10000110_10000000;
    parameter     MSG_REG7_WRITE  = 16'b10000111_00000000;
    
    parameter     MSG_REG8_WRITE  = 16'b10001000_00010110;       // RH1 DAC1 17
    parameter     MSG_REG9_WRITE  = 16'b10001001_10000000; 
      
    parameter     MSG_REG10_WRITE  = 16'b10001010_00010111;
    parameter     MSG_REG11_WRITE  = 16'b10001011_10000000;
    parameter     MSG_REG12_WRITE  = 16'b10001100_00101100;
    parameter     MSG_REG13_WRITE  = 16'b10001100_10000110; 
    
    parameter     MSG_REG14_WRITE  = 16'b10001010_11111111;
    parameter     MSG_REG15_WRITE  = 16'b10001011_11111111;
    parameter     MSG_REG16_WRITE  = 16'b10001100_11111111;
    parameter     MSG_REG17_WRITE  = 16'b10001100_11111111;
    
    parameter     MSG_CARLIB   =   16'b01010101_00000000;     
    
    parameter     MSG_REG63_READ = 16'b1110101000000000;        // read command: {11 + 5bit: reg id + 00000000}


    initial rhd_cs = 1;
    assign rhd_sck = clk25 && (~tmp_cs);
    
    reg     [15:0]      CONVERT_CMD;
    
    reg     [5:0]       cnt_command;
    reg     [7:0]       state = IDLE;    
    reg     [7:0]       cnt_ack_bit = 0;
    reg     [7:0]       cnt_cmd_bit = 0;
    reg     [7:0]       cnt_wat_bit = 0;
    reg     [31:0]      cnt_idl_bit = 0;

    reg     tmp_cs;

    reg     [15:0]      rhd_ack = 16'hffff;

    parameter     WAIT_MAX       = 32'd1;

    parameter     IDLE = 8'd0,   R0 = 8'd1,  W0 = 8'd2, W1 = 8'd3, W2 = 8'd4, W3 = 8'd5, W4 = 8'd6, W5 = 8'd7, W6 = 8'd8, W7 = 8'd9, W8 = 8'd10, W9 = 8'd11;
    parameter     W10 = 8'd12, W11 = 8'd13, W12 = 8'd14, W13 = 8'd15, W14 = 8'd16, W15 = 8'd17, W16 = 8'd18, W17 = 8'd19;
    parameter     CARLIB = 8'd20, CARLIB_DUMMY = 8'd21, INIT_FINISH = 8'd22, CONVERT = 8'd23;
    
    parameter     cycle = 8'd27;     // 15KHz
    


    /*
    always@(posedge clk25 or posedge reset_n)

    begin

      if (reset_n) begin

        state <= IDLE;

      end

        case (state)

            IDLE        :   state       <=      (   cnt_idl_bit == WAIT_MAX     ) ?   REG0_W     :   IDLE  ;

            REG0_W      :   state       <=      (   cnt_cmd_bit == cycle        ) ?   WAIT       :   REG0_W;

            WAIT        :   state       <=      (   cnt_wat_bit == cycle        ) ?   REG0_ACK   :   WAIT;

            REG0_ACK    :   state       <=      (   cnt_ack_bit == cycle        ) ?   IDLE  :   REG0_ACK;

            REG_CHECK   :   state       <=                                            IDLE;

        endcase

    end
    */
        

    reg flag, flag1;
    reg rd_data_en;

    reg [31:0] cnt;

    

    always@(posedge clk25 or posedge reset_n)

    begin

        if (reset_n)

        begin
          state <= IDLE;
          cnt_command <= 0;
          cnt <= 0;
          tmp_cs <= 1;
          rhd_cs <= 1;
          rhd_mosi <= 0;
          cnt_cmd_bit <= 0;
          cnt_wat_bit <= 0;
          cnt_ack_bit <= 0;
          flag <=0;
          flag1 <= 0;
          rhd_ack <= 0;
          cnt_idl_bit <= 0;
          rd_data_en <= 0;
        end

    else
        begin

        case (state)

            IDLE:

                if ( cnt_idl_bit < WAIT_MAX ) begin
                    rd_data_en <= 0;
                    cnt_idl_bit <= cnt_idl_bit + 1;
                    rhd_cs <= 1;
                    tmp_cs <= 1;
                end else begin
                    rd_data_en <= 0;
                    rhd_ack <= 0;
                    cnt_idl_bit <=0;
                    rhd_cs <= 0;
                    state <= R0;
                end

            R0:
                begin
                
                if ( cnt_wat_bit < 2 ) begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if (cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        cnt_wat_bit <= cnt_wat_bit + 1;
                        rhd_cs <= 0;
                    end else
                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG63_READ[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs   <= 1'b0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end
               end else begin
                    cnt_wat_bit <= 0;
                    state <= W0;
               end
               
               end
                

            W0:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if (cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W1;
                        if (rhd_ack == 16'h0054) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else
                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG0_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs   <= 1'b0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end
                end    

             W1:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W2;
                        if (rhd_ack == 16'h0054) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG1_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             W2:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W3;
                        if (rhd_ack == 16'hffde) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG2_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end   
                
            W3:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W4;
                        // if (rhd_ack == 16'hff03) begin
                        if (rhd_ack == 16'hff04) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else
                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG3_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end   
                
             W4:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W5;
                        if (rhd_ack == 16'hff12) begin
                        //if (rhd_ack == 16'hff07) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG4_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
            W5:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W6;
                        if (rhd_ack == 16'hff00) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG5_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end  
                
             W6:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W7;
                        if (rhd_ack == 16'hff80) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG6_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             W7:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W8;
                        if (rhd_ack == 16'hff00) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG7_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             W8:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W9;
                        if (rhd_ack == 16'hff80) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG8_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             W9:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W10;
                        if (rhd_ack == 16'hff00) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG9_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
             
             W10:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W11;
                        if (rhd_ack == 16'hff16) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG10_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end

             W11:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W12;
                        if (rhd_ack == 16'hff80) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG11_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             W12:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W13;
                        if (rhd_ack == 16'hff17) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG12_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             W13:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W14;
                        if (rhd_ack == 16'hff80) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG13_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             W14:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W15;
                        if (rhd_ack == 16'hff2c) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG14_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             W15:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W16;
                        if (rhd_ack == 16'hff86) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG15_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
             
             W16:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= W17;
                        if (rhd_ack == 16'hffff) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG16_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
            W17:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= CARLIB;
                        if (rhd_ack == 16'hffff) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_REG17_WRITE[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             CARLIB:
                begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                        rd_data_en <= 0;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 8'd0;
                        rhd_cs <= 0;
                        state <= CARLIB_DUMMY;
                        if (rhd_ack == 16'hffff) begin
                            flag <= 0;
                        end else 
                            flag <= 1;
                    end else

                        begin
                            rd_data_en <= 0;
                            rhd_mosi <= MSG_CARLIB[15 - cnt_cmd_bit];
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end

                end
                
             CARLIB_DUMMY:
                begin
                    if ( cnt_wat_bit < 9 ) begin
                        if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                            rd_data_en <= 0;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            cnt_wat_bit <= cnt_wat_bit + 1;
                            rhd_cs <= 0;
                        end else
                            begin
                                rd_data_en <= 0;
                                rhd_mosi <= MSG_REG63_READ[15 - cnt_cmd_bit];
                                rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
                   end else begin
                        cnt_wat_bit <= 0;
                        state <= CONVERT;
                   end
                   
                end
                
             CONVERT:
                begin
                
                    if ( cnt_wat_bit < 35 ) begin
                        CONVERT_CMD = {2'b00, cnt_wat_bit[5:0], 8'b00000000};
                        if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                            rd_data_en <= 0;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            cnt_wat_bit <= cnt_wat_bit + 1;
                            rhd_cs <= 0;
                            if ( cnt_wat_bit > 1 && cnt_wat_bit < 34) begin
                                rd_data_en <= 1;
                                /*
                                if (rhd_ack == 16'h0054) begin
                                    flag1 <= 0;
                                end else 
                                    flag1 <= 1;
                                */
                            end
                        end else
                            begin
                                rd_data_en <= 0;
                                rhd_mosi <= CONVERT_CMD[15 - cnt_cmd_bit];//MSG_REG63_READ[15 - cnt_cmd_bit];
                                rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
                   end else begin
                        cnt_wat_bit <= 0;
                        rd_data_en <= 0;
                   end
                /*
                    if (cnt_command < 6'd35)
                      begin
                        //CMD <= {2'b00, cnt_command, 8'b00000000};
                        // CMD <= MSG_REG64_READ;
                        if (cnt_cmd_bit >= 16 && cnt_cmd_bit < cycle)
                        begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                            rd_data_en <= 0;
                        end
                        else if (cnt_cmd_bit == cycle)
                        begin
                          cnt_cmd_bit <= 0;
                          rhd_cs <= 0;
                          cnt_command <= cnt_command + 1;
                          rd_data_en  <= 1;
                        end
                        else
                        begin
                          rd_data_en <= 0;
                          rhd_mosi <= MSG_REG63_READ[15 - cnt_cmd_bit];
                          rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                          rhd_cs <= 0;
                          cnt_cmd_bit <= cnt_cmd_bit + 1;
                        end
                      end
                  else
                      begin
                        cnt_cmd_bit <= 0;
                        rd_data_en <= 0;
                        cnt_command <= 0;
                        state <= CONVERT;
                      end
                  */
                   end
        endcase               

       end

 end
 

assign led = ( flag ) ? 1'b1 : 1'b0;
wire [15:0] rd_data;
assign rd_data = ( rd_data_en ) ? rhd_ack : rd_data;

// sync en signal from 16 MHz to 80 Mhz
reg en_d1;
reg en_d2;
reg en_d3;
always @(posedge clk80 or posedge reset_n) begin
        if (reset_n) begin
            en_d1 <= 1'b0;
            en_d2 <= 1'b0;
            en_d3 <= 1'b0;
        end
        else begin
            en_d1 <= rd_data_en;  // 第一拍：可能出现亚稳态
            en_d2 <= en_d1;    // 第二拍：数据稳定 (此时已同步到 clk_fast)
            en_d3 <= en_d2;    // 保存上一个周期的状态
        end
    end

    assign rd_data_en_80 = en_d2 & (~en_d3);


reg [31:0] rd_cnt;
always @(posedge clk80 or posedge reset_n) begin
    if (reset_n) begin
        rd_cnt <= 0;
    end else begin
        if ( rd_data_en_80 == 1 ) begin
            rd_cnt <= rd_cnt + 1;
        end
    end
end

assign led1 = ( flag1 ) ? 1 : 0;  //(rd_cnt > 32'd1_200_000) ? 1'b1 : 1'b0;
            
// ******* SPI interface ********* //
Spi_master spi(

.clk                    (clk                    ),
.clk_160mhz             (clk80                 ),
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
.rd_data_en             (rd_data_en_80          )

//.frame                  (spi_frame              ),
//.spi_frame_id           (spi_f_cnt              ) 

); 

endmodule
