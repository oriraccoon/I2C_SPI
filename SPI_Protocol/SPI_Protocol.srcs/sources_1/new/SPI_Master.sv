`timescale 1ns / 1ps

import spi_mode_pkg::*;

module SPI_Master (
    // General
    input logic clock,
    input logic reset,

    // SPI_Master
    input  logic MISO,
    output logic MOSI,
    output logic SCLK,
    output logic SS,
    input  logic CPOL,
    input  logic CPHA,

    // Data
    input  logic            start,
    input  logic      [7:0] tx_data,
    output logic      [7:0] rx_data,
    output logic            done
    // output logic            ready,
    // output spi_mode_e       state,

    // internal
    // output logic SCLK_RisingEdge_detect,
    // output logic SCLK_FallingEdge_detect
);

    logic prev_SCLK;
    logic cpol0sclk, cpol1sclk;
    logic o_clk;
    logic tx_done;


    spi_mode_e       state;
    wire ready, SCLK_RisingEdge_detect, SCLK_FallingEdge_detect, MOSI_start;

    clock_div #(
        .FCOUNT(5)
    ) c (
        .*,
        .start(!SS)
    );

    spi_mode_e state_next;

    assign SCLK_RisingEdge_detect  = (SCLK && ~prev_SCLK) ? 1'b1 : 1'b0;
    assign SCLK_FallingEdge_detect = (!SCLK && prev_SCLK) ? 1'b1 : 1'b0;


    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            SS <= 1'b1;
        end else begin
            state <= state_next;
            prev_SCLK <= SCLK;
            if (start) begin
                SS <= 1'b0;
            end else if (tx_done) begin
                SS <= 1'b1;
            end
        end
    end

    always_ff @(posedge o_clk or posedge reset or posedge done) begin
        if (reset || done) begin
            cpol0sclk <= 1'b0;
            cpol1sclk <= 1'b1;
        end 
        else begin
            cpol0sclk <= ~cpol0sclk;  // 1/2 clock
            cpol1sclk <= ~cpol1sclk;
        end
    end

    always_comb begin
        state_next = state;
        SCLK = 1'b0;
        case (state)
            IDLE: begin
                SCLK = 1'b0;
                case ({
                    CPHA, CPOL
                })
                    2'b00: state_next = SMODE0;
                    2'b01: state_next = SMODE1;
                    2'b10: state_next = SMODE2;
                    2'b11: state_next = SMODE3;
                endcase
            end
            SMODE0: begin
                // rising : rx data, falling : tx data
                SCLK = cpol0sclk;
                if ({CPHA, CPOL} != 2'b00) begin
                    state_next = IDLE;
                end

            end
            SMODE1: begin
                // rising : tx data, falling : rx data
                SCLK = cpol1sclk;
                if ({CPHA, CPOL} != 2'b01) begin
                    state_next = IDLE;
                end
            end
            SMODE2: begin
                // rising : tx data, falling : rx data
                SCLK = cpol0sclk;
                if ({CPHA, CPOL} != 2'b10) begin
                    state_next = IDLE;
                end
            end
            SMODE3: begin
                // rising : rx data, falling : tx data
                SCLK = cpol1sclk;
                if ({CPHA, CPOL} != 2'b11) begin
                    state_next = IDLE;
                end
            end
        endcase
    end

    SPI_Master_Transceiver U_SPI_Transceiver (
        .*,
        .S_STATE(state),
        .start  (!SS)
    );

endmodule

module SPI_Master_Transceiver (
    input logic       clock,
    input logic       reset,
    input logic       SCLK,
    input logic       MISO,
    input logic [7:0] tx_data,
    input logic       SS,
    input logic       start,
    input spi_mode_e  S_STATE,
    input logic       SCLK_RisingEdge_detect,
    input logic       SCLK_FallingEdge_detect,

    output logic       MOSI,
    output logic       done,
    output logic       tx_done,
    output logic       ready,
    output logic [7:0] rx_data,
    output logic MOSI_start
);

    typedef enum {
        IDLE,
        WAIT,
        START,
        DONE
    } state_e;
    
    state_e tx_state, tx_state_next;
    state_e rx_state, rx_state_next;

    logic tx_sclk_edge;
    logic rx_sclk_edge;
    logic [7:0] temp_tx_data_reg, temp_tx_data_next;
    logic [7:0] temp_rx_data_reg, temp_rx_data_next;
    logic [7:0] rx_data_reg;
    logic [2:0] tx_bit_count_reg, tx_bit_count_next;
    logic [2:0] rx_bit_count_reg, rx_bit_count_next;
    logic MOSI_temp;

    always_comb begin
        case (S_STATE)
            SMODE0, SMODE3: begin
                tx_sclk_edge = SCLK_FallingEdge_detect;
                rx_sclk_edge = SCLK_RisingEdge_detect;
            end
            SMODE1, SMODE2: begin
                tx_sclk_edge = SCLK_RisingEdge_detect;
                rx_sclk_edge = SCLK_FallingEdge_detect;
            end
            default: begin
                tx_sclk_edge = 0;
                rx_sclk_edge = 0;
            end
        endcase
    end

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            tx_state <= IDLE;
            rx_state <= IDLE;
            tx_bit_count_reg <= 0;
            rx_bit_count_reg <= 0;
            temp_tx_data_reg <= 0;
            temp_rx_data_reg <= 0;
            rx_data <= 0;
        end else begin
            tx_state <= tx_state_next;
            rx_state <= rx_state_next;
            tx_bit_count_reg <= tx_bit_count_next;
            rx_bit_count_reg <= rx_bit_count_next;
            temp_tx_data_reg <= temp_tx_data_next;
            temp_rx_data_reg <= temp_rx_data_next;
            rx_data <= rx_data_reg;
            MOSI <= (SS) ? 1'bz : MOSI_temp;
        end
    end

    always_comb begin : M_MOSI_block
        tx_state_next = tx_state;
        tx_done = 1'b0;
        ready = 1'b1;
        MOSI_start = 1'b0;
        tx_bit_count_next = tx_bit_count_reg;
        temp_tx_data_next = temp_tx_data_reg;
        MOSI_temp = MOSI;
        case (tx_state)
            IDLE: begin
                if (start) begin
                    if ( (S_STATE == SMODE2) || (S_STATE == SMODE3) ) begin
                        tx_state_next = WAIT;
                    end
                    tx_state_next = START;
                    ready = 1'b0;
                    temp_tx_data_next = tx_data;
                    tx_bit_count_next = 0;
                end
            end
            WAIT: begin
                if (tx_bit_count_reg == 5) begin
                    tx_state_next = START;
                    tx_bit_count_next = 0;
                end
                else begin
                    tx_bit_count_next = tx_bit_count_reg + 1;
                end
            end
            START: begin
                ready = 1'b0;
                if (tx_sclk_edge) begin
                    MOSI_start = 1'b1;
                    MOSI_temp = temp_tx_data_reg[7];
                    temp_tx_data_next = {temp_tx_data_reg[6:0], 1'b0};
                    if (tx_bit_count_reg == 7) begin
                        tx_state_next = DONE;
                        tx_bit_count_next = 0;
                    end else begin
                        tx_bit_count_next = tx_bit_count_next + 1;
                    end
                end
            end
            DONE: begin
                ready = 1'b0;
                tx_done = 1'b1;
                tx_state_next = IDLE;
            end
        endcase
    end


    always_comb begin : M_MISO_block
        rx_state_next = rx_state;
        done = 1'b0;
        temp_rx_data_next = temp_rx_data_reg;
        rx_bit_count_next = rx_bit_count_reg;
        rx_data_reg = rx_data;
        case (rx_state)
            IDLE: begin
                if (start) begin
                    rx_state_next = WAIT;
                    temp_rx_data_next = 8'b0;
                    rx_bit_count_next = 0;
                end
            end
            WAIT: begin
                if (start) begin
                    rx_state_next = START;
                end
            end
            START: begin
                if (rx_sclk_edge) begin
                    temp_rx_data_next = temp_rx_data_next[6:0] << 1;
                    temp_rx_data_next[0] = MISO;
                    if (rx_bit_count_reg == 7) begin
                        rx_state_next = DONE;
                        rx_bit_count_next = 0;
                    end else begin
                        rx_bit_count_next = rx_bit_count_next + 1;
                    end
                end
            end
            DONE: begin
                done = 1'b1;
                rx_data_reg = temp_rx_data_reg;
                rx_state_next = IDLE;
            end
        endcase
    end

endmodule

module demux1x4 (
    input logic SS,
    input logic [1:0] Ctrl,
    output logic [3:0] y
);



endmodule

module clock_div #(
    parameter FCOUNT = 2
) (
    input  logic clock,
    input  logic reset,
    input  logic start,
    output logic o_clk
);

    logic [$clog2(FCOUNT)-1:0] count;

    always_ff @(posedge clock or posedge reset) begin
        if (reset) begin
            count <= 0;
            o_clk <= 0;
        end else begin
            if (start) begin
                if (count == (FCOUNT >> 1)) begin
                    o_clk <= ~o_clk;
                    count <= 0;
                end else begin
                    count <= count + 1;
                end
            end
            else begin
                o_clk <= 0;
            end
        end
    end

endmodule
