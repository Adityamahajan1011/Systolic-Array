module pe #(
    DATA_WIDTH = 3 , R_WIDTH = 6
) (
    input clk ,reset , 
    input [DATA_WIDTH-1:0]a_in , b_in ,
    output reg[DATA_WIDTH-1:0] a_out,b_out,
    output reg[R_WIDTH-1:0]acc_result 
);

always @(posedge clk or posedge reset) begin
    if(reset) begin
        a_out<=0 ; 
        b_out<=0 ; 
        acc_result<=0 ;
    end
    else 
    begin
            a_out<=a_in ; 
            b_out<=b_in ; 
            acc_result <= acc_result + a_in * b_in ;
    end
end
    
endmodule