`timescale 1ns / 1ps

module partial_product_generator(
    input [15:0] A,
    input [15:0] B,
    input [4:0] exact_region,
    input [4:0] approx_region,
    output [31:0] partial_products
);

wire [31:0] exact_product;
wire [31:0] approx_mask;
wire [31:0] truncated_product;
wire [31:0] rounding_value;

assign exact_product = A * B;

assign approx_mask =
    (approx_region == 5'd0) ? 32'hFFFF_FFFF :
    ~((32'h0000_0001 << approx_region) - 1'b1);

assign truncated_product = exact_product & approx_mask;

assign rounding_value =
    ((approx_region != 5'd0) && (exact_region >= 5'd15)) ?
    (32'h0000_0001 << (approx_region - 1'b1)) :
    32'd0;

assign partial_products = truncated_product + rounding_value;

endmodule
