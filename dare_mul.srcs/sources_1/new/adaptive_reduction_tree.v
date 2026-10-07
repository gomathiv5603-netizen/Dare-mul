`timescale 1ns / 1ps

module adaptive_reduction_tree #(
    parameter USE_ADAPTIVE_REDUCTION_TREE = 1
)(
    input [31:0] partial_products,
    input [4:0] approx_region,
    output [31:0] reduced_sum
);

wire [31:0] reduction_mask;

assign reduction_mask =
    (approx_region <= 5'd1) ? 32'hFFFF_FFFF :
    ~((32'h0000_0001 << (approx_region - 1'b1)) - 1'b1);

assign reduced_sum =
    USE_ADAPTIVE_REDUCTION_TREE ?
    (partial_products & reduction_mask) :
    partial_products;

endmodule
