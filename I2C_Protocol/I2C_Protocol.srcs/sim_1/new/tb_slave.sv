`timescale 1ns / 1ps

module tb_slave ();

    // General signals
    reg        clk;
    reg        reset;
    // I2C ports
    tri        SCL;
    tri        SDA;
    // external signals



    pullup(SCL);
    pullup(SDA);

    always #5 clk = ~clk;


endmodule
