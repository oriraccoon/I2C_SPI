`timescale 1ns / 1ps

import spi_mode_pkg::*;

module SPI_TOP (
    // General
    input logic clock,
    input logic reset,

    // Data
    input logic       btn,
    input logic [7:0] tx_data,

    output logic [3:0] fndCom,
    output logic [7:0] fndFont,

    input logic [7:0] sw
);

    // SPI_Master
    wire       MISO;
    wire       MOSI;
    wire       SCLK;
    wire       SS;
    logic      CPOL;
    logic      CPHA;
    wire       SCLK_RisingEdge_detect;
    wire       SCLK_FallingEdge_detect;

    wire       m_done;
    wire       m_ready;

    wire       s_done;
    wire       s_ready;
    
    logic MOSI_start;
    logic MISO_start;

    spi_mode_e state;


    initial begin
        CPOL = 0;
        CPHA = 0;
    end


    SPI_Master m (
        .*,
        .start(btn),
        .rx_data(),
        .ready(m_ready),
        .done(m_done)
    );

    Segment_SPI s (
        .*,
        .S_STATE(state),
        // Data
        .start(btn),
        .done(s_done),
        .ready(s_ready)
    );
endmodule
