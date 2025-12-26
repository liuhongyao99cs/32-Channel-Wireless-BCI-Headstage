# 32-Channel-Wireless-BCI-Headstage
This is a 32-channel wireless headstage for BCI signal which is composed of INTAN RHD 2132, Cmod A7 FPGA controller and ESP32-S3 as radio layer.

### The repository contains necessary code and PCB files to create a wireless headstage.

### Code structure:
We implement two modules in FPGA:
1. Driver for INTAN RHD 2132 chip (We test sample rate up to 35*20K samples/s)
2. SPI interface with ESP32S3


### Physical Specifications

- **Weight:** 7.34 grams
- **Dimensions:** 23.5 x 18 x 22 mm
- **Connector:** Omnetics 2250
- **Sampling speed:** 32 channels at 30KHz (16 bits)

### Recording demo

#### How to program the headstage
1. Run verilog file in Cmod A7 fold with Vivado 2025.2 (or later version):
   ```bash
   program the bitstream file into the FPGA layer.
   
2. Run esp-idf extention in vscode to program ESP32S3:
   

3. Run Visual Studio to open recording server:

The server side should work like this: [demo video](/Images/headstage_demo.mp4)
