`timescale 1ns / 1ps

module tb_master;

    // General
    logic clk;
    logic reset;

    // I2C signals
    tri SCL;
    tri SDA;

    // Control & data signals
    logic [7:0] tx_data;
    wire [7:0] rx_data;
    logic [6:0] addr;
    logic start;
    logic stop;
    logic wren;
    // wire tx_done;
    // wire ready;
    wire [15:0] led;

    I2C_Master dut (
        .clk(clk),
        .reset(reset),
        .SCL(SCL),
        .SDA(SDA),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .addr(addr),
        .wren(wren),
        .start(start),
        .stop(stop)
        // .tx_done(tx_done),
        // .ready(ready)
    );

    I2C_Slave dut_s (.*);

    always #5 clk = ~clk;

    initial begin
        clk     = 0;
        reset   = 1;
        tx_data = 8'hA5;
        addr    = 7'h07;
        wren    = 0;
        start   = 0;
        stop    = 0;
        #10 reset = 0;

        #5000 start = 1;
        #10 start = 0;
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD); 
        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD); 
        tx_data = 8'hA6;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hA7;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hA8;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hA9;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hAa;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hAb;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hAc;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hAd;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hAe;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hAf;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hb7;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hc7;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        tx_data = 8'hd7;

        wait (dut.state == dut.WRITE_DATA);
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);

        #10 stop = 1;
        #10 stop = 0;

        #100000;
        $display("[TB] I2C Master write Finished");

        wait (dut.state == dut.IDLE); #10 start = 1; wren = 1;
        #10 start = 0;
        wait (dut.state == dut.READ_ACK);
        wait (dut.state == dut.HOLD);
        wait (dut.state == dut.READ_DATA);
        wait (dut.state == dut.WRITE_ACK); 
        wait (dut.state == dut.HOLD); 
        wait (dut.state == dut.READ_DATA);
        wait (dut.state == dut.WRITE_ACK); 
        wait (dut.state == dut.HOLD); 
        wait (dut.state == dut.READ_DATA);
        wait (dut.state == dut.WRITE_ACK); 
        wait (dut.state == dut.HOLD); 
        wait (dut.state == dut.READ_DATA);
        wait (dut.state == dut.WRITE_ACK); 
        wait (dut.state == dut.HOLD); 
        wait (dut.state == dut.READ_DATA);
        wait (dut.state == dut.WRITE_ACK); 
        wait (dut.state == dut.HOLD); 
        wait (dut.state == dut.READ_DATA);
        wait (dut.state == dut.WRITE_ACK); 
        wait (dut.state == dut.HOLD); 
        
        #10 stop <= 1; #10 stop <= 0;

        #100;

        $display("[TB] I2C Master read Finished");


        #10000;

        $stop;
    end

endmodule
