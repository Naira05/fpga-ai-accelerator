`timescale 1ns/1ps

module mac #(
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

    multiplier #(
        .PIXEL_W  (PIXEL_W),
        .WEIGHT_W (WEIGHT_W),
        .PROD_W   (PROD_W)
    ) u_multiplier (
        .clk     (clk),
        .rst_n   (rst_n),
        .pixel   (pixel),
        .weight  (weight),
        .product (product)
    );

    accumulator #(
        .PROD_W (PROD_W),
        .ACC_W  (ACC_W)
    ) u_accumulator (
        .clk     (clk),
        .rst_n   (rst_n),
        .enable  (enable),
        .clear   (clear),
        .value   (product),
        .acc     (acc)
    );

endmodule