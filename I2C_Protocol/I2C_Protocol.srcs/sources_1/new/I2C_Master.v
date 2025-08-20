`timescale 1ns / 1ps

module I2C_Master (
    // General signals
    input        clk,
    input        reset,
    // I2C ports
    inout        SCL,
    inout       SDA,
    // external signals
    input  [7:0] tx_data,
    output reg [7:0] rx_data,
    input  [6:0] addr,
 

    input        wren,          // 쓰기 모드 or 읽기 모드?
    input        start,         // I2C 통신 시작 IDLE -> START
    input        stop,          // I2C 통신 정지 ? -> IDLE
    output [3:0] o_state
    // output       tx_done,   
    // output       ready
);

    localparam
        IDLE = 0,
        START = 1,
        ADDR_READ = 2,
        READ_ACK = 3,
        WRITE_DATA = 4,
        READ_DATA = 5,
        HOLD = 7,
        WRITE_ACK = 8,
        LOW = 9
    ;


    reg [3:0] state, next_state;
    reg [$clog2(250)-1:0] clk_count;
    reg i2c_clk;
    reg st;
    reg sta;
    reg [1:0] count, count_next;
    reg [3:0] bit_count, bit_count_next;
    reg [7:0] temp_tx_data, temp_tx_data_next;
    reg [7:0] temp_rx_data, temp_rx_data_next;
    reg [6:0] temp_addr_data, temp_addr_data_next;
    reg temp_wren, temp_wren_next;
    reg write_en, write_en_next;
    reg scl_en, scl_en_next;
    reg scl_reg = 1, scl_reg_next = 1;
    reg sda_reg = 1, sda_reg_next = 1;
    reg temp_ack, temp_ack_next;

    assign SDA = (write_en) ? (~sda_reg) ? 1'b0 : 1'b1 : 1'bz;
    assign SCL = (scl_en) ? (~scl_reg) ? 1'b0 : 1'b1 : 1'bz;
    assign o_state = state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            i2c_clk <= 0;
            clk_count <= 0;
            st <= 0;
        end else begin
            if (clk_count == 249) begin
                i2c_clk <= ~i2c_clk;
                clk_count = 0;
            end else begin
                clk_count = clk_count + 1;
            end

            if (stop) begin
                st <= 1;
            end
            if (start) begin
                sta <= 1;
            end
            
            if (state == IDLE) st <= 0;
            else if (state == WRITE_ACK) begin
                rx_data <= temp_rx_data;
            end
            else sta <= 0;

        end
    end

    always @(posedge i2c_clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            scl_reg <= 1;
            sda_reg <= 1;
            count <= 0;
            bit_count <= 0;
            temp_tx_data <= 0;
            temp_addr_data <= 0;
            temp_rx_data <= 0;
            temp_wren <= 0;
            write_en <= 1;
            scl_en <= 1;
            temp_ack <= 0;
        end
        else begin
            state <= next_state;
            scl_reg <= scl_reg_next;
            sda_reg <= sda_reg_next;
            count <= count_next;
            bit_count <= bit_count_next;
            temp_tx_data <= temp_tx_data_next;
            temp_addr_data <= temp_addr_data_next;
            temp_rx_data <= temp_rx_data_next;
            temp_wren <= temp_wren_next;
            write_en <= write_en_next;
            scl_en <= scl_en_next;
            temp_ack <= temp_ack_next;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (sta)
                    next_state = START;
            end
            START: begin
                if (count == 3)
                    next_state = ADDR_READ;
            end
            ADDR_READ: begin
                if (count == 3 && bit_count == 7)
                    next_state = READ_ACK;
            end
            READ_ACK: begin
                if (count == 3)
                    next_state = temp_ack ? IDLE : HOLD;
            end
            WRITE_DATA: begin
                if (count == 3 && bit_count == 7)
                    next_state = READ_ACK;
            end
            HOLD: begin
                if (count == 3)
                    next_state = st ? IDLE : LOW;
            end
            LOW: begin
                if (count == 3)
                    next_state = temp_wren ? READ_DATA : WRITE_DATA;
            end
            READ_DATA: begin
                if (count == 3 && bit_count == 7)
                    next_state = WRITE_ACK;
            end
            WRITE_ACK: begin
                if (count == 3)
                    next_state = HOLD;
            end
        endcase
    end

    always @(*) begin
        scl_reg_next       = scl_reg;
        sda_reg_next       = sda_reg;
        count_next         = count;
        bit_count_next     = bit_count;
        temp_tx_data_next  = temp_tx_data;
        temp_addr_data_next= temp_addr_data;
        temp_rx_data_next  = temp_rx_data;
        temp_wren_next     = temp_wren;
        write_en_next      = write_en;
        scl_en_next = scl_en;
        temp_ack_next = temp_ack;
        case (state)
            IDLE: begin
                sda_reg_next = 1'b1;
                scl_reg_next = 1'b1;
                if (sta) begin 
                    sda_reg_next = 1'b0;
                end
            end

            START: begin
                sda_reg_next = 0;
                scl_reg_next = 0;
                count_next = count + 1;
                if (count == 3) begin
                    temp_addr_data_next = addr;
                    temp_wren_next = wren;
                    count_next = 0;
                    bit_count_next = 0;
                    // sda_reg_next = (bit_count == 7) ? temp_wren : temp_addr_data[6];
                end
            end

            ADDR_READ: begin
                count_next = count + 1;
                if (count == 0)
                    scl_reg_next = 1;
                else if (count == 2) begin
                    scl_reg_next = 0;
                    temp_addr_data_next = {temp_addr_data[5:0], 1'b0};
                end
                else if (count == 3) begin
                    sda_reg_next = (bit_count == 6) ? temp_wren : temp_addr_data[6];
                    bit_count_next = (bit_count == 7) ? 0 : bit_count + 1;
                    // if (bit_count == 7) begin
                    //     write_en_next = 0;
                    // end
                end
            end

            READ_ACK: begin
                temp_ack_next = SDA;
                write_en_next = 0;
                count_next = count + 1;
                if (count == 0)
                    scl_reg_next = 1;
                else if (count == 2)
                    scl_reg_next = 0;
                else if (count == 3) begin
                    write_en_next = 1;
                end
            end

            WRITE_DATA: begin
                count_next = count + 1;
                if (count == 0)
                    scl_reg_next = 1;
                else if (count == 2) begin
                    scl_reg_next = 0;
                    temp_tx_data_next = {temp_tx_data[6:0], 1'b0};
                end
                else if (count == 3) begin
                    bit_count_next = (bit_count == 7) ? 0 : bit_count + 1;
                    if (bit_count == 7) begin
                        write_en_next = 0;
                    end
                end
                sda_reg_next = temp_tx_data[7];
            end

            HOLD: begin
                write_en_next = 1;
                sda_reg_next = 1;
                scl_reg_next = 0;
                count_next = count + 1;
                if (count == 3) begin
                    if (st) scl_reg_next = 1;
                    sda_reg_next = 0;
                end
            end

            LOW: begin
                sda_reg_next = 0;
                scl_reg_next = 0;
                count_next = count + 1;
                if (count == 3) begin
                    if (!temp_wren) begin
                        temp_tx_data_next = tx_data;
                        sda_reg_next = tx_data[7];
                    end
                    write_en_next = temp_wren ? 0 : 1;
                end
            end

            READ_DATA: begin
                write_en_next = 0;
                count_next = count + 1;
                if (count == 0)
                    scl_reg_next = 1;
                else if (count == 2) begin
                    scl_reg_next = 0;
                    temp_rx_data_next = {temp_rx_data[6:0], SDA};
                end
                else if (count == 3) begin
                    bit_count_next = (bit_count == 7) ? 0 : bit_count + 1;
                    if (bit_count == 7) begin
                        write_en_next = 1;
                    end
                end
            end

            WRITE_ACK: begin
                write_en_next = 1;
                count_next = count + 1;
                sda_reg_next = 0;
                if (count == 0)
                    scl_reg_next = 1;
                else if (count == 2)
                    scl_reg_next = 0;
            end
        endcase
    end


endmodule