`timescale 1ns/1ps

//==============================================================
// adder_tree.sv
//
// 9-input pipelined adder tree for a 3x3 convolution.
//
// Structure:
//
//       9 -> 5 -> 3 -> 2 -> 1
//
// Bit widths:
//
//       16 -> 17 -> 18 -> 19 -> 20
//
// Each level is registered.
//
// Total latency = 4 clock cycles.
//
// Input : 9 signed 16-bit products
// Output: signed 20-bit sum
//==============================================================

module adder_tree #(
    parameter int IN_W  = 16,
    parameter int OUT_W = IN_W + 4
)(
    input  logic                    clk,
    input  logic                    rst_n,

    input  logic signed [IN_W-1:0] product [0:8],

    output logic signed [OUT_W-1:0] sum
);

    //==========================================================
    // Stage 1
    //
    // 9 inputs -> 5 outputs
    //
    // Width: 16 -> 17
    //==========================================================

    logic signed [IN_W:0] stage1 [0:4];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            for (int i = 0; i < 5; i++) begin
                stage1[i] <= '0;
            end

        end
        else begin

            stage1[0] <=
                $signed({product[0][IN_W-1], product[0]}) +
                $signed({product[1][IN_W-1], product[1]});

            stage1[1] <=
                $signed({product[2][IN_W-1], product[2]}) +
                $signed({product[3][IN_W-1], product[3]});

            stage1[2] <=
                $signed({product[4][IN_W-1], product[4]}) +
                $signed({product[5][IN_W-1], product[5]});

            stage1[3] <=
                $signed({product[6][IN_W-1], product[6]}) +
                $signed({product[7][IN_W-1], product[7]});

            // 9th product has no pair
            // Sign extension happens automatically through assignment
            stage1[4] <= product[8];

        end
    end


    //==========================================================
    // Stage 2
    //
    // 5 inputs -> 3 outputs
    //
    // Width: 17 -> 18
    //==========================================================

    logic signed [IN_W+1:0] stage2 [0:2];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            for (int i = 0; i < 3; i++) begin
                stage2[i] <= '0;
            end

        end
        else begin

            stage2[0] <=
                $signed({stage1[0][IN_W], stage1[0]}) +
                $signed({stage1[1][IN_W], stage1[1]});

            stage2[1] <=
                $signed({stage1[2][IN_W], stage1[2]}) +
                $signed({stage1[3][IN_W], stage1[3]});

            stage2[2] <= stage1[4];

        end
    end


    //==========================================================
    // Stage 3
    //
    // 3 inputs -> 2 outputs
    //
    // Width: 18 -> 19
    //==========================================================

    logic signed [IN_W+2:0] stage3 [0:1];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            for (int i = 0; i < 2; i++) begin
                stage3[i] <= '0;
            end

        end
        else begin

            stage3[0] <=
                $signed({stage2[0][IN_W+1], stage2[0]}) +
                $signed({stage2[1][IN_W+1], stage2[1]});

            stage3[1] <= stage2[2];

        end
    end


    //==========================================================
    // Stage 4
    //
    // 2 inputs -> 1 output
    //
    // Width: 19 -> 20
    //==========================================================

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= '0;
        end
        else begin

            sum <=
                $signed({stage3[0][IN_W+2], stage3[0]}) +
                $signed({stage3[1][IN_W+2], stage3[1]});

        end
    end

endmodule