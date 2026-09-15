`timescale 1ns/1ps

module cnn_accelerator #(
    parameter int DATA_WIDTH  = 8,
    parameter int IMAGE_WIDTH = 32,
    parameter int WEIGHT_W    = 8,
    parameter int N           = 9,
    parameter int PROD_W     = DATA_WIDTH + WEIGHT_W,
    parameter int ACC_W       = 20,
    parameter int OUT_W       = 16,
    parameter int MAC_LATENCY = 5
)(
    input  logic clk,
    input  logic rst_n,

    // Kernel programming interface
    input  logic kernel_load,
    input  logic signed [WEIGHT_W-1:0] kernel_in [0:N-1],

    // Streaming pixel input
    input  logic valid_in,
    input  logic [DATA_WIDTH-1:0] pixel_in,

    // Optional ReLU
    input  logic relu_en,

    // Streaming output
    output logic signed [OUT_W-1:0] pixel_out,
    output logic valid_out
);

    // ============================================================
    // Reset
    // ============================================================

    // window_generator/LB_chain use synchronous active-high reset.
    // Convert top-level async active-low reset.
    logic rst;

    assign rst = ~rst_n;


    // ============================================================
    // Kernel registers
    // ============================================================

    logic signed [WEIGHT_W-1:0] kernel_reg [0:N-1];

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            for (int i = 0; i < N; i++) begin
                kernel_reg[i] <= '0;
            end

        end

        else if (kernel_load) begin

            for (int i = 0; i < N; i++) begin
                kernel_reg[i] <= kernel_in[i];
            end

        end

    end


    // ============================================================
    // Sliding window generation
    // ============================================================

    logic [DATA_WIDTH-1:0] window [0:2][0:2];
    logic window_valid;

    window_generator #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_WIDTH (IMAGE_WIDTH)
    ) u_window_gen (
        .clk          (clk),
        .rst          (rst),
        .valid_in     (valid_in),
        .pixel_in     (pixel_in),
        .window       (window),
        .window_valid (window_valid)
    );


    // ============================================================
    // Flatten 3x3 window
    //
    // Row-major order:
    //
    // [0][0] [0][1] [0][2]
    // [1][0] [1][1] [1][2]
    // [2][0] [2][1] [2][2]
    // ============================================================

    logic [DATA_WIDTH-1:0] pixel_flat [0:N-1];

    always_comb begin

        for (int r = 0; r < 3; r++) begin

            for (int c = 0; c < 3; c++) begin

                pixel_flat[r*3 + c] =
                    window[r][c];

            end

        end

    end


    // ============================================================
    // Pipelined 9-tap MAC
    // ============================================================

    logic signed [ACC_W-1:0] mac_sum;

    pipelined_mac #(
        .N        (N),
        .PIXEL_W  (DATA_WIDTH),
        .WEIGHT_W (WEIGHT_W),
        .PROD_W   (PROD_W),
        .ACC_W    (ACC_W)
    ) u_pipelined_mac (
        .clk    (clk),
        .rst_n  (rst_n),
        .pixel  (pixel_flat),
        .weight (kernel_reg),
        .sum    (mac_sum)
    );


    // ============================================================
    // Valid pipeline
    //
    // Align window_valid with the MAC latency.
    // ============================================================

    logic result_valid;

    controller #(
        .LATENCY (MAC_LATENCY)
    ) u_controller (
        .clk          (clk),
        .rst_n        (rst_n),
        .window_valid (window_valid),
        .result_valid (result_valid)
    );


    // ============================================================
    // Optional ReLU
    // ============================================================

    logic signed [ACC_W-1:0] relu_out;

    relu #(
        .WIDTH (ACC_W)
    ) u_relu (
        .data_in  (mac_sum),
        .enable   (relu_en),
        .data_out (relu_out)
    );


    // ============================================================
    // Saturation
    // ============================================================

    logic signed [OUT_W-1:0] saturated_out;

    saturate #(
        .IN_W  (ACC_W),
        .OUT_W (OUT_W)
    ) u_saturate (
        .data_in  (relu_out),
        .data_out (saturated_out)
    );


    // ============================================================
    // RESULT FIFO
    //
    // Why?
    //
    // The window generator naturally produces:
    //
    //     30 valid windows
    //     2 invalid cycles
    //     30 valid windows
    //     2 invalid cycles
    //     ...
    //
    // The FIFO decouples this internal production rate from the
    // external output rate.
    //
    // We accumulate 90 results before starting the output stream.
    //
    // 90 = 3 complete output rows
    //
    // After that, the FIFO has enough buffered results to absorb
    // the remaining 2-cycle row gaps while outputting continuously.
    // ============================================================

    localparam int FIFO_DEPTH = 128;

    // Three complete output rows.
    localparam int FIFO_START_THRESHOLD =
        3 * (IMAGE_WIDTH - 2);

    logic signed [OUT_W-1:0] fifo_pixel_out;
    logic fifo_valid_out;

    result_fifo #(
        .DATA_WIDTH (OUT_W),
        .DEPTH      (FIFO_DEPTH),
        .START_THRESHOLD (FIFO_START_THRESHOLD)
    ) u_result_fifo (
        .clk         (clk),
        .rst_n       (rst_n),

        .data_in     (saturated_out),
        .valid_in    (result_valid),

        .data_out    (fifo_pixel_out),
        .valid_out   (fifo_valid_out)
    );


    // ============================================================
    // Final output
    // ============================================================

    assign pixel_out = fifo_pixel_out;
    assign valid_out = fifo_valid_out;


endmodule