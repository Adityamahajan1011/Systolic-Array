`timescale 1ns / 1ps

module tb_arrayy;
    parameter N          = 3;
    parameter DATA_WIDTH = 3;
    parameter R_WIDTH    = 6;

    reg clk;
    reg reset;
    reg [N*DATA_WIDTH-1:0] a;
    reg [N*DATA_WIDTH-1:0] b;
    wire [(N*N*R_WIDTH)-1:0] result;

    // Golden model matrices and DUT output storage
    reg [DATA_WIDTH-1:0] mat_A [0:N-1][0:N-1];
    reg [DATA_WIDTH-1:0] mat_B [0:N-1][0:N-1];
    reg [R_WIDTH-1:0]    mat_C_gold [0:N-1][0:N-1];
    reg [R_WIDTH-1:0]    mat_C_dut  [0:N-1][0:N-1];

    integer i, j, k, t;
    integer errors;

    // Instantiate DUT
    arrayy #(
        .N(N),
        .DATA_WIDTH(DATA_WIDTH),
        .R_WIDTH(R_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .a(a),
        .b(b),
        .result(result)
    );

    // Clock generator (50 MHz / 20ns period)
    localparam CLK_PERIOD = 20;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("tb_arrayy.vcd");
        $dumpvars(0, tb_arrayy);

        // 1. Initialize Stimulus Matrices
        mat_A[0][0] = 1; mat_A[0][1] = 2; mat_A[0][2] = 0;
        mat_A[1][0] = 0; mat_A[1][1] = 7; mat_A[1][2] = 5;
        mat_A[2][0] = 3; mat_A[2][1] = 2; mat_A[2][2] = 0;

        mat_B[0][0] = 0; mat_B[0][1] = 2; mat_B[0][2] = 0;
        mat_B[1][0] = 1; mat_B[1][1] = 0; mat_B[1][2] = 3;
        mat_B[2][0] = 0; mat_B[2][1] = 0; mat_B[2][2] = 4;

        // 2. Compute Golden Reference Model
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                mat_C_gold[i][j] = 0;
                for (k = 0; k < N; k = k + 1) begin
                    mat_C_gold[i][j] = mat_C_gold[i][j] + (mat_A[i][k] * mat_B[k][j]);
                end
            end
        end

        // 3. Reset Hardware
        clk = 0;
        reset = 1;
        a = 0;
        b = 0;
        errors = 0;
        repeat(2) @(negedge clk);
        reset = 0;

        // 4. Stream Raw Matrix Elements (Parallel, No Manual Skew Needed)
        // At cycle t: feed Column t of Matrix A to row inputs, Row t of Matrix B to col inputs
        for (t = 0; t < N; t = t + 1) begin
            @(negedge clk);
            for (i = 0; i < N; i = i + 1) begin
                a[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = mat_A[i][t];
                b[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] = mat_B[t][i];
            end
        end

        // 5. Drain Phase: Drive zeros into array inputs
        @(negedge clk);
        a = 0;
        b = 0;

        // Wait remaining computation cycles: Total time is 3N - 2 cycles
        repeat((3*N - 2) - N + 1) @(negedge clk);

        // 6. Unpack Flattened Result Vector into 2D Array
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                mat_C_dut[i][j] = result[((i*N + j + 1)*R_WIDTH)-1 -: R_WIDTH];
            end
        end

        // 7. Automated Self-Check
        $display("\n==================================================");
        $display("               VERIFICATION RESULTS               ");
        $display("==================================================");
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                if (mat_C_dut[i][j] !== mat_C_gold[i][j]) begin
                    $display("MISMATCH at C[%0d][%0d]: Expected %0d, Got %0d", 
                             i, j, mat_C_gold[i][j], mat_C_dut[i][j]);
                    errors = errors + 1;
                end
            end
        end

        // 8. Formatted Console Matrix Print
        $display("\nDUT OUTPUT MATRIX:");
        for (i = 0; i < N; i = i + 1) begin
            $write("  [");
            for (j = 0; j < N; j = j + 1) begin
                $write(" %3d", mat_C_dut[i][j]);
            end
            $display(" ]");
        end

        if (errors == 0) begin
            $display("\n>>> TEST PASSED: ALL %0d OUTPUTS MATCH GOLDEN MODEL <<<", N*N);
        end else begin
            $display("\n>>> TEST FAILED: %0d ERRORS FOUND <<<", errors);
        end
        $display("==================================================\n");

        $finish;
    end

endmodule