// =============================================================================
// LSE Addition Module (Width-Adaptive)
// Description: LSE addition with automatic width adaptation
// Version: Unified standard interface - Width-adaptive implementation
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module lse_add #(
    parameter WIDTH = 24,
    parameter LUT_SIZE = 1024,
    parameter LUT_PRECISION = 10
)(
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic [WIDTH-1:0] operand_a,
    input  logic [WIDTH-1:0] operand_b,
    input  logic [LUT_PRECISION-1:0] lut_table [LUT_SIZE],
    input  logic [1:0] pe_mode,
    output logic [WIDTH-1:0] result,
    output logic valid_out
);

    // =========================================================================
    // Width-Adaptive Parameters
    // =========================================================================
    localparam NEG_INF_VAL = {1'b1, {(WIDTH-1){1'b0}}}; // MSB=1, others=0
    localparam SMALL_CORRECTION = WIDTH/8; // Adaptive correction based on width
    localparam DIFF_THRESHOLD = -(2**(WIDTH-4)); // Adaptive threshold
    
    // =========================================================================
    // Internal Signals for Synchronous Processing
    // =========================================================================
    logic [WIDTH-1:0] result_next;
    
    // =========================================================================
    // Combinational LSE Logic (Width-Adaptive)
    // =========================================================================
    always_comb begin : lse_add_comb
        
        // Check for special values (negative infinity)
        if (operand_a == NEG_INF_VAL || operand_b == NEG_INF_VAL) begin
            if (operand_a == NEG_INF_VAL && operand_b == NEG_INF_VAL) begin
                result_next = NEG_INF_VAL;  // -inf + (-inf) = -inf
            end else if (operand_a == NEG_INF_VAL) begin
                result_next = operand_b;    // -inf + x = x
            end else begin
                result_next = operand_a;    // x + (-inf) = x
            end
        end else begin
            // Standard LSE addition: log(exp(a) + exp(b))
            // Simple approximation: max(a,b) + log(1 + exp(-|a-b|))
            logic [WIDTH-1:0] larger, smaller;
            logic signed [WIDTH:0] diff; // One bit wider for proper signed arithmetic
            
            if (operand_a >= operand_b) begin
                larger = operand_a;
                smaller = operand_b;
            end else begin
                larger = operand_b;
                smaller = operand_a;
            end
            
            diff = $signed({1'b0, smaller}) - $signed({1'b0, larger}); // Always ≤ 0
            
            // LSE approximation with width-adaptive correction
            if (diff > DIFF_THRESHOLD) begin
                // Significant contribution from smaller value
                if (larger <= ({{(WIDTH-4){1'b1}}, 4'b0000}) - SMALL_CORRECTION) begin
                    result_next = larger + WIDTH'(SMALL_CORRECTION); // Add correction, avoid overflow
                end else begin
                    result_next = {WIDTH{1'b1}}; // Saturate to maximum value
                end
            end else begin
                // Very small contribution, ignore smaller value
                result_next = larger;
            end
        end
    end
    
    // =========================================================================
    // Synchronous Output Register
    // =========================================================================
    always_ff @(posedge clk) begin : lse_add_sync
        if (rst) begin
            result <= '0;
            valid_out <= 1'b0;
        end else if (enable) begin
            result <= result_next;
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end
    
endmodule : lse_add