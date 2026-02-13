module RHD (
    input CLK_16mhz,
    input reset_n,
    input rhd_miso,
    output rhd_mosi,
    output rhd_cs,
    output rhd_sck,
    output [15:0] rd_data,
    output rd_data_en,
    output rhd_init,
    output led
  );
  wire init_mosi, init_cs, init_sck;
  wire sample_mosi, sample_cs, sample_sck;

  // Multiplex SPI signals based on rhd_init
  assign rhd_mosi = rhd_init ? sample_mosi : init_mosi;
  assign rhd_cs = rhd_init ? sample_cs : init_cs;
  assign rhd_sck = rhd_init ? sample_sck : init_sck;

  RHD_init RHD_init_inst (
             .clk(CLK_16mhz),
             //.reset_n(reset_n),
             .rhd_miso(rhd_miso),
             .rhd_mosi(init_mosi),
             .rhd_cs(init_cs),
             .rhd_sck(init_sck),
             .rhd_init(rhd_init),
             .led(led)
           );

  RHD_sample RHD_sample_inst (
               .sysclk(CLK_16mhz),
               .reset_n(reset_n),
               .ADC_EN(rhd_init),
               .rhd_miso(rhd_miso),
               .rhd_mosi(sample_mosi),
               .rhd_cs(sample_cs),
               .rhd_sck(sample_sck),
               .rhd_data(rd_data),
               .rhd_data_en(rd_data_en)
             );

endmodule
