`timescale 1ns/1ps

module multiplier #(
    parameter int PIXEL_W  = 8,
    parameter int WEIGHT_W = 8,
    parameter int PROD_W   = PIXEL_W + WEIGHT_W
)(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic        [PIXEL_W-1:0]    pixel,
    input  logic signed [WEIGHT_W-1:0]    weight,
    output logic signed [PROD_W-1:0]     product
);

    logic signed [PIXEL_W:0] pixel_s;
    logic signed [PROD_W-1:0] product_full;

    always_comb begin
        // Convert unsigned pixel into a positive signed value
        pixel_s = {1'b0, pixel};

        // Signed multiplication
        product_full = pixel_s * weight;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            product <= '0;
        else
            product <= product_full;
    end

endmodule