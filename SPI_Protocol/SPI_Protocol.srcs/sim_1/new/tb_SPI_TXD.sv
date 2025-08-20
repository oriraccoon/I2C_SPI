`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/05/16 15:54:00
// Design Name: 
// Module Name: tb_SPI_TXD
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

import spi_mode_pkg::*;

module tb_SPI_TXD ();
    // General
    logic clock;
    logic reset;

    // SPI
    logic MISO;
    wire MOSI;
    wire SCLK;
    wire SS;
    logic CPOL;
    logic CPHA;

    // Data
    logic       start;
    logic [7:0] tx_data;
    wire [7:0] rx_data;
    wire       done;
    wire       ready;
    
    wire SCLK_RisingEdge_detect;
    wire SCLK_FallingEdge_detect;
    // internal
    spi_mode_e state;

SPI_Master dut(
.*
);

always #5 clock = ~clock;

initial begin
    clock = 0; reset = 1; MISO = 0; CPOL = 0; CPHA = 0; start = 0; tx_data = 0;
    #10 reset = 0;
    #10 start = 1; tx_data = 8'b10010011;
    #10 start = 0;
    @(posedge done);
    @(posedge clock);
    @(posedge clock);
    @(posedge clock);
    $finish;

end


endmodule
