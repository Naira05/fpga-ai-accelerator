`timescale 1ns/1ps

// ============================================================================
// RESULT FIFO
// =============================================================================
//
// Buffers convolution results so that the external interface can provide
// one output pixel per cycle even though the sliding-window generator has
// two-cycle gaps at row boundaries.
//
// Split out from cnn_accelerator.sv into its own file for consistency with
// the rest of rtl/memory/ (line_buffer.sv, LB_chain.sv) - one module per
// file, grouped by category.
// ============================================================================

module result_fifo #(
    parameter int DATA_WIDTH = 16,
    parameter int DEPTH = 128,
    parameter int START_THRESHOLD = 90
)(
    input logic clk,
    input logic rst_n,

    input logic signed [DATA_WIDTH-1:0] data_in,
    input logic valid_in,

    output logic signed [DATA_WIDTH-1:0] data_out,
    output logic valid_out
);

    // ============================================================
    // Pointer / counter widths
    // ============================================================

    localparam int PTR_WIDTH =
        (DEPTH <= 1) ? 1 : $clog2(DEPTH);

    localparam int COUNT_WIDTH =
        $clog2(DEPTH + 1);


    // ============================================================
    // FIFO memory
    // ============================================================

    logic signed [DATA_WIDTH-1:0] fifo_mem [0:DEPTH-1];

    logic [PTR_WIDTH-1:0] write_ptr;
    logic [PTR_WIDTH-1:0] read_ptr;

    logic [COUNT_WIDTH-1:0] fifo_count;


    // ============================================================
    // Output streaming state
    // ============================================================

    logic output_started;


    // ============================================================
    // Read/write enables
    // ============================================================

    logic write_enable;
    logic read_enable;

    assign write_enable = valid_in;

    assign read_enable =
        output_started &&
        (fifo_count != 0);


    // ============================================================
    // FIFO output
    //
    // Asynchronous read from the registered FIFO memory.
    // The data is stable between clock edges.
    // ============================================================

    assign data_out = fifo_mem[read_ptr];

    assign valid_out =
        output_started &&
        (fifo_count != 0);


    // ============================================================
    // FIFO memory write - CLOCK ONLY, no reset in sensitivity list.
    //
    // This must be its own block with no async (or sync) reset
    // touching it at all - Xilinx Block RAM primitives cannot
    // implement an asynchronous reset on stored data. Sharing an
    // always_ff block with `negedge rst_n` (even if that branch never
    // touches fifo_mem) blocks BRAM inference for the whole array,
    // forcing Vivado to build it out of individual flip-flops instead
    // (Synth 8-4767 / 8-5788 warnings). fifo_mem never needs to be
    // reset - only the pointers/count below need reset, and stale
    // memory contents are never read since read_enable depends on
    // fifo_count, which IS reset to 0.
    // ============================================================

    always_ff @(posedge clk) begin
        if (write_enable) begin
            fifo_mem[write_ptr] <= data_in;
        end
    end


    // ============================================================
    // FIFO control logic (pointers, count, output state)
    //
    // Async reset is fine here - none of these are memory arrays.
    // ============================================================

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            write_ptr      <= '0;
            read_ptr       <= '0;
            fifo_count     <= '0;
            output_started <= 1'b0;

        end

        else begin

            // ====================================================
            // WRITE (pointer update only - the actual fifo_mem write
            // now lives in the clock-only block above)
            // ====================================================

            if (write_enable) begin

                if (write_ptr == DEPTH-1) begin
                    write_ptr <= '0;
                end
                else begin
                    write_ptr <= write_ptr + 1'b1;
                end

            end


            // ====================================================
            // READ
            // ====================================================

            if (read_enable) begin

                if (read_ptr == DEPTH-1) begin
                    read_ptr <= '0;
                end
                else begin
                    read_ptr <= read_ptr + 1'b1;
                end

            end


            // ====================================================
            // COUNT
            //
            // Both can happen in the same cycle.
            // ====================================================

            case ({write_enable, read_enable})

                2'b10: begin
                    fifo_count <= fifo_count + 1'b1;
                end

                2'b01: begin
                    fifo_count <= fifo_count - 1'b1;
                end

                2'b11: begin
                    fifo_count <= fifo_count;
                end

                default: begin
                    fifo_count <= fifo_count;
                end

            endcase


            // ====================================================
            // Start output after enough buffering
            //
            // Once started, remain started until FIFO empties.
            // ====================================================

            if (!output_started) begin

                if (fifo_count >= START_THRESHOLD) begin
                    output_started <= 1'b1;
                end

            end

            else begin

                if ((fifo_count == 0) && !write_enable) begin
                    output_started <= 1'b0;
                end

            end

        end

    end

endmodule