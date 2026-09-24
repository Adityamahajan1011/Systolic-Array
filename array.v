module delay_ele #(
    parameter DATA_WIDTH = 3,
    parameter DEPTH      = 0
)(
    input  wire                  clk,
    input  wire                  reset,
    input  wire [DATA_WIDTH-1:0] idata,
    output wire [DATA_WIDTH-1:0] odata
);

    if (DEPTH == 0) begin : gen_pass_through
        assign odata = idata;
    end else begin : gen_shift_chain
        reg [DATA_WIDTH-1:0] shift_reg [0:DEPTH-1];
        integer k;

        always @(posedge clk or posedge reset) begin
            if (reset) begin
                for (k = 0; k < DEPTH; k = k + 1)
                    shift_reg[k] <= {DATA_WIDTH{1'b0}};
            end else begin
                shift_reg[0] <= idata;
                for (k = 1; k < DEPTH; k = k + 1)
                    shift_reg[k] <= shift_reg[k-1];
            end
        end

        assign odata = shift_reg[DEPTH-1];
    end

endmodule

module arrayy #(
    parameter N          = 3,
    parameter DATA_WIDTH = 3, 
    parameter R_WIDTH    = 6 
)(
    input  wire                     clk,
    input  wire                     reset,
    // Flattened boundary inputs (N elements of DATA_WIDTH bits each)
    input  wire [N*DATA_WIDTH-1:0]  a,
    input  wire [N*DATA_WIDTH-1:0]  b,
    // Flattened outputs (N*N elements of R_WIDTH bits each)
    output wire [(N*N*R_WIDTH)-1:0] result
);

    genvar row, col, i;
    wire [DATA_WIDTH-1:0] horizontal [0:N-1][0:N];
    wire [DATA_WIDTH-1:0] vertical   [0:N][0:N-1];

    // Horizontal Row Skew Buffers (Row i gets delay = i)
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_hori_delay
            delay_ele #(
                .DATA_WIDTH(DATA_WIDTH),
                .DEPTH(i)
            ) d_hori (
                .clk(clk),
                .reset(reset),
                .idata(a[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]),
                .odata(horizontal[i][0])
            );
        end
    endgenerate

    // Vertical Column Skew Buffers (Col i gets delay = i)
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_vert_delay
            delay_ele #(
                .DATA_WIDTH(DATA_WIDTH),
                .DEPTH(i)
            ) d_vert (
                .clk(clk),
                .reset(reset),
                .idata(b[(i+1)*DATA_WIDTH-1 : i*DATA_WIDTH]),
                .odata(vertical[0][i])
            );
        end
    endgenerate

    // N x N Processing Element Grid
    generate
        for (row = 0; row < N; row = row + 1) begin : gen_row
            for (col = 0; col < N; col = col + 1) begin : gen_col
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .R_WIDTH(R_WIDTH)
                ) pe_inst (
                    .clk(clk),
                    .reset(reset),
                    .a_in(horizontal[row][col]),
                    .b_in(vertical[row][col]),
                    .a_out(horizontal[row][col+1]),
                    .b_out(vertical[row+1][col]),
                    .acc_result(result[((row*N + col + 1)*R_WIDTH)-1 : (row*N + col)*R_WIDTH])
                );
            end
        end
    endgenerate

endmodule