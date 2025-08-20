`timescale 1ns / 1ps



module tb_SPI_Slave();
    // General
    logic clock;
    logic reset;

    // SPI_Slave
    logic SCLK;
    logic MOSI;
    logic SS;
    wire MISO;

    // Data
    logic       start;
    wire       done;
    wire       ready;

    // internal
    logic SCLK_RisingEdge_detect;
    logic SCLK_FallingEdge_detect;
    wire [7:0] data;

SPI_Slave dut(
.*,
.S_STATE(SMODE0)
);

always #5 begin
    clock = ~clock;
end

always @(negedge clock) SCLK = ~SCLK;
always @(posedge SCLK) SCLK_RisingEdge_detect = ~SCLK_RisingEdge_detect;
always @(negedge SCLK) SCLK_FallingEdge_detect = ~SCLK_FallingEdge_detect;

initial begin
    clock = 0; reset = 1; SCLK = 0; SS = 1; MOSI = 0; start = 0;
    SCLK_RisingEdge_detect = 0;
    SCLK_FallingEdge_detect = 0;
    #10 reset = 0;
    #10 start = 1; SS = 0;
    
    @(posedge SCLK_RisingEdge_detect);
    start = 0; MOSI = 1;
    @(posedge SCLK_RisingEdge_detect);
    MOSI = 1;
    @(posedge SCLK_RisingEdge_detect);
    MOSI = 0;
    @(posedge SCLK_RisingEdge_detect);
    MOSI = 0;
    @(posedge SCLK_RisingEdge_detect);
    MOSI = 0;
    @(posedge SCLK_RisingEdge_detect);
    MOSI = 1;
    @(posedge SCLK_RisingEdge_detect);
    MOSI = 0;
    @(posedge SCLK_RisingEdge_detect);
    MOSI = 1;
    @(posedge done);
    SS = 1;
    @(posedge clock);
    @(posedge clock);
    @(posedge clock);
    $finish;
    
end


endmodule
