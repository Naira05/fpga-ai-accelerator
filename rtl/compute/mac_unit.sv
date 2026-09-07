`timescale 1ns/1ps

module mac_unit #(
    parameter int PIXEL_W  = 8,
    parameter int WEIGHT_W = 8,
    parameter int PROD_W   = PIXEL_W + WEIGHT_W,
    parameter int ACC_W    = 20
)(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         enable,
    input  logic                         clear,

    input  logic        [PIXEL_W-1:0]    pixel,
    input  logic signed [WEIGHT_W-1:0]   weight,

    output logic signed [ACC_W-1:0]     acc
);

    logic signed [PROD_W-1:0] product;

    logic signed [ACC_W-1:0] product_ext;

    always_comb begin
        product = $signed({1'b0, pixel}) * weight;

        product_ext = {{(ACC_W-PROD_W){product[PROD_W-1]}}, product};
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc <= '0;
        end
        else if (clear) begin
            acc <= '0;
        end
        else if (enable) begin
            acc <= acc + product_ext;
        end
    end

endmodule