`timescale 1ns/1ps

module mac_array #(
    parameter int N        = 9,
    parameter int PIXEL_W  = 8,
    parameter int WEIGHT_W = 8,
    parameter int PROD_W   = PIXEL_W + WEIGHT_W
)(
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic        [PIXEL_W-1:0]    pixel  [0:N-1],
    input  logic signed [WEIGHT_W-1:0]   weight [0:N-1],

    output logic signed [PROD_W-1:0]     product [0:N-1]
);

    genvar i;

    generate
        for (i = 0; i < N; i++) begin : GEN_MULTIPLIERS

            multiplier #(
                .PIXEL_W  (PIXEL_W),
                .WEIGHT_W (WEIGHT_W),
                .PROD_W   (PROD_W)
            ) u_multiplier (
                .clk     (clk),
                .rst_n   (rst_n),
                .pixel   (pixel[i]),
                .weight  (weight[i]),
                .product (product[i])
            );

        end
    endgenerate

endmodule