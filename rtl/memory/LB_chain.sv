module LB_chain#(
    parameter DATA_WIDTH  = 8,
    parameter IMAGE_WIDTH = 32
)(
    input logic clk, rst,
    input logic valid_in,
    input logic [DATA_WIDTH-1:0] pixel_in,
    output logic [DATA_WIDTH-1:0] current_pixel, prev_pixel, prev_2_pixel,
    output logic valid_1_row,valid_2_row
);
logic lb1_valid_out, lb2_valid_out;
logic [DATA_WIDTH-1:0] lb1_pixel_out, lb2_pixel_out;

//instantiate lb1
line_buffer #(
    .DATA_WIDTH  (DATA_WIDTH),
    .IMAGE_WIDTH (IMAGE_WIDTH)
) lb1 (
    .clk       (clk),
    .rst       (rst),
    .valid_in  (valid_in),
    .pixel_in  (pixel_in),
    .pixel_out (lb1_pixel_out),
    .valid_out (lb1_valid_out)
);

//instantiate lb2
line_buffer #(
    .DATA_WIDTH  (DATA_WIDTH),
    .IMAGE_WIDTH (IMAGE_WIDTH)
) lb2 (
    .clk       (clk),
    .rst       (rst),
    .valid_in  (lb1_valid_out),
    .pixel_in  (lb1_pixel_out),
    .pixel_out (lb2_pixel_out),
    .valid_out (lb2_valid_out)
);
assign current_pixel = pixel_in;
assign prev_pixel = lb1_pixel_out;
assign prev_2_pixel = lb2_pixel_out;
assign valid_1_row = lb1_valid_out;
assign valid_2_row = lb2_valid_out;
endmodule
