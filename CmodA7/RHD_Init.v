`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01.07.2024 20:53:22
// Design Name: 
// Module Name: RHD_Init
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

// ====================
// Rhd 2132 initialization
// ====================

module RHD_init(
    input         clk,
    input         rhd_miso,
    
    output  reg   rhd_cs,
    output        rhd_sck,
    output  reg   rhd_mosi,
    output  reg   rhd_init,

    output  reg  [15:0] rhd_data,
    output  reg   rhd_data_en,
    
    output        led 

    );
        
    // fsm state 
    reg         [7:0]   state   =   IDLE;
    parameter   IDLE = 1, Dummy1 = 2, Dummy2 = 3, Calibrate = 4;
    parameter   W0 = 5, W1 = 6, W2 = 7, W3 = 8, W4 = 9, W5 = 10, W6 = 11, W7 = 12, W8 = 13, W9 = 14, W10 = 15, W11 = 16,
                W12 = 17, W13 = 18, W14 = 19, W15 = 20, W16 = 21, W17 = 22, WAIT = 23, W0_ACK = 24, Calibrate_WAIT = 25, INIT_END = 26, CONVERT = 27;
                
                
    parameter   cycle = 35, IDLE_MAX = 100, WAIT_MAX = 3000;                  
       
    // ========== command list =============== //
    // CONVERT (C): 00 + C5-C0 + 0000000H   ;   RESULT: A[15]-A[0]
    // CALIBRATE : 0101010100000000
    // CLEAR :     0110101000000000
    // WRITE ( R, D ) : 10 + R[5]-R[0] + D[7]-D[0]
    // READ  ( R    ) : 11 + R[5]-R[0] + 00000000
    
    // WRITE REG COMMAND
    parameter   WRITE_0 = 16'h80de,     WRITE_1 = 16'h8142,     WRITE_2 = 16'h8204,     WRITE_3 = 16'h8300;
    parameter   WRITE_4 = 16'h849c,     WRITE_5 = 16'h8540,     WRITE_6 = 16'h8680,     WRITE_7 = 16'h8700;
    parameter   WRITE_8 = 16'h8816,     WRITE_9 = 16'h8940,     WRITE_10 = 16'h8a80,    WRITE_11 = 16'h8b00;
    parameter   WRITE_12 = 16'h8c2c,    WRITE_13 = 16'h8d86,    WRITE_14 = 16'h8eff,    WRITE_15 = 16'h8fff;
    parameter   WRITE_16 = 16'h90ff,    WRITE_17 = 16'h91ff;
    // CALIBRATE
    parameter   Calib = 16'h5500;
    // Dummy 
    parameter   READ_63 = 16'he900;

    // ===== init ======= //
    reg     [7:0]       cnt_idle = 0;
    reg     [15:0]      cnt_wait = 0;
    reg     [7:0]       cnt_cmd_bit = 0;
    reg     [7:0]       cnt_ack_bit = 0;    
    reg     [3:0]       cnt_command = 0;
    reg     [15:0]      rhd_ack;
    reg                 tmp_cs;

    // ==== SAMPLE ===== //
    reg         [5:0]       cnt_command_C = 0;
    reg         [15:0]      cnt_cmd_bit_C = 0;
    reg         [15:0]      cnt_idle_C = 0;
    reg         [15:0]      CMD_C = 16'h0000;


    
    initial rhd_cs = 1;
    assign  rhd_sck = clk && (~tmp_cs);
    
    // FSM
    always@(posedge clk)
        case ( state )
            IDLE            :   state   <=   ( cnt_idle == IDLE_MAX ) ?  Dummy1  :   IDLE;
            Dummy1          :   state   <=   ( cnt_command == 2     ) ?  W0      :   Dummy1; 
            W0              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W1    :   W0;
            W1              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W2    :   W1;
            W2              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W3    :   W2;
            W3              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W4    :   W3;
            W4              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W5    :   W4;
            W5              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W6    :   W5;
            W6              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W7    :   W6;
            W7              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W8    :   W7;
            W8              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W9    :   W8;
            W9              :   state   <=   ( cnt_cmd_bit == cycle ) ?  W10    :   W9;
            W10             :   state   <=   ( cnt_cmd_bit == cycle ) ?  W11    :   W10;
            W11             :   state   <=   ( cnt_cmd_bit == cycle ) ?  W12    :   W11;
            W12             :   state   <=   ( cnt_cmd_bit == cycle ) ?  W13    :   W12;
            W13             :   state   <=   ( cnt_cmd_bit == cycle ) ?  W14    :   W13;
            W14             :   state   <=   ( cnt_cmd_bit == cycle ) ?  W15    :   W14;
            W15             :   state   <=   ( cnt_cmd_bit == cycle ) ?  W16    :   W15;
            W16             :   state   <=   ( cnt_cmd_bit == cycle ) ?  W17    :   W16;
            W17             :   state   <=   ( cnt_cmd_bit == cycle ) ?  Calibrate_WAIT     :   W17;
            Calibrate_WAIT  :   state   <=   ( cnt_wait == WAIT_MAX ) ?  Calibrate :   Calibrate_WAIT;
            Calibrate       :   state   <=   ( cnt_cmd_bit == cycle ) ?  Dummy2        :   Calibrate;
            //WAIT            :   state   <=   ( cnt_cmd_bit == cycle ) ?  W0_ACK  :   WAIT;
            Dummy2          :   state   <=   ( cnt_command == 9     ) ?  INIT_END        :   Dummy2;
            INIT_END        :   state   <=   ( rhd_ack == 16'd78    ) ?  CONVERT    :   IDLE;
        endcase
    
    // logic in each state
    always@(posedge clk)
        case (state)
            IDLE:
                if ( cnt_idle < IDLE_MAX ) begin
                    cnt_idle <= cnt_idle + 1;
                    rhd_cs <= 1;
                    tmp_cs <= 1;
                end else begin
                    rhd_cs <= 0;
                end
                
            Dummy1:
                if ( cnt_command < 2 ) begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                            cnt_command <= cnt_command + 1;
                        end else
                            begin
                                rhd_mosi <= READ_63[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
                 end else 
                    cnt_command <= 0;
                    
             W0:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_0[15 - cnt_cmd_bit];
                                rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            WAIT:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                        cnt_cmd_bit <= cnt_cmd_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                    end else if ( cnt_cmd_bit == cycle ) begin
                        cnt_cmd_bit <= 1'b0;
                        rhd_cs <= 0;
                    end else
                        begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs      <= 1'b0;
                            tmp_cs      <= 1'b0;
                        end
                        
            Calibrate_WAIT:
                if ( cnt_wait < WAIT_MAX ) begin
                    cnt_wait <= cnt_wait + 1;
                end else
                    cnt_wait <= 0;
                        
            W0_ACK:
                if ( cnt_ack_bit >= 8'd16 && cnt_ack_bit < cycle) begin
                        cnt_ack_bit <= cnt_ack_bit + 1;
                        rhd_cs <= 1;
                        tmp_cs <= 1;
                    end else if ( cnt_ack_bit == cycle ) begin
                        cnt_ack_bit <= 8'd0;
                        rhd_cs <= 0;
                    end else
                        begin
                            rhd_ack  <= {rhd_ack[14:0],rhd_miso};
                            rhd_cs   <= 1'b0;
                            tmp_cs <= 0;
                            cnt_ack_bit <= cnt_ack_bit + 1;
                        end 
                        
            W1:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_1[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W2:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_2[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W3:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_3[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end                
            W4:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_4[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W5:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_5[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W6:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_6[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W7:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_7[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W8:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_8[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W9:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_9[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W10:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_10[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W11:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_11[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W12:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_12[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W13:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_13[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W14:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_14[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W15:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_15[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W16:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_16[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            W17:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= WRITE_17[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
            Calibrate:
                if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                        end else
                            begin
                                rhd_mosi <= Calib[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
        
            Dummy2:
                if ( cnt_command < 9 ) begin
                    if ( cnt_cmd_bit >= 8'd16 && cnt_cmd_bit < cycle ) begin
                            cnt_cmd_bit <= cnt_cmd_bit + 1;
                            rhd_cs <= 1;
                            tmp_cs <= 1;
                        end else if (cnt_cmd_bit == cycle ) begin
                            cnt_cmd_bit <= 8'd0;
                            rhd_cs <= 0;
                            cnt_command <= cnt_command + 1;
                        end else
                            begin
                                rhd_mosi <= READ_63[15 - cnt_cmd_bit];
                                rhd_cs   <= 1'b0;
                                tmp_cs   <= 1'b0;
                                cnt_cmd_bit <= cnt_cmd_bit + 1;
                            end
                 end else 
                    cnt_command <= 0;
            
            

            CONVERT:
                if ( cnt_command_C < 35 ) begin  
                        CMD_C <= {2'b00,cnt_command_C,8'b00000000}; 
                        if ( cnt_cmd_bit_C >= 8'd16 && cnt_cmd_bit_C < cycle ) begin
                                cnt_cmd_bit_C <= cnt_cmd_bit_C + 1;
                                rhd_cs <= 1;
                                tmp_cs <= 1;
                            end else if (cnt_cmd_bit_C == cycle ) begin
                                cnt_cmd_bit_C <= 8'd0;
                                rhd_cs <= 0;
                                cnt_command_C <= cnt_command_C + 1;
                            end else
                                begin
                                    rhd_mosi <= CMD_C[15 - cnt_cmd_bit];
                                    rhd_cs   <= 1'b0;
                                    tmp_cs   <= 1'b0;
                                    cnt_cmd_bit_C <= cnt_cmd_bit_C + 1;
                                end                                    // three dummy commands
                 end else begin
                    cnt_command_C <= 0;
                    CMD_C <= 0;
                 end
                
        endcase

        // read data from adc
        always@(posedge rhd_sck) begin
            case ( state )
                CONVERT:
                    if ( cnt_command_C < 34 && cnt_command_C > 1 ) begin  
                        rhd_data <= {rhd_data[14:0],rhd_miso};                                       
                    end 
            endcase
            
        end
        
        always@(posedge clk) begin
            case ( state )
                CONVERT:
                    if ( cnt_command_C < 34 && cnt_command_C > 1 ) begin  
                        if ( cnt_cmd_bit_C == 16 )
                            rhd_data_en <= 1;
                        else
                            rhd_data_en <= 0;
                    end 
            endcase
            
        end

        
        //assign rhd_init = ( (state == INIT_END)) ? 1'b1 : 1'b0;
        always@(posedge clk)begin
            if ( state == INIT_END && rhd_ack == 16'd78)
                rhd_init <= 1;
        end
        assign led = ( state == CONVERT ) ? 1'b1:1'b0;

endmodule