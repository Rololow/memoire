// =============================================================================
// LSE SIMD 24-bit Module - Combinatorial Version
// Description: Simple combinatorial LSE for quick testing
// Author: LSE-PE Project
// Date: October 2025
// =============================================================================

module lse_simd_24b_comb #(
    parameter DATA_WIDTH = 24
)(
    input  wire [DATA_WIDTH-1:0] x_in,        // First operand
    input  wire [DATA_WIDTH-1:0] y_in,        // Second operand
    output wire [DATA_WIDTH-1:0] result,      // LSE result
    output wire                  overflow     // Overflow flag
);

    // =============================================================================
    // Constants
    // =============================================================================
    localparam NEG_INF = 24'h800000;  // -infinity representation
    localparam POS_SAT = 24'h7FFFFF;  // Positive saturation
    
    // =============================================================================
    // Internal Signals
    // =============================================================================
    wire                      x_larger;
    wire [DATA_WIDTH-1:0]     larger, smaller;
    wire signed [DATA_WIDTH-1:0] diff;
    wire [DATA_WIDTH-1:0]     lse_approx;
    wire [24:0]               temp_sum;
    
    // =============================================================================
    // LSE Logic (All Combinatorial)
    // =============================================================================
    
    // Compare magnitudes (handle NEG_INF specially)
    assign x_larger = (x_in == NEG_INF) ? 1'b0 :
                      (y_in == NEG_INF) ? 1'b1 :
                      (x_in >= y_in);
    
    // Select larger and smaller operands
    assign larger  = x_larger ? x_in : y_in;
    assign smaller = x_larger ? y_in : x_in;
    
    // Compute difference
    assign diff = $signed(smaller) - $signed(larger);
    
    // Improved LSE approximation 
    // LSE(x,y) = max(x,y) + log(1 + 2^(min(x,y) - max(x,y)))
    // For equal values: LSE(x,x) = x + log(1 + 2^0) = x + log(2) ≈ x + 1.0 
    // For different values: LSE(x,y) ≈ max(x,y) + small_correction
    assign lse_approx = (smaller == NEG_INF) ? 24'h000000 :                    // No contribution from -inf
                        (larger == smaller) ? 24'h000400 :                     // Equal values: add log(2) ≈ 1.0
                        (diff < -24'h002000) ? 24'h000020 :                    // Very small contribution  
                        (diff < -24'h001000) ? 24'h000080 :                    // Small contribution
                        (diff < -24'h000800) ? 24'h000200 :                    // Medium contribution
                        24'h000400;                                            // Significant contribution
    
    // Final sum with overflow check
    assign temp_sum = larger + lse_approx;
    
    // Output assignment
    assign result = (temp_sum > POS_SAT) ? POS_SAT : temp_sum[23:0];
    assign overflow = (temp_sum > POS_SAT);

endmodule