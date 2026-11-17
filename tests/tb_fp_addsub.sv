
`timescale 1ns/1ps

module tb_fp_addsub;

    logic clk = 0;
    logic reset = 1;
    logic in_valid = 0;
    logic sub = 0;

    logic [31:0] a = 0;
    logic [31:0] b = 0;

    wire out_valid;
    wire [31:0] result;

    integer failures = 0;

    fp_addsub dut(.*);

    always #5 clk = ~clk;

    task automatic check(
        input logic [31:0] x, y, expected,
        input logic subtract
    );
        @(negedge clk);

        a = x;
        b = y;
        sub = subtract;
        in_valid = 1;

        @(negedge clk);
        in_valid = 0;

        if (!out_valid || result !== expected) begin
            $display(
                "FAIL a=%h b=%h sub=%b expected=%h got=%h",
                x, y, subtract, expected, result
            );
            failures = failures + 1;
        end
        else begin
            $display(
                "PASS a=%h b=%h sub=%b result=%h",
                x, y, subtract, result
            );
        end

        @(negedge clk);
    endtask

    initial begin
        repeat(2) @(negedge clk);
        reset = 0;

        // Addition: 5.5 + 2.25 = 7.75
        check(32'h40b00000, 32'h40100000,
              32'h40f80000, 0);

        // Subtraction: 5.5 - 2.25 = 3.25
        check(32'h40b00000, 32'h40100000,
              32'h40500000, 1);

        // 1 + 1 = 2
        check(32'h3f800000, 32'h3f800000,
              32'h40000000, 0);

        // 1 - 1 = 0
        check(32'h3f800000, 32'h3f800000,
              32'h00000000, 1);

        // Negative zero
        check(32'h80000000, 32'h00000000,
              32'h80000000, 1);

        // Infinity plus negative infinity
        check(32'h7f800000, 32'hff800000,
              32'h7fc00000, 0);

        // NaN
        check(32'h7fc12345, 32'h3f800000,
              32'h7fc00000, 0);

        // Subnormal addition
        check(32'h00000001, 32'h00000001,
              32'h00000002, 0);

        // Overflow
        check(32'h7f7fffff, 32'h7f7fffff,
              32'h7f800000, 0);

        $display("Total failures: %0d", failures);
        $finish;
    end

endmodule
