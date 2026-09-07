`timescale 1ns/1ps

module pipelined_mac #(
    parameter int N        = 9,
    parameter int PIXEL_W  = 8,
    parameter int WEIGHT_W = 8,
    parameter int PROD_W   = PIXEL_W + WEIGHT_W,
    parameter int ACC_W    = 20
)(
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic        [PIXEL_W-1:0]    pixel  [0:N-1],
    input  logic signed [WEIGHT_W-1:0]   weight [0:N-1],

    output logic signed [ACC_W-1:0]     sum
);

    logic signed [PROD_W-1:0] product [0:N-1];

    mac_array #(
        .N        (N),
        .PIXEL_W  (PIXEL_W),
        .WEIGHT_W (WEIGHT_W),
        .PROD_W   (PROD_W)
    ) u_mac_array (
        .clk     (clk),
        .rst_n   (rst_n),
        .pixel   (pixel),
        .weight  (weight),
        .product (product)
    );

    adder_tree #(
        .IN_W  (PROD_W),
        .OUT_W (ACC_W)
    ) u_adder_tree (
        .clk     (clk),
        .rst_n   (rst_n),
        .product (product),
        .sum      (sum)
    );

endmodule