`timescale 1ns / 1ps

module dreu #(
    parameter USE_HISTORY_AWARE_ADAPTATION = 1
)(
    input clk,
    input rst,
    input high_dynamic_range,
    output reg [4:0] exact_region,
    output reg [4:0] approx_region
);

reg [1:0] range_history;
wire history_promoted_range;

assign history_promoted_range =
    USE_HISTORY_AWARE_ADAPTATION ?
    (high_dynamic_range | &range_history) :
    high_dynamic_range;

always @(posedge clk or posedge rst)
begin
    if (rst) begin
        exact_region <= 5'd14;
        approx_region <= 5'd2;
        range_history <= 2'b00;
    end
    else begin
        if (USE_HISTORY_AWARE_ADAPTATION)
            range_history <= {range_history[0], high_dynamic_range};
        else
            range_history <= 2'b00;

        if (history_promoted_range) begin
            exact_region <= 5'd15;
            approx_region <= 5'd1;
        end
        else begin
            exact_region <= 5'd13;
            approx_region <= 5'd3;
        end
    end
end

endmodule
