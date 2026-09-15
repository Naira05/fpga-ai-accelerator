`timescale 1ns/1ps

module saturate #(
    parameter int IN_W  = 20,
    parameter int OUT_W = 16
)(
    input  logic signed [IN_W-1:0]  data_in,
    output logic signed [OUT_W-1:0] data_out
);

    localparam signed [OUT_W-1:0] MAX_VAL = {1'b0, {(OUT_W-1){1'b1}}};
    localparam signed [OUT_W-1:0] MIN_VAL = {1'b1, {(OUT_W-1){1'b0}}};

    // Overflow iff the upper (IN_W-OUT_W+1) bits are not all equal to the sign bit.
    logic overflow;
    assign overflow = |data_in[IN_W-1:OUT_W-1] & ~(&data_in[IN_W-1:OUT_W-1]);

    always_comb begin
        if (overflow)
            data_out = data_in[IN_W-1] ? MIN_VAL : MAX_VAL;
        else
            data_out = data_in[OUT_W-1:0];
    end

endmodule