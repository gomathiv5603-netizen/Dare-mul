`timescale 1ns / 1ps

module hybrid_accumulator(
    input clk,
    input rst,
    input [31:0] reduced_sum,
    output reg [31:0] P
);

always @(posedge clk or posedge rst)
begin
    if (rst)
        P <= 32'd0;
    else
        P <= reduced_sum;
end

endmodule
