module window_generator #(
    parameter DATA_WIDTH  = 8,
    parameter IMAGE_WIDTH = 32
)(
    input logic clk, rst,
    input logic valid_in,
    input logic [DATA_WIDTH-1:0] pixel_in,
    output logic [DATA_WIDTH-1:0] window [0:2][0:2],
    output logic window_valid
);
logic [DATA_WIDTH-1:0] current_pixel, prev_pixel, prev_2_pixel;
logic valid_1_row, valid_2_row;
localparam PTR_WIDTH = (IMAGE_WIDTH <= 1) ? 1 : $clog2(IMAGE_WIDTH);
logic [PTR_WIDTH-1:0] col_count;
//instantiate the LB_chain
LB_chain #(
    .DATA_WIDTH  (DATA_WIDTH),
    .IMAGE_WIDTH (IMAGE_WIDTH)
) lb_chain (
    .clk          (clk),
    .rst          (rst),
    .valid_in     (valid_in),
    .pixel_in     (pixel_in),

    .current_pixel(current_pixel),
    .prev_pixel   (prev_pixel),
    .prev_2_pixel (prev_2_pixel),

    .valid_1_row  (valid_1_row),
    .valid_2_row  (valid_2_row)
);

 //horizontal shift registers
logic [DATA_WIDTH-1:0] shift_reg_top [0:2];
logic [DATA_WIDTH-1:0] shift_reg_middle [0:2];
logic [DATA_WIDTH-1:0] shift_reg_bottom [0:2];
always_ff @(posedge clk) begin
    if(rst) begin
        shift_reg_bottom[0] <= '0;
        shift_reg_bottom[1] <= '0;
        shift_reg_bottom[2] <= '0;

        shift_reg_middle[0] <= '0;
        shift_reg_middle[1] <= '0;
        shift_reg_middle[2] <= '0;

        shift_reg_top[0] <= '0;
        shift_reg_top[1] <= '0;
        shift_reg_top[2] <= '0;
    end else begin
        if(valid_2_row) begin //top row
            shift_reg_top[0] <= prev_2_pixel;
            shift_reg_top[1] <= shift_reg_top[0];
            shift_reg_top[2] <= shift_reg_top[1];
        end
        if(valid_1_row) begin //middle row
            shift_reg_middle[0] <= prev_pixel;
            shift_reg_middle[1] <= shift_reg_middle[0];
            shift_reg_middle[2] <= shift_reg_middle [1];
        end
        if(valid_in) begin //bottom row 
            shift_reg_bottom[0] <= current_pixel;
            shift_reg_bottom[1] <= shift_reg_bottom[0];
            shift_reg_bottom[2] <= shift_reg_bottom[1];
        end
    end 
end

//assign the window outputs
assign window[0][0] = shift_reg_top[2];
assign window[0][1] = shift_reg_top[1];
assign window[0][2] = shift_reg_top[0];
assign window[1][0] = shift_reg_middle[2];
assign window[1][1] = shift_reg_middle[1];
assign window[1][2] = shift_reg_middle[0];
assign window[2][0] = shift_reg_bottom[2];
assign window[2][1] = shift_reg_bottom[1];
assign window[2][2] = shift_reg_bottom[0];

//column counter needed
always_ff @(posedge clk) begin
    if(rst) begin
        col_count <= '0;
    end else if(valid_in) begin
        if(col_count == IMAGE_WIDTH-1) begin
            col_count <= '0;
        end else begin
            col_count <= col_count + 1'b1;
        end
    end
end
//window_valid logic
logic window_valid_comb;
assign window_valid_comb = valid_in && valid_1_row && valid_2_row && (col_count >= 2);

always_ff @(posedge clk) begin
    if (rst) window_valid <= 1'b0;
    else     window_valid <= window_valid_comb;
end
endmodule
