`timescale 1ns / 1ps

import spi_mode_pkg::*;

module Segment_SPI (
    // General
    input logic clock,
    input logic reset,

    // SPI_Slave
    input logic SCLK,
    input logic MOSI,
    input logic SS,
    output logic MISO,
    input spi_mode_e S_STATE,

    // Data
    input  logic start,
    input logic MOSI_start,
    output logic done,
    output logic ready,
    output logic MISO_start,

    // internal
    input logic SCLK_RisingEdge_detect,
    input logic SCLK_FallingEdge_detect,

    output logic [3:0] fndCom,
    output logic [7:0] fndFont,
    input logic [7:0] sw
);

    logic [7:0] o_data;
    logic [7:0] i_data;

    logic tx_done;
    assign i_data = sw;

    SPI_Slave SPI_S (.*);

    FndController seg_IP (
        .*,
        .fcr(1'b1),
        .fdr({6'b0, o_data}),
        .fpr(4'b0)
    );

endmodule


module SPI_Slave (
    // General
    input logic clock,
    input logic reset,

    // SPI_Slave
    input logic SCLK,
    input logic MOSI,
    input logic SS,
    output logic MISO,
    input spi_mode_e S_STATE,

    // Data
    input  logic start,
    input logic MOSI_start,
    output logic done,
    output logic tx_done,
    output logic ready,
    output logic MISO_start,

    // internal
    input logic SCLK_RisingEdge_detect,
    input logic SCLK_FallingEdge_detect,
    output logic [7:0] o_data,
    input logic [7:0] i_data
);

    typedef enum { IDLE, ADDR_PHASE, WRITE_PHASE, READ_PHASE } state_e;

    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;
    logic [31:0] slv_reg0_next, slv_reg1_next, slv_reg2_next, slv_reg3_next;
    state_e state, state_next;
    logic [1:0] addr, addr_next;
    logic rx_start, rx_start_next;
    logic o_data_next;

    always_ff @( posedge clock or posedge reset ) begin
        if (reset) begin
            state <= IDLE;
            addr <= 2'bx;
            rx_start <= 0;
            o_data <= 0;
            slv_reg0 <= 32'bx;
            slv_reg1 <= 32'bx;
            slv_reg2 <= 32'bx;
            slv_reg3 <= 32'bx;
        end
        else begin
            state <= state_next;
            addr <= addr_next;
            rx_start <= rx_start_next;
            o_data <= o_data_next;
            slv_reg0 <= slv_reg0_next;
            slv_reg1 <= slv_reg1_next;
            slv_reg2 <= slv_reg2_next;
            slv_reg3 <= slv_reg3_next;
        end
    end

    always_comb begin
        state_next = state;
        addr_next = addr;
        rx_start_next = 0;
        o_data_next = o_data;
        slv_reg0_next = slv_reg0;
        slv_reg1_next = slv_reg1;
        slv_reg2_next = slv_reg2;
        slv_reg3_next = slv_reg3;
        case (state)
            IDLE: begin
                if (!SS) begin
                    state_next = ADDR_PHASE;
                end
            end
            ADDR_PHASE: begin
                if (!SS) begin
                    if (done) begin
                        addr_next = i_data[1:0];
                        if (i_data[7]) begin
                            state_next = WRITE_PHASE;
                        end
                        else begin
                            state_next = READ_PHASE;
                        end
                        
                    end
                end
                
            end
            WRITE_PHASE: begin
                if (!SS) begin
                    if (done) begin
                        case (addr)
                            2'd0: slv_reg0_next = i_data;
                            2'd1: slv_reg1_next = i_data;
                            2'd2: slv_reg2_next = i_data;
                            2'd3: slv_reg3_next = i_data;
                        endcase
                        if (addr == 2'd3) begin
                            addr_next = 0;
                        end
                        else begin
                            addr_next = addr + 1;
                        end
                    end
                end
                else begin
                    state_next = IDLE;
                end
            end
            READ_PHASE: begin
                if (!SS) begin
                    rx_start_next = 1'b1;
                    case (addr)
                        2'd0: o_data_next = slv_reg0[7:0];
                        2'd1: o_data_next = slv_reg1[7:0];
                        2'd2: o_data_next = slv_reg2[7:0];
                        2'd3: o_data_next = slv_reg3[7:0];
                    endcase
                    if (tx_done) begin
                        if (addr == 2'd3) begin
                            addr_next = 0;
                        end
                        else begin
                            addr_next = addr + 1;
                        end
                    end

                end
                else begin
                    state_next = IDLE;
                end
                
            end
        endcase
    end

    SPI_Slave_Transceiver U_SPI_Transceiver (
        .*,
        .start(!SS),
        .rx_data(o_data),
        .tx_data(i_data)
    );


endmodule

module SPI_Slave_Transceiver (
    input logic       clock,
    input logic       reset,
    input logic       SCLK,
    input logic       MOSI,
    input logic [7:0] tx_data,
    input logic       SS,
    input logic       start,
    input logic       rx_start,
    input spi_mode_e  S_STATE,
    input logic       SCLK_RisingEdge_detect,
    input logic       SCLK_FallingEdge_detect,
    input logic MOSI_start,
    output logic MISO_start,

    output logic       MISO,
    output logic       done,
    output logic       tx_done,
    output logic       ready,
    output logic [7:0] rx_data
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
    logic [7:0] rx_data_reg;
    logic [7:0] temp_tx_data_reg, temp_tx_data_next;
    logic [7:0] temp_rx_data_reg, temp_rx_data_next;
    logic [2:0] tx_bit_count_reg, tx_bit_count_next;
    logic [2:0] rx_bit_count_reg, rx_bit_count_next;
    logic MISO_temp;

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
            MISO <= (SS) ? 1'bz : MISO_temp;
        end
    end

    always_comb begin : S_MISO_block
        tx_state_next = tx_state;
        tx_done = 1'b0;
        ready = 1'b1;
        MISO_start = 1'b0;
        tx_bit_count_next = tx_bit_count_reg;
        temp_tx_data_next = temp_tx_data_reg;
        MISO_temp = MISO;
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
                    MISO_start = 1'b1;
                    MISO_temp = temp_tx_data_reg[7];
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


    always_comb begin : S_MOSI_block
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
                if (MOSI_start) begin
                    rx_state_next = START;
                end
            end
            START: begin
                if (rx_sclk_edge) begin
                    temp_rx_data_next = temp_rx_data_next[6:0] << 1;
                    temp_rx_data_next[0] = MOSI;
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

module FndController (
    input logic clock,
    input logic reset,
    input logic fcr,
    input logic [13:0] fdr,
    input logic [3:0] fpr,
    output logic [3:0] fndCom,
    output logic [7:0] fndFont
);

    logic o_clk;
    logic [3:0] digit1000, digit100, digit10, digit1;
    logic [27:0] blink_data;

    parameter LEFT = 16_000, RIGHT = 16_001, BOTH = 16_002;

    clock_divider #(
        .FCOUNT(100_000)
    ) U_1khz (
        .clk  (clock),
        .rst  (reset),
        .o_clk(o_clk)
    );

    digit_spliter U_digit_Spliter (
        .bcd(fdr),
        .digit1000(digit1000),
        .digit100(digit100),
        .digit10(digit10),
        .digit1(digit1)
    );

    function [6:0] bcd2seg(input [3:0] bcd);
        begin
            case (bcd)
                4'h0: bcd2seg = 7'h40;
                4'h1: bcd2seg = 7'h79;
                4'h2: bcd2seg = 7'h24;
                4'h3: bcd2seg = 7'h30;
                4'h4: bcd2seg = 7'h19;
                4'h5: bcd2seg = 7'h12;
                4'h6: bcd2seg = 7'h02;
                4'h7: bcd2seg = 7'h78;
                4'h8: bcd2seg = 7'h00;
                4'h9: bcd2seg = 7'h10;
                default: bcd2seg = 7'h7F;
            endcase
        end
    endfunction

    function [27:0] blink(input [13:0] bcd);
        begin
            case (bcd)
                LEFT: blink = {7'b0000110, 7'h3F, 7'h7F, 7'h7F};
                RIGHT: blink = {7'h7F, 7'h7F, 7'h3F, 7'b0110000};
                BOTH: blink = {7'b0000110, 7'h3F, 7'h3F, 7'b0110000};
                default: blink = {7'h7F, 7'h7F, 7'h7F, 7'h7F};
            endcase
        end
    endfunction

    always_ff @(posedge o_clk or posedge reset) begin
        if (reset) begin
            fndCom  = 4'b1110;
            fndFont = 8'hC0;
        end else begin
            if ((fdr < 10000) && fcr) begin
                case (fndCom)
                    4'b0111: begin
                        fndCom  <= 4'b1110;
                        fndFont <= {~fpr[0], bcd2seg(digit1)};
                    end
                    4'b1110: begin
                        fndCom  <= 4'b1101;
                        fndFont <= {~fpr[1], bcd2seg(digit10)};
                    end
                    4'b1101: begin
                        fndCom  <= 4'b1011;
                        fndFont <= {~fpr[2], bcd2seg(digit100)};
                    end
                    4'b1011: begin
                        fndCom  <= 4'b0111;
                        fndFont <= {~fpr[3], bcd2seg(digit1000)};
                    end
                    default: begin
                        fndCom  <= 4'b1110;
                        fndFont <= 8'hC0;
                    end
                endcase
            end else if ((fdr >= 10000) && fcr) begin
                blink_data = blink(fdr);
                case (fndCom)
                    4'b0111: begin
                        fndCom  <= 4'b1110;
                        fndFont <= {1'b1, blink_data[6:0]};
                    end
                    4'b1110: begin
                        fndCom  <= 4'b1101;
                        fndFont <= {1'b1, blink_data[13:7]};
                    end
                    4'b1101: begin
                        fndCom  <= 4'b1011;
                        fndFont <= {1'b1, blink_data[20:14]};
                    end
                    4'b1011: begin
                        fndCom  <= 4'b0111;
                        fndFont <= {1'b1, blink_data[27:21]};
                    end
                    default: begin
                        fndCom  <= 4'b1110;
                        fndFont <= 8'hC0;
                    end
                endcase
            end else if (!fcr) begin
                fndCom  <= 4'b1111;
                fndFont <= 8'hFF;
            end
        end
    end

endmodule

module clock_divider #(
    parameter FCOUNT = 100_000
) (
    input  logic clk,
    input  logic rst,
    output logic o_clk
);
    logic [$clog2(FCOUNT)-1:0] count;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
            o_clk <= 0;
        end else begin
            if (count == FCOUNT - 1) begin
                o_clk <= 1;
                count <= 0;
            end else begin
                count <= count + 1;
                o_clk <= 0;
            end
        end
    end
endmodule


module digit_spliter #(
    parameter WIDTH = 14
) (
    input [WIDTH-1:0] bcd,
    output [3:0] digit1000,
    output [3:0] digit100,
    output [3:0] digit10,
    output [3:0] digit1
);

    assign digit1 = (bcd % 10);
    assign digit10 = (bcd % 100) / 10;
    assign digit100 = (bcd % 1000) / 100;
    assign digit1000 = bcd / 1000;

endmodule

