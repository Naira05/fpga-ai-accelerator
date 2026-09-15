`timescale 1ns/1ps

module controller #(
    parameter int LATENCY = 5   // 1 (multiplier reg) + 4 (adder_tree stages)
)(
    input  logic clk,
    input  logic rst_n,
    input  logic window_valid,
    output logic result_valid
);

    logic [LATENCY-1:0] valid_shift;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            valid_shift <= '0;
        else
            valid_shift <= {valid_shift[LATENCY-2:0], window_valid};
    end

    assign result_valid = valid_shift[LATENCY-1];

endmodule