`timescale 1ns / 1ps

module RHD_Driver #(
    // System Clock Frequency: 50MHz
    parameter CLK_FREQ = 50_000_000, 
    
    // SPI SCLK Divider
    // Formula: SCLK = CLK_FREQ / (2 * (SPI_DIV + 1))
    // Example: Div=1 => 50M / 4 = 12.5 MHz (Ideal speed for RHD2132)
    parameter SPI_DIV  = 1,
    
    // Target Sampling Rate (Samples per second per channel)
    // At 50MHz system clock, 15kS/s is stable and easily achievable.
    parameter TARGET_FS = 15_000 
)(
    input  wire         clk,        // 50MHz System Clock
    input  wire         rst_n,      // Active Low Reset
    input  wire         enable,     // High to start operation
    
    // SPI Interface (To RHD2132 Chip)
    output reg          cs_n,       // Chip Select (Active Low)
    output reg          sclk,       // SPI Serial Clock
    output reg          mosi,       // Master Out Slave In
    input  wire         miso,       // Master In Slave Out
    
    // User Output Interface
    output reg          data_valid, // Data Valid Pulse (High for 1 cycle)
    output reg [5:0]    channel_id, // Channel ID: 0-31 (Neural), 32-34 (Aux 1-3)
    output reg [15:0]   adc_data,   // 16-bit ADC Sample Data
    output reg          busy        // Busy Flag (1 = Driver is running)
);

    // =========================================================================
    // 1. Parameters and Constants Definition
    // =========================================================================
    // Sequence Length: 32 Amplifier Channels + 3 Aux Commands = 35
    localparam SEQ_LENGTH = 35; 
    
    // Sampling Rate Pacing Calculation
    // Total Throughput = TARGET_FS * 35
    // Example: 50M / (15000 * 35) approx 95 clock cycles
    localparam [31:0] PACING_CYCLES = CLK_FREQ / (TARGET_FS * SEQ_LENGTH);
    
    // 100us Wait Counter (Required by Datasheet Page 19 after Config)
    // Calculation: 50M * 100us = 5000 clock cycles
    localparam [31:0] WAIT_100US_CYCLES = CLK_FREQ / 10000; 

    // SPI Command Definitions
    localparam CMD_CONVERT = 2'b00;
    localparam CMD_CALIB   = 2'b01; 
    localparam CMD_WRITE   = 2'b10;
    localparam CMD_READ    = 2'b11;

    // =========================================================================
    // 2. State Machine Definition
    // =========================================================================
    localparam S_IDLE        = 0;
    localparam S_DUMMY_START = 1; // Power-on Dummy Read
    localparam S_PREPARE     = 2; // Decide/Prepare Next Command
    localparam S_WAIT_100US  = 3; // Wait after Initialization
    localparam S_SPI_START   = 4; // Drive CS Low
    localparam S_SPI_TRANS   = 5; // SPI Bit Transmission
    localparam S_SPI_DONE    = 6; // Drive CS High & Process Pipeline
    localparam S_PACE_WAIT   = 7; // Wait for Pacing Trigger (Sample Rate Control)

    reg [3:0]  state;
    reg [2:0]  seq_stage; // 0:Init, 1:Wait100us, 2:Calib, 3:WaitCalib, 4:Sample
    
    // Internal Counters
    reg [4:0]  init_idx;       // Index for Initialization ROM (0-17)
    reg [1:0]  dummy_cnt;      // Counter for Dummy Reads
    reg [3:0]  calib_wait_cnt; // Counter for Calibration Wait (9 cycles)
    reg [31:0] wait_timer;     // General purpose timer (for 100us wait)
    reg [31:0] pace_cnt;       // Pacing counter for sampling rate control

    // SPI Data Registers
    reg [15:0] tx_shift, rx_shift;
    reg [15:0] cmd_next;       // Command to be sent in the next cycle
    reg [7:0]  clk_div_cnt;    // SPI Clock Divider Counter
    reg [4:0]  bit_cnt;        // Bit Counter (15 down to 0)
    
    // Channel & Pipeline Management
    reg [5:0]  curr_ch;        // Channel currently being prepared (0-34)
    reg [5:0]  pipe_ch_0;      // Channel just sent (Pipeline Stage 1)
    reg [5:0]  pipe_ch_1;      // Channel with result returning (Pipeline Stage 2 / Output)
    reg        pipe_v_0, pipe_v_1; // Pipeline Valid Flags

    // =========================================================================
    // 3. Initialization ROM Configuration (18 Registers)
    // =========================================================================
    reg [15:0] init_rom [0:17];
    initial begin
        // RHD2132 Recommended Configuration (Wideband Example)
        // NOTE: For specific bandwidths (e.g., 1Hz-5kHz), use the official Intan 
        // Bandwidth Configurator software to calculate values for Reg 4, 5, and 7.
        init_rom[0]  = {CMD_WRITE, 6'd0,  8'b11011110}; // Reg 0: ADC Config
        init_rom[1]  = {CMD_WRITE, 6'd1,  8'b00100000}; // Reg 1: ADC Bias
        init_rom[2]  = {CMD_WRITE, 6'd2,  8'd40};       // Reg 2: MUX Bias
        init_rom[3]  = {CMD_WRITE, 6'd3,  8'd2};        // Reg 3: MUX Load
        init_rom[4]  = {CMD_WRITE, 6'd4,  8'd22};       // Reg 4: ADC/Low Cutoff
        init_rom[5]  = {CMD_WRITE, 6'd5,  8'd26};       // Reg 5: Low Cutoff
        init_rom[6]  = {CMD_WRITE, 6'd6,  8'd0};        // Reg 6: DAC
        init_rom[7]  = {CMD_WRITE, 6'd7,  8'd0};        // Reg 7: High Cutoff
        init_rom[8]  = {CMD_WRITE, 6'd8,  8'd0};        // Reg 8: Aux Enable
        init_rom[9]  = {CMD_WRITE, 6'd9,  8'd0};        // Reg 9: Aux 
        init_rom[10] = {CMD_WRITE, 6'd10, 8'd0}; 
        init_rom[11] = {CMD_WRITE, 6'd11, 8'd0}; 
        init_rom[12] = {CMD_WRITE, 6'd12, 8'd0}; 
        init_rom[13] = {CMD_WRITE, 6'd13, 8'd0}; 
        init_rom[14] = {CMD_WRITE, 6'd14, 8'hFF};       // Power Up Ch 0-7
        init_rom[15] = {CMD_WRITE, 6'd15, 8'hFF};       // Power Up Ch 8-15
        init_rom[16] = {CMD_WRITE, 6'd16, 8'hFF};       // Power Up Ch 16-23
        init_rom[17] = {CMD_WRITE, 6'd17, 8'hFF};       // Power Up Ch 24-31
    end
    
    // Auxiliary Command Definitions: Read Aux Input 1, 2, 3
    // Aux Input 1 maps to Ch 32, Aux 2 to Ch 33, Aux 3 to Ch 34
    wire [15:0] aux_cmd_1 = {CMD_CONVERT, 6'd32, 8'h00};
    wire [15:0] aux_cmd_2 = {CMD_CONVERT, 6'd33, 8'h00};
    wire [15:0] aux_cmd_3 = {CMD_CONVERT, 6'd34, 8'h00};

    // =========================================================================
    // 4. Main Logic Implementation
    // =========================================================================
    
    // --- Sample Rate Pacing Counter ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pace_cnt <= 0;
        else if (enable && busy) begin
            if (state == S_PACE_WAIT) begin
                 // Reset counter when target cycle count is reached
                 if (pace_cnt >= PACING_CYCLES) pace_cnt <= 0; 
                 else pace_cnt <= pace_cnt + 1;
            end else begin
                 // Keep counting in other states to maintain time continuity
                 if (pace_cnt < PACING_CYCLES) pace_cnt <= pace_cnt + 1;
            end
        end else begin
            pace_cnt <= 0;
        end
    end

    // --- Main State Machine ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            cs_n <= 1; sclk <= 0; mosi <= 0;
            busy <= 0; data_valid <= 0;
            init_idx <= 0; seq_stage <= 0;
            curr_ch <= 0; 
            dummy_cnt <= 0;
            pipe_v_0 <= 0; pipe_v_1 <= 0;
            pipe_ch_0 <= 0; pipe_ch_1 <= 0;
            adc_data <= 0; channel_id <= 0;
        end else begin
            // Default pulse reset
            data_valid <= 0;
            
            case (state)
                // ----------------------------------------------------
                S_IDLE: begin
                    cs_n <= 1;
                    if (enable) begin
                        busy <= 1;
                        state <= S_DUMMY_START;
                        dummy_cnt <= 0;
                    end
                end

                // ----------------------------------------------------
                // Stage A: Send 2 Dummy Reads to Wake up SPI (Recommended by Datasheet)
                S_DUMMY_START: begin
                    cmd_next <= {CMD_READ, 6'd63, 8'h00}; // Read ID Command
                    pipe_v_0 <= 0; // Result from dummy read is discarded
                    state <= S_SPI_START;
                    
                    if (dummy_cnt < 2) dummy_cnt <= dummy_cnt + 1;
                    else begin
                        state <= S_PREPARE;
                        seq_stage <= 0; // Enter Initialization Stage
                        init_idx <= 0;
                    end
                end

                // ----------------------------------------------------
                // Stage B: Decision Layer (Prepare Next Command)
                S_PREPARE: begin
                    cs_n <= 1;
                    case (seq_stage)
                        // 0: Send Initialization Registers
                        0: begin 
                            cmd_next <= init_rom[init_idx];
                            pipe_v_0 <= 0;
                            state <= S_SPI_START;
                        end
                        
                        // 1: Wait 100us (Mandatory per Datasheet)
                        1: begin
                            wait_timer <= 0;
                            state <= S_WAIT_100US;
                        end

                        // 2: Send Calibration Command (Calibrate ADC)
                        2: begin
                            cmd_next <= 16'h5500; 
                            pipe_v_0 <= 0;
                            state <= S_SPI_START;
                        end

                        // 3: Wait after Calibration (9 cycles)
                        3: begin
                            cmd_next <= {CMD_READ, 6'd63, 8'h00}; // Send Dummy to toggle clock
                            pipe_v_0 <= 0;
                            state <= S_SPI_START;
                        end

                        // 4: Normal Sampling Loop (35 Commands)
                        4: begin
                            if (curr_ch < 32) begin
                                // 0-31: Neural Amplifier Channels
                                cmd_next <= {CMD_CONVERT, curr_ch, 8'h00};
                            end else begin
                                // 32-34: Auxiliary Commands
                                case (curr_ch)
                                    32: cmd_next <= aux_cmd_1;
                                    33: cmd_next <= aux_cmd_2;
                                    34: cmd_next <= aux_cmd_3;
                                    default: cmd_next <= aux_cmd_1;
                                endcase
                            end
                            
                            pipe_v_0 <= 1;        // This command produces valid data
                            state <= S_PACE_WAIT; // Wait for Pacing trigger (Ensure 15kS/s)
                        end
                    endcase
                end

                // ----------------------------------------------------
                // 100us Delay State
                S_WAIT_100US: begin
                    if (wait_timer >= WAIT_100US_CYCLES) begin
                        seq_stage <= 2; // Proceed to Calibration
                        state <= S_PREPARE;
                    end else begin
                        wait_timer <= wait_timer + 1;
                    end
                end

                // ----------------------------------------------------
                // Sampling Rate Pacing Wait
                S_PACE_WAIT: begin
                    // Wait until pacing counter matches target cycle count
                    if (pace_cnt >= PACING_CYCLES) begin
                        state <= S_SPI_START;
                    end
                end

                // ----------------------------------------------------
                // SPI Physical Layer - Start
                S_SPI_START: begin
                    cs_n     <= 0;
                    tx_shift <= cmd_next;
                    mosi     <= cmd_next[15]; // MSB First
                    bit_cnt  <= 15;
                    clk_div_cnt <= 0;
                    sclk     <= 0;
                    state    <= S_SPI_TRANS;
                end

                // ----------------------------------------------------
                // SPI Physical Layer - Transmit
                S_SPI_TRANS: begin
                    if (clk_div_cnt < SPI_DIV) begin
                        clk_div_cnt <= clk_div_cnt + 1;
                    end else begin
                        clk_div_cnt <= 0;
                        sclk <= ~sclk; // Toggle SCLK

                        if (sclk == 0) begin // Rising Edge (0->1): Host Samples MISO
                            rx_shift[bit_cnt] <= miso;
                        end else begin // Falling Edge (1->0): Host Shifts MOSI
                            if (bit_cnt == 0) begin
                                sclk <= 0; 
                                state <= S_SPI_DONE;
                            end else begin
                                bit_cnt <= bit_cnt - 1;
                                mosi <= tx_shift[bit_cnt - 1];
                            end
                        end
                    end
                end

                // ----------------------------------------------------
                // SPI Physical Layer - Done & Pipeline Logic
                S_SPI_DONE: begin
                    cs_n <= 1; // CS Must go High
                    
                    // --- Pipeline Shift ---
                    // Intan RHD2132 data latency is 2 command cycles.
                    pipe_ch_1 <= pipe_ch_0;
                    pipe_v_1  <= pipe_v_0;
                    
                    pipe_ch_0 <= curr_ch;
                    // pipe_v_0 was set in the PREPARE stage

                    // --- Data Output ---
                    // Only output data during Sampling stage AND if the pipeline is valid
                    if (seq_stage == 4 && pipe_v_1) begin
                        data_valid <= 1;
                        adc_data   <= rx_shift;
                        // channel_id corresponds to the source of the current rx_shift data
                        channel_id <= pipe_ch_1; 
                    end

                    // --- Sequence Control Logic ---
                    case (seq_stage)
                        0: begin // Init Loop
                            if (init_idx < 17) begin
                                init_idx <= init_idx + 1;
                                state <= S_PREPARE;
                            end else begin
                                seq_stage <= 1; // -> Go to Wait 100us
                                state <= S_PREPARE;
                            end
                        end
                        
                        // Stage 1 (Wait) is handled in S_WAIT_100US
                        
                        2: begin // Calibrate Sent
                            seq_stage <= 3; // -> Go to Wait 9 cycles
                            calib_wait_cnt <= 0;
                            state <= S_PREPARE;
                        end
                        
                        3: begin // Calib Wait Loop
                            if (calib_wait_cnt < 9) begin
                                calib_wait_cnt <= calib_wait_cnt + 1;
                                state <= S_PREPARE;
                            end else begin
                                seq_stage <= 4; // -> Start Sampling
                                curr_ch <= 0;
                                pace_cnt <= 0;
                                state <= S_PREPARE;
                            end
                        end
                        
                        4: begin // Sampling Loop (0..34)
                            if (curr_ch >= SEQ_LENGTH - 1) 
                                curr_ch <= 0;
                            else 
                                curr_ch <= curr_ch + 1;
                            
                            state <= S_PREPARE;
                        end
                    endcase
                end
            endcase
        end
    end

endmodule