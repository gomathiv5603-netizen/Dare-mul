`timescale 1ns / 1ps

module operand_analysis(
    input [15:0] A,
    input [15:0] B,
    output reg high_dynamic_range
);


wire [15:0] operand_sum;

assign operand_sum = A + B;


always @(*)
begin


    if(operand_sum > 16'd40000)
    begin

        high_dynamic_range = 1'b1;

    end

    else
    begin

        high_dynamic_range = 1'b0;

    end

end

endmodule
