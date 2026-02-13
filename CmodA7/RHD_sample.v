`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.07.2024 22:05:53
// Design Name: 
// Module Name: RHD_sample
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


module RHD_sample(
    input       sysclk,
    input       ADC_EN, 
    input       reset_n,
    input       rhd_miso,
    
    output  reg   rhd_cs,
    output  wire  rhd_sck,
    output  reg   rhd_mosi,
    
    output  reg   [15:0]      rhd_data,
    output  reg   rhd_data_en,
    
    output        led1
    
    );
    
  parameter IDLE = 0, CONVERT = 1, cycle = 40;
  reg [3:0] state = IDLE;
  reg [5:0] cnt_command = 0;
  reg [11:0] cnt_cmd_bit = 0;
  reg [15:0] CMD = 16'h0000;

  assign rhd_sck = sysclk && (~rhd_cs);
  assign led1 = (rhd_data > 0) ? 1'b1 : 1'b0;

  // State machine
  always @(posedge sysclk or posedge reset_n)
  begin
    if (reset_n)
    begin
      state <= IDLE;
      rhd_cs <= 1;
    end
    else
    begin
      case (state)
        IDLE:
          state <= (ADC_EN) ? CONVERT : IDLE;
        CONVERT:
          state <= (ADC_EN) ? CONVERT : IDLE;
      endcase
    end
  end

  // SPI command and data handling
  always @(posedge sysclk or posedge reset_n)
  begin
    if (reset_n)
    begin
      rhd_cs <= 1;
      rhd_mosi <= 0;
      cnt_command <= 0;
      cnt_cmd_bit <= 0;
      CMD <= 16'h0000;
    end
    else
    begin
      case (state)
        IDLE:
        begin
          rhd_cs <= 1;
          cnt_command <= 0;
          cnt_cmd_bit <= 0;
        end
        CONVERT:
        begin
          if (cnt_command < 35)
          begin
            //CMD <= {2'b00, cnt_command, 8'b00000000};
            CMD <= 16'he900;
            if (cnt_cmd_bit >= 16 && cnt_cmd_bit < cycle)
            begin
              cnt_cmd_bit <= cnt_cmd_bit + 1;
              rhd_cs <= 1;
            end
            else if (cnt_cmd_bit == cycle)
            begin
              cnt_cmd_bit <= 0;
              rhd_cs <= 0;
              cnt_command <= cnt_command + 1;
            end
            else
            begin
              rhd_mosi <= CMD[15 - cnt_cmd_bit];
              rhd_cs <= 0;
              cnt_cmd_bit <= cnt_cmd_bit + 1;
            end
          end
          else
          begin
            cnt_command <= 0;
            CMD <= 0;
          end
        end
      endcase
    end
  end

  // Data read
  always @(posedge rhd_sck)
  begin
    if (state == CONVERT && cnt_command > 1 && cnt_command < 34)
    begin
      rhd_data <= {rhd_data[14:0], rhd_miso};
    end
  end

  // Data enable
  always @(posedge sysclk)
  begin
    rhd_data_en <= (state == CONVERT && cnt_command > 1 && cnt_command < 34 && cnt_cmd_bit == 16) ? 1 : 0;
  end
endmodule
