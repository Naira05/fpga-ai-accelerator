`timescale 1ns/1ps

module tb_cnn_accelerator;

    // ============================================================
    // Parameters
    // ============================================================
    localparam int DATA_WIDTH   = 8;
    localparam int IMAGE_WIDTH  = 32;
    localparam int WEIGHT_W     = 8;
    localparam int N            = 9;
    localparam int PROD_W       = 16;
    localparam int ACC_W        = 20;
    localparam int OUT_W        = 16;
    localparam int MAC_LATENCY  = 5;

    localparam int IMAGE_SIZE   = IMAGE_WIDTH * IMAGE_WIDTH;
    localparam int OUT_WIDTH    = IMAGE_WIDTH - 2;
    localparam int NUM_OUT      = OUT_WIDTH * OUT_WIDTH;

    localparam int DRAIN_CYCLES = 150;

    // ============================================================
    // Clock / reset
    // ============================================================
    localparam real CLK_PERIOD = 6.250; // ns - keep in sync with the .xdc
 
    logic clk;
    logic rst_n;
 
    initial clk = 1'b0;
 
    always #(CLK_PERIOD / 2.0) clk = ~clk;
 

    // ============================================================
    // DUT inputs
    // ============================================================
    logic kernel_load;

    logic signed [WEIGHT_W-1:0] kernel_in [0:N-1];
    initial begin
        // Initialize array elements to 0 at t=0 to avoid 'X' states
        foreach (kernel_in[i]) begin
            kernel_in[i] = '0;
        end
    end
    

    logic valid_in;
    logic [DATA_WIDTH-1:0] pixel_in;

    logic relu_en;

    // ============================================================
    // DUT outputs
    // ============================================================
    logic signed [OUT_W-1:0] pixel_out;
    logic valid_out;

    // ============================================================
    // DUT
    // ============================================================
    cnn_accelerator #(
        .DATA_WIDTH  (DATA_WIDTH),
        .IMAGE_WIDTH (IMAGE_WIDTH),
        .WEIGHT_W    (WEIGHT_W),
        .N            (N),
        .PROD_W      (PROD_W),
        .ACC_W        (ACC_W),
        .OUT_W       (OUT_W),
        .MAC_LATENCY (MAC_LATENCY)
    ) dut (
        .clk         (clk),
        .rst_n       (rst_n),

        .kernel_load (kernel_load),
        .kernel_in   (kernel_in),

        .valid_in    (valid_in),
        .pixel_in    (pixel_in),

        .relu_en     (relu_en),

        .pixel_out   (pixel_out),
        .valid_out   (valid_out)
    );

    // ============================================================
    // Memories
    // ============================================================
    logic [DATA_WIDTH-1:0] input_mem [0:IMAGE_SIZE-1];

    logic signed [WEIGHT_W-1:0] kernel_mem [0:N-1];

    logic signed [OUT_W-1:0] expected_mem [0:NUM_OUT-1];

    logic signed [OUT_W-1:0] actual_mem [0:NUM_OUT-1];

    // ============================================================
    // Counters / statistics
    // ============================================================
    integer out_idx;

    integer total_correct;
    integer total_errors;
    integer total_checked;

    // ============================================================
    // Throughput statistics
    // ============================================================
    integer throughput_valid_count;
    integer throughput_cycle_count;

    integer current_consecutive_valid;
    integer max_consecutive_valid;

    integer first_valid_cycle;
    integer last_valid_cycle;

    integer cycle_counter;

    // ============================================================
    // Gap detection
    // ============================================================
    integer gap_length;
    integer total_gaps;
    integer max_gap_length;
    integer outputs_before_gap;

    bit seen_first_output;
    

    // ============================================================
    // Live cycle counter
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_counter <= 0;
        end
        else begin
            cycle_counter <= cycle_counter + 1;
        end
    end

    // ============================================================
    // Output capture + throughput + gap measurement
    // ============================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            throughput_valid_count    <= 0;
            throughput_cycle_count    <= 0;

            current_consecutive_valid <= 0;
            max_consecutive_valid     <= 0;

            first_valid_cycle <= -1;
            last_valid_cycle  <= -1;

            gap_length         <= 0;
            total_gaps         <= 0;
            max_gap_length     <= 0;
            outputs_before_gap <= 0;

            seen_first_output <= 1'b0;
        end
        else begin
            throughput_cycle_count <= throughput_cycle_count + 1;

            if (valid_out) begin
                if (out_idx < NUM_OUT) begin
                    actual_mem[out_idx] <= pixel_out;
                end

                out_idx <= out_idx + 1;

                throughput_valid_count <= throughput_valid_count + 1;

                if (!seen_first_output) begin
                    seen_first_output <= 1'b1;
                    first_valid_cycle <= throughput_cycle_count;
                end

                last_valid_cycle <= throughput_cycle_count;

                current_consecutive_valid <= current_consecutive_valid + 1;

                if ((current_consecutive_valid + 1) > max_consecutive_valid) begin
                    max_consecutive_valid <= current_consecutive_valid + 1;
                end

                if (gap_length > 0) begin
                    total_gaps <= total_gaps + 1;

                    if (gap_length > max_gap_length) begin
                        max_gap_length <= gap_length;
                    end

                    $display(
                        "VALID_OUT GAP: cycle=%0d | gap=%0d cycles | outputs_before_gap=%0d",
                        throughput_cycle_count,
                        gap_length,
                        throughput_valid_count
                    );

                    gap_length <= 0;
                end
            end
            else begin
                current_consecutive_valid <= 0;

                if (seen_first_output) begin
                    gap_length <= gap_length + 1;
                end
            end
        end
    end

    // ============================================================
    // Reset
    // ============================================================
    task automatic apply_reset;
        begin
            rst_n       = 1'b0;

            valid_in    = 1'b0;
            pixel_in    = '0;

            kernel_load = 1'b0;
            relu_en     = 1'b0;

            for (int i = 0; i < N; i++) begin
                kernel_in[i] = '0;
            end

            repeat (3) @(negedge clk);

            rst_n = 1'b1;

            @(negedge clk);
        end
    endtask

    // ============================================================
    // Load kernel
    // ============================================================
    task automatic load_kernel;
        begin
            for (int i = 0; i < N; i++) begin
                kernel_in[i] = kernel_mem[i];
            end

            kernel_load = 1'b1;

            @(negedge clk);

            kernel_load = 1'b0;

            @(negedge clk);
        end
    endtask

    // ============================================================
    // Stream frame continuously
    // ============================================================
    task automatic stream_frame;
        begin
            valid_in = 1'b1;

            for (int i = 0; i < IMAGE_SIZE; i++) begin
                pixel_in = input_mem[i];
                @(negedge clk);
            end

            valid_in = 1'b0;
            pixel_in = '0;
        end
    endtask

    // ============================================================
    // Stream frame with intentional stalls
    // ============================================================
    task automatic stream_frame_with_stalls;
        integer i;
        begin
            for (i = 0; i < IMAGE_SIZE; i++) begin
                valid_in = 1'b1;
                pixel_in = input_mem[i];

                @(negedge clk);

                if (((i + 1) % 101) == 0) begin
                    $display(
                        "STALL: after input pixel %0d -> 3-cycle valid_in stall",
                        i
                    );

                    valid_in = 1'b0;
                    pixel_in = '0;

                    repeat (3) @(negedge clk);
                end
                else if (((i + 1) % 37) == 0) begin
                    $display(
                        "STALL: after input pixel %0d -> 2-cycle valid_in stall",
                        i
                    );

                    valid_in = 1'b0;
                    pixel_in = '0;

                    repeat (2) @(negedge clk);
                end
            end

            valid_in = 1'b0;
            pixel_in = '0;
        end
    endtask

    // ============================================================
    // Reset throughput counters
    // ============================================================
    task automatic reset_throughput_stats;
        begin
            throughput_valid_count = 0;
            throughput_cycle_count = 0;

            current_consecutive_valid = 0;
            max_consecutive_valid     = 0;

            first_valid_cycle = -1;
            last_valid_cycle  = -1;

            cycle_counter = 0;

            gap_length         = 0;
            total_gaps         = 0;
            max_gap_length     = 0;
            outputs_before_gap = 0;

            seen_first_output = 1'b0;
        end
    endtask

    // ============================================================
    // Print throughput results
    // ============================================================
    task automatic report_throughput;
        real average_throughput;
        integer active_cycles;

        begin
            $display("");
            $display("==============================================");
            $display("THROUGHPUT MEASUREMENT");
            $display("==============================================");

            $display(
                "Valid outputs observed : %0d",
                throughput_valid_count
            );

            $display(
                "Maximum consecutive valid_out cycles : %0d",
                max_consecutive_valid
            );

            $display(
                "Number of valid_out gaps : %0d",
                total_gaps
            );

            $display(
                "Maximum gap length : %0d cycles",
                max_gap_length
            );

            if ((first_valid_cycle >= 0) &&
                (last_valid_cycle >= first_valid_cycle)) begin

                active_cycles = last_valid_cycle - first_valid_cycle + 1;

                average_throughput = real'(throughput_valid_count) /
                                     real'(active_cycles);

                $display(
                    "First valid cycle : %0d",
                    first_valid_cycle
                );

                $display(
                    "Last valid cycle : %0d",
                    last_valid_cycle
                );

                $display(
                    "Output active interval : %0d cycles",
                    active_cycles
                );

                $display(
                    "Average sustained throughput : %0.4f outputs/cycle",
                    average_throughput
                );

                $display(
                    "Equivalent : %0.2f%% of 1 output/cycle",
                    average_throughput * 100.0
                );
            end
            else begin
                $display(
                    "No valid output observed."
                );
            end

            // Updated to check for sustained 1-output/cycle per row (30 consecutive cycles)
            if (max_consecutive_valid >= OUT_WIDTH) begin
                $display(
                    "RESULT: Continuous 1-output/cycle row throughput achieved."
                );
            end
            else begin
                $display(
                    "RESULT: 1-output/cycle was NOT sustained for all outputs."
                );
            end

            $display("==============================================");
            $display("");
        end
    endtask

    // ============================================================
    // Check outputs
    // ============================================================
    task automatic check_results(input string test_name);
        integer errors_before;

        begin
            errors_before = total_errors;

            $display("");
            $display("----------------------------------------------");
            $display("Checking test: %s", test_name);
            $display("----------------------------------------------");

            if (out_idx !== NUM_OUT) begin
                $display(
                    "[%s] ERROR: expected %0d outputs, received %0d",
                    test_name,
                    NUM_OUT,
                    out_idx
                );

                total_errors = total_errors + 1;
            end
            else begin
                for (int i = 0; i < NUM_OUT; i++) begin
                    if (actual_mem[i] !== expected_mem[i]) begin
                        $display(
                            "[%s] MISMATCH at output %0d: expected=%0d actual=%0d",
                            test_name,
                            i,
                            expected_mem[i],
                            actual_mem[i]
                        );

                        total_errors = total_errors + 1;
                    end
                    else begin
                        total_correct = total_correct + 1;
                    end

                    total_checked = total_checked + 1;
                end
            end

            if (total_errors == errors_before) begin
                $display(
                    "[%s] PASS: all %0d output pixels matched",
                    test_name,
                    NUM_OUT
                );
            end
            else begin
                $display(
                    "[%s] FAIL: %0d new error(s)",
                    test_name,
                    total_errors - errors_before
                );
            end
        end
    endtask

    // ============================================================
    // Run one normal test
    // ============================================================
    task automatic run_test_case(
        input string test_name,
        input logic test_relu
    );
        string input_file;
        string kernel_file;
        string output_file;

        begin
            $display("");
            $display("==============================================");
            $display("RUNNING TEST: %s", test_name);
            $display("==============================================");

            // Updated path to include "../" prefix for build directory compatibility
            input_file  = {"../test_vectors/", test_name, "_input.hex"};
            kernel_file = {"../test_vectors/", test_name, "_kernel.hex"};
            output_file = {"../test_vectors/", test_name, "_output.hex"};

            $readmemh(input_file,  input_mem);
            $readmemh(kernel_file, kernel_mem);
            $readmemh(output_file, expected_mem);

            apply_reset();

            relu_en = test_relu;

            load_kernel();

            out_idx = 0;

            stream_frame();

            repeat (DRAIN_CYCLES) @(negedge clk);

            check_results(test_name);
        end
    endtask

    // ============================================================
    // Run stall test
    // ============================================================
    task automatic run_stall_test(
        input string test_name,
        input logic test_relu
    );
        string input_file;
        string kernel_file;
        string output_file;

        begin
            $display("");
            $display("==============================================");
            $display("RUNNING STALL TEST: %s", test_name);
            $display("==============================================");

            // Updated path to include "../" prefix
            input_file  = {"../test_vectors/", test_name, "_input.hex"};
            kernel_file = {"../test_vectors/", test_name, "_kernel.hex"};
            output_file = {"../test_vectors/", test_name, "_output.hex"};

            $readmemh(input_file,  input_mem);
            $readmemh(kernel_file, kernel_mem);
            $readmemh(output_file, expected_mem);

            apply_reset();

            relu_en = test_relu;

            load_kernel();

            out_idx = 0;

            stream_frame_with_stalls();

            repeat (DRAIN_CYCLES + 20) @(negedge clk);

            check_results({test_name, "_stall"});
        end
    endtask

    // ============================================================
    // Main test sequence
    // ============================================================
    initial begin
        rst_n       = 1'b0;
        kernel_load = 1'b0;
        valid_in    = 1'b0;
        pixel_in    = '0;
        relu_en     = 1'b0;

        out_idx = 0;

        total_correct = 0;
        total_errors  = 0;
        total_checked = 0;

        throughput_valid_count = 0;
        throughput_cycle_count = 0;

        current_consecutive_valid = 0;
        max_consecutive_valid     = 0;

        first_valid_cycle = -1;
        last_valid_cycle  = -1;

        cycle_counter = 0;

        gap_length         = 0;
        total_gaps         = 0;
        max_gap_length     = 0;
        outputs_before_gap = 0;

        seen_first_output = 1'b0;

        for (int i = 0; i < N; i++) begin
            kernel_in[i] = '0;
        end

        apply_reset();

        // ========================================================
        // OFFICIAL TEST CASES
        // ========================================================
        run_test_case("normal",         1'b1);
        run_test_case("extreme",        1'b0);
        run_test_case("balanced",       1'b0);
        run_test_case("all_zero",       1'b0);
        run_test_case("identity",       1'b0);
        run_test_case("worst_case_neg", 1'b0);
        run_test_case("worst_case_pos", 1'b0);

        // ========================================================
        // STALL REQUIREMENT TEST
        // ========================================================
        run_stall_test("normal", 1'b1);

        // ========================================================
        // THROUGHPUT TEST
        // ========================================================
        $display("");
        $display("==============================================");
        $display("RUNNING THROUGHPUT TEST");
        $display("==============================================");

        // Updated relative paths with "../"
        $readmemh("../test_vectors/normal_input.hex",  input_mem);
        $readmemh("../test_vectors/normal_kernel.hex", kernel_mem);
        $readmemh("../test_vectors/normal_output.hex", expected_mem);

        apply_reset();

        relu_en = 1'b1;

        load_kernel();

        out_idx = 0;

        reset_throughput_stats();

        stream_frame();

        repeat (DRAIN_CYCLES) @(negedge clk);

        check_results("throughput");

        report_throughput();

        // ========================================================
        // FINAL SUMMARY
        // ========================================================
        $display("");
        $display("==============================================");
        $display("FINAL TEST SUMMARY");
        $display("==============================================");

        $display("Total correct : %0d", total_correct);
        $display("Total errors  : %0d", total_errors);
        $display("Total checked : %0d", total_checked);

        if (total_errors == 0) begin
            $display("");
            $display("ALL TEST CASES PASSED");
            $display("");
        end
        else begin
            $display("");
            $display("SOME TESTS FAILED");
            $display("");
        end

        $stop;
    end

    // ============================================================
    // Live monitor
    // ============================================================
    initial begin
        $monitor(
            "Time=%0t | rst_n=%b valid_in=%b pixel_in=%0d | valid_out=%b pixel_out=%0d",
            $time,
            rst_n,
            valid_in,
            pixel_in,
            valid_out,
            pixel_out
        );
    end

endmodule