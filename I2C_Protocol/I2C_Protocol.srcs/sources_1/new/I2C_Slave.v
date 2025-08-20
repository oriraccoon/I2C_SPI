`timescale 1ns / 1ps

module I2C_Slave (
    // I2C ports
    inout SCL,
    inout SDA,
    output [15:0] led
);

    wire [6:0] temp_addr_data;
    wire temp_wren;
    wire [7:0] so_data;
    wire [7:0] si_data;

    assign led[7:0] = so_data;
    assign led[15:8] = si_data;

    I2C_SLAVE_REG U_I2C_REG (
        .addr(temp_addr_data),
        .wren(temp_wren),
        .so_data(so_data),
        .si_data(si_data)
    );

    I2C_Slave_Intf U_I2C_SLAVE (
        .SCL(SCL),
        .SDA(SDA),
        .temp_addr_data(temp_addr_data),
        .temp_wren(temp_wren),
        .so_data(so_data),
        .si_data(si_data)
    );

endmodule

module I2C_Slave_Intf (
    // I2C ports
    inout            SCL,
    inout            SDA,
    // external signals
    output reg [6:0] temp_addr_data,
    output reg       temp_wren,
    input      [7:0] so_data,
    output reg [7:0] si_data
);

    localparam 
        READ_ADDR = 0,
        SEND_ACK = 1,
        WRITE_DATA = 2,
        READ_DATA = 3,
        SEND_ACK2 = 4,
        READ_ACK = 5
    ;

    localparam MY_ADDR = 7'd7;

    reg [2:0] state = READ_ADDR;
    reg write_en = 0;
    reg sda_reg = 0;
    reg start = 0;
    reg temp_ack = 0;
    reg [2:0] bit_count = 7;
    reg [7:0] temp_si_data = 0;
    reg [7:0] temp_so_data = 0;
    reg [7:0] temp_aw_data = 0;

    assign SDA = (write_en) ? sda_reg : 1'bz;
    

    always @( negedge SDA ) begin
        if (~start && SCL) begin
            start <= 1;
        end
    end

    always @( posedge SDA ) begin
        if (start && SCL) begin
            start <= 0;
            bit_count <= 7;
            state <= READ_ADDR;
        end
    end

    always @( posedge SCL ) begin
        if (start) begin
            case (state)
                READ_ADDR: begin
                    temp_aw_data[bit_count] <= SDA;
                    if (bit_count == 0) begin
                        state <= SEND_ACK;
                        temp_so_data <= so_data;
                    end
                    else bit_count <= bit_count - 1;
                end
                SEND_ACK: begin
                    if (MY_ADDR == temp_aw_data[7:1]) begin
                        temp_addr_data <= 0;
                        bit_count <= 7;
                        temp_wren <= temp_aw_data[0];
                        if (temp_aw_data[0]) begin
                            state <= READ_DATA;
                            temp_si_data <= 0;
                            temp_so_data <= so_data;
                        end
                        else begin
                            state <= WRITE_DATA;
                            temp_si_data <= 0;
                            temp_so_data <= so_data;
                        end
                    end
                end
                WRITE_DATA: begin
                    temp_si_data[bit_count] <= SDA;
                    if (bit_count == 0) begin
                        state <= SEND_ACK2;
                    end
                    else bit_count <= bit_count - 1;
                end
                READ_DATA: begin
                    if (bit_count == 0) begin
                        state <= READ_ACK;
                    end
                    else begin
                        bit_count <= bit_count - 1;
                    end
                end
                SEND_ACK2: begin
                    bit_count <= 7;
                    si_data <= temp_si_data;
                    if (temp_addr_data == 6) begin
                        temp_addr_data <= 0;
                    end
                    else temp_addr_data <= temp_addr_data + 1;
                    state <= WRITE_DATA;
                end
                READ_ACK: begin
                    bit_count <= 7;
                    temp_so_data <= so_data;
                    if (temp_addr_data == 6) begin
                        temp_addr_data <= 0;
                    end
                    else temp_addr_data <= temp_addr_data + 1;
                    state <= READ_DATA;
                end
                
            endcase
        end
    end

    always @( negedge SCL ) begin
        case (state)
            READ_ADDR: begin
                write_en <= 0;
            end
            SEND_ACK: begin
                write_en <= 1;
                sda_reg <= ~(MY_ADDR == temp_aw_data[7:1]);
            end
            WRITE_DATA: begin
                write_en <= 0;
            end
            READ_DATA: begin
                write_en <= 1;
                sda_reg <= temp_so_data[bit_count];
            end
            SEND_ACK2: begin
                write_en <= 1;
                sda_reg <= 0;
            end
            READ_ACK: begin
                write_en <= 0;
            end
        endcase
    end


endmodule


module I2C_SLAVE_REG (
    input      [6:0] addr,
    input            wren,
    input      [7:0] si_data,
    output     [7:0] so_data
);

    reg [7:0] mem[0:6];

    assign so_data = mem[addr];
    
    always @(*) begin
        if (!wren) begin
            mem[addr] = si_data;
        end
    end

endmodule
