`timescale 1ns / 1ps

module runtime_feedback(
    input clk,
    input rst,
    input [31:0] P,
    output reg feedback_flag
);


reg [3:0] stable_counter;


always @(posedge clk or posedge rst)
begin


    if(rst)
    begin

        feedback_flag <= 1'b0;

        stable_counter <= 4'd0;

    end


    else
    begin


        if(P > 32'd500000)
        begin

 
            if(stable_counter < 4'd8)
            begin

                stable_counter <=
                stable_counter + 1'b1;

                feedback_flag <= 1'b0;

            end

            else
            begin


                feedback_flag <= 1'b1;

            end

        end


        else
        begin

            stable_counter <= 4'd0;

            feedback_flag <= 1'b0;

        end

    end

end

endmodule
