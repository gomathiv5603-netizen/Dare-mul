`timescale 1ns / 1ps

module dare_mul_top #(
    parameter USE_OPERAND_ANALYSIS = 1,
    parameter USE_DREU = 1,
    parameter USE_HISTORY_AWARE_ADAPTATION = 1,
    parameter USE_DYNAMIC_REGION_PARTITIONING = 1,
    parameter USE_ADAPTIVE_REDUCTION_TREE = 1,
    parameter USE_HYBRID_ACCUMULATOR = 1,
    parameter USE_RUNTIME_FEEDBACK = 1
)(
    input clk,
    input rst,
    input [15:0] A,
    input [15:0] B,
    output reg [31:0] P
);

wire analyzed_high_dynamic_range;
wire effective_high_dynamic_range;

wire [4:0] dreu_exact_region;
wire [4:0] dreu_approx_region;
wire [4:0] selected_exact_region;
wire [4:0] selected_approx_region;

wire [31:0] partial_products;
wire [31:0] reduced_sum;
wire [31:0] accumulated_product;
wire [31:0] accumulation_stage_output;
wire [31:0] feedback_adjusted_product;

wire feedback_flag;

operand_analysis oa (
    .A(A),
    .B(B),
    .high_dynamic_range(analyzed_high_dynamic_range)
);

assign effective_high_dynamic_range =
    USE_OPERAND_ANALYSIS ?
    analyzed_high_dynamic_range :
    (A[15] | B[15]);

dreu #(
    .USE_HISTORY_AWARE_ADAPTATION(USE_HISTORY_AWARE_ADAPTATION)
) dreu_inst (
    .clk(clk),
    .rst(rst),
    .high_dynamic_range(effective_high_dynamic_range),
    .exact_region(dreu_exact_region),
    .approx_region(dreu_approx_region)
);

assign selected_exact_region =
    USE_DYNAMIC_REGION_PARTITIONING ?
    (USE_DREU ? dreu_exact_region : 5'd14) :
    5'd14;

assign selected_approx_region =
    USE_DYNAMIC_REGION_PARTITIONING ?
    (USE_DREU ? dreu_approx_region : 5'd2) :
    5'd2;

partial_product_generator ppg (
    .A(A),
    .B(B),
    .exact_region(selected_exact_region),
    .approx_region(selected_approx_region),
    .partial_products(partial_products)
);

adaptive_reduction_tree #(
    .USE_ADAPTIVE_REDUCTION_TREE(USE_ADAPTIVE_REDUCTION_TREE)
) art (
    .partial_products(partial_products),
    .approx_region(selected_approx_region),
    .reduced_sum(reduced_sum)
);

hybrid_accumulator ha (
    .clk(clk),
    .rst(rst),
    .reduced_sum(reduced_sum),
    .P(accumulated_product)
);

assign accumulation_stage_output =
    USE_HYBRID_ACCUMULATOR ?
    accumulated_product :
    reduced_sum;

runtime_feedback rf (
    .clk(clk),
    .rst(rst),
    .P(P),
    .feedback_flag(feedback_flag)
);

assign feedback_adjusted_product =
    (USE_RUNTIME_FEEDBACK && feedback_flag) ?
    {accumulation_stage_output[31:4], accumulation_stage_output[3:0] >> 1} :
    accumulation_stage_output;

always @(posedge clk or posedge rst)
begin
    if (rst)
        P <= 32'd0;
    else
        P <= feedback_adjusted_product;
end

endmodule
