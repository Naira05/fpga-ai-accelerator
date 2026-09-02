`timescale 1ns/1ps

//==============================================================
// adder_tree.sv
//
// 9-input pipelined adder tree
//
// Structure:
//      9 inputs -> 5 -> 3 -> 2 -> 1 output
//
// Each adder stage is registered, so the final output has
// a latency of 4 clock cycles.
//
// Input width : IN_W  = 17 bits
// Output width: OUT_W = 21 bits
//
// Bit growth:
//      17 -> 18 -> 19 -> 20 -> 21
//==============================================================

module adder_tree #(
    parameter int IN_W  = 17,
    parameter int OUT_W = IN_W + 4
)(
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic signed [IN_W-1:0]       product [0:8],

    output logic signed [OUT_W-1:0]      sum
);

    //==========================================================
    // Stage 1: 9 inputs -> 5 outputs
    //
    // Two products are added together.
    // product[8] has no pair, so it is passed through.
    //
    // Width: 17 -> 18 bits
    //==========================================================

    logic signed [IN_W:0] stage1 [0:4];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 5; i++) begin
                stage1[i] <= '0;
            end
        end
        else begin
            stage1[0] <= $signed(product[0]) + $signed(product[1]);
            stage1[1] <= $signed(product[2]) + $signed(product[3]);
            stage1[2] <= $signed(product[4]) + $signed(product[5]);
            stage1[3] <= $signed(product[6]) + $signed(product[7]);

            // Odd input passes through
            stage1[4] <= product[8];
        end
    end


    //==========================================================
    // Stage 2: 5 inputs -> 3 outputs
    //
    // Width: 18 -> 19 bits
    //==========================================================

    logic signed [IN_W+1:0] stage2 [0:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 3; i++) begin
                stage2[i] <= '0;
            end
        end
        else begin
            stage2[0] <= $signed(stage1[0]) + $signed(stage1[1]);
            stage2[1] <= $signed(stage1[2]) + $signed(stage1[3]);

            // Odd input passes through
            stage2[2] <= stage1[4];
        end
    end


    //==========================================================
    // Stage 3: 3 inputs -> 2 outputs
    //
    // Width: 19 -> 20 bits
    //==========================================================

    logic signed [IN_W+2:0] stage3 [0:1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 2; i++) begin
                stage3[i] <= '0;
            end
        end
        else begin
            stage3[0] <= $signed(stage2[0]) + $signed(stage2[1]);

            // Odd input passes through
            stage3[1] <= stage2[2];
        end
    end


    //==========================================================
    // Stage 4: 2 inputs -> 1 output
    //
    // Width: 20 -> 21 bits
    //
    // This is the final addition.
    //==========================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= '0;
        end
        else begin
            sum <= $signed(stage3[0]) + $signed(stage3[1]);
        end
    end

endmodule