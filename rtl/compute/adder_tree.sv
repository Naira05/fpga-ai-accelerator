`timescale 1ns/1ps

module adder_tree #(
    parameter int IN_W  = 17,
    parameter int OUT_W = IN_W + 4
)(
    input  logic signed [IN_W-1:0] product [0:8],
    output logic signed [OUT_W-1:0] sum
);

    logic signed [OUT_W-1:0] level1 [0:7];
    logic signed [OUT_W-1:0] level2 [0:3];
    logic signed [OUT_W-1:0] level3 [0:1];

    always_comb begin

        // Level 1
        level1[0] = product[0] + product[1];
        level1[1] = product[2] + product[3];
        level1[2] = product[4] + product[5];
        level1[3] = product[6] + product[7];

        level1[4] = product[8];
        level1[5] = '0;
        level1[6] = '0;
        level1[7] = '0;

        // Level 2
        level2[0] = level1[0] + level1[1];
        level2[1] = level1[2] + level1[3];

        level2[2] = level1[4] + level1[5];
        level2[3] = level1[6] + level1[7];

        // Level 3
        level3[0] = level2[0] + level2[1];
        level3[1] = level2[2] + level2[3];

        // Final sum
        sum = level3[0] + level3[1];

    end

endmodule