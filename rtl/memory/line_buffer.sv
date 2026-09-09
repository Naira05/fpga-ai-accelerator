module line_buffer #(
    parameter DATA_WIDTH  = 8,
    parameter IMAGE_WIDTH = 32
)(
    input logic clk, rst,
    input logic valid_in,
    input logic [DATA_WIDTH-1:0] pixel_in,
    output logic [DATA_WIDTH-1:0] pixel_out,
    output logic valid_out
);
localparam PTR_WIDTH = (IMAGE_WIDTH <= 1) ? 1 : $clog2(IMAGE_WIDTH);
logic [DATA_WIDTH-1:0] buffer [0:IMAGE_WIDTH-1]; //memory buffer for one row of pixels
// Current column
logic [PTR_WIDTH-1:0] col_count;
// Indicates that at least one complete row has already been written into the buffer.
logic first_row_done;
assign pixel_out = buffer[col_count];
assign valid_out = valid_in && first_row_done;

always_ff @(posedge clk) begin
    if (rst) begin
        col_count      <= '0;
        first_row_done <= 1'b0;
    end else if (valid_in) begin
        buffer[col_count] <= pixel_in;
        if (col_count == IMAGE_WIDTH-1) begin
            col_count      <= '0;
            first_row_done <= 1'b1;
        end else begin
            col_count <= col_count + 1'b1;
        end
    end
end
endmodule
