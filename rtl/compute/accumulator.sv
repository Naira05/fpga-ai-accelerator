`timescale 1ns/1ps

module accumulator #(
    parameter int PROD_W = 16,
    parameter int ACC_W  = 20
)(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         enable,
    input  logic                         clear,

    input  logic signed [PROD_W-1:0]     value,

    output logic signed [ACC_W-1:0]      acc
);

    logic signed [ACC_W-1:0] value_ext;

    always_comb begin
        value_ext = {{(ACC_W-PROD_W){value[PROD_W-1]}}, value};
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= '0;
        end
        else if (clear) begin
            acc <= '0;
        end
        else if (enable) begin
            acc <= acc + value_ext;
        end
    end

endmodule