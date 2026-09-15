`timescale 1ns/1ps

module relu #(
    parameter int WIDTH = 20
)(
    input  logic signed [WIDTH-1:0] data_in,
    input  logic                    enable,
    output logic signed [WIDTH-1:0] data_out
);

    // When enabled, clamp negative values to 0; otherwise pass through unchanged.
    assign data_out = (enable && data_in[WIDTH-1]) ? '0 : data_in;

endmodule