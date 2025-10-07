// =============================================================================
// LSE Addition Module (LSE-PE Implementation)
// Description: Implements Algorithm 1 from "LSE-PE: Hardware Efficient for 
//              Tractable Probabilistic Reasoning" (Yao et al., NeurIPS 2024)
// Version: Algorithm-compliant implementation with CLUT support
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module lse_add #(
    parameter WIDTH = 24,
    parameter LUT_SIZE = 1024,
    parameter LUT_PRECISION = 10,
    parameter FRAC_BITS = 10  // Number of fractional bits for CLUT addressing
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
    // Parameters for LSE-PE Algorithm
    // =========================================================================
    localparam NEG_INF_VAL = {1'b1, {(WIDTH-1){1'b0}}}; // MSB=1, others=0
    localparam INT_BITS = WIDTH - FRAC_BITS;  // Integer bits
    localparam CLUT_ADDR_BITS = 4; // 16-entry CLUT (2^4)
    
    // =========================================================================
    // Internal Signals for Synchronous Processing
    // =========================================================================
    logic [WIDTH-1:0] result_next;
    
    // =========================================================================
    // Mode-Based Addition Logic
    // =========================================================================
    always_comb begin : lse_add_comb
        
        case (pe_mode)
            2'b00: begin // 24-bit LSE mode implementing Algorithm 1
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
                    // =============================================================
                    // Algorithm 1: LSE-PE Implementation
                    // =============================================================
                    
                    // Declare all variables first (SystemVerilog requirement)
                    logic [WIDTH-1:0] x, y;
                    logic signed [WIDTH:0] sub;
                    logic signed [INT_BITS-1:0] I_yx;
                    logic [FRAC_BITS-1:0] F_yx;
                    logic [WIDTH-1:0] one_plus_frac;
                    logic [WIDTH-1:0] f_tilde;
                    logic [5:0] shift_amount;
                    logic [CLUT_ADDR_BITS-1:0] clut_addr;
                    logic [LUT_PRECISION-1:0] clut_correction;
                    logic [$clog2(LUT_SIZE)-1:0] scaled_addr;
                    logic [WIDTH:0] temp_result;
                    
                    // Step 1-2: Determine x (larger) and y (smaller), assume x ≥ y
                    if (operand_a >= operand_b) begin
                        x = operand_a;
                        y = operand_b;
                    end else begin
                        x = operand_b;
                        y = operand_a;
                    end
                    
                    // Step 3: Sub ← y - x (always ≤ 0)
                    sub = $signed({1'b0, y}) - $signed({1'b0, x});
                    
                    // Step 4: Extract I(y-x) (integer part) and F(y-x) (fractional part)
                    // Format: [INT_BITS].[FRAC_BITS]
                    I_yx = sub[WIDTH:FRAC_BITS];       // Upper bits = integer
                    F_yx = sub[FRAC_BITS-1:0];         // Lower bits = fractional
                    
                    // Step 5-6: Two-stage approximation
                    // ˜f(y-x) ← (1 + F(y-x)) ≫ (-I(y-x))
                    
                    // Compute (1 + F(y-x))
                    // "1" in fixed-point is 2^FRAC_BITS
                    one_plus_frac = {{(INT_BITS-1){1'b0}}, 1'b1, F_yx};
                    
                    // Right shift by (-I(y-x))
                    // Since I(y-x) is negative, -I(y-x) is positive
                    shift_amount = (-I_yx < 6'd24) ? -I_yx[5:0] : 6'd24; // Cap at 24 bits
                    
                    f_tilde = one_plus_frac >> shift_amount;
                    
                    // Step 7: Error correction using CLUT
                    // CLUT address: Use top CLUT_ADDR_BITS of f_tilde's fractional part
                    
                    // Extract bits for CLUT addressing from fractional part
                    clut_addr = f_tilde[FRAC_BITS-1:FRAC_BITS-CLUT_ADDR_BITS];
                    
                    // Read correction from CLUT (map to actual LUT_SIZE)
                    if (CLUT_ADDR_BITS < $clog2(LUT_SIZE)) begin
                        // Scale address to LUT_SIZE
                        scaled_addr = clut_addr << ($clog2(LUT_SIZE) - CLUT_ADDR_BITS);
                        clut_correction = lut_table[scaled_addr];
                    end else begin
                        clut_correction = lut_table[clut_addr];
                    end
                    
                    // Step 8: return x + ˜f(y-x) + CLUT(˜f(y-x))
                    temp_result = x + f_tilde + {{(WIDTH-LUT_PRECISION){1'b0}}, clut_correction};
                    
                    // Overflow protection: saturate to maximum value
                    if (temp_result[WIDTH]) begin  // Overflow detected
                        result_next = {WIDTH{1'b1}};
                    end else begin
                        result_next = temp_result[WIDTH-1:0];
                    end
                end
            end
            
            2'b01: begin // 4x6-bit SIMD addition mode
                // Extract 4 lanes of 6 bits each
                logic [5:0] a_lane0, a_lane1, a_lane2, a_lane3;
                logic [5:0] b_lane0, b_lane1, b_lane2, b_lane3;
                logic [5:0] sum_lane0, sum_lane1, sum_lane2, sum_lane3;
                
                // Extract lanes from operands (24-bit = 4x6-bit)
                a_lane0 = operand_a[5:0];
                a_lane1 = operand_a[11:6];
                a_lane2 = operand_a[17:12];
                a_lane3 = operand_a[23:18];
                
                b_lane0 = operand_b[5:0];
                b_lane1 = operand_b[11:6];
                b_lane2 = operand_b[17:12];
                b_lane3 = operand_b[23:18];
                
                // Perform saturated addition on each 6-bit lane
                sum_lane0 = (a_lane0 + b_lane0 > 6'h3F) ? 6'h3F : (a_lane0 + b_lane0);
                sum_lane1 = (a_lane1 + b_lane1 > 6'h3F) ? 6'h3F : (a_lane1 + b_lane1);
                sum_lane2 = (a_lane2 + b_lane2 > 6'h3F) ? 6'h3F : (a_lane2 + b_lane2);
                sum_lane3 = (a_lane3 + b_lane3 > 6'h3F) ? 6'h3F : (a_lane3 + b_lane3);
                
                // Pack result back into 24-bit output
                result_next = {sum_lane3, sum_lane2, sum_lane1, sum_lane0};
            end
            
            default: begin // Fallback to 24-bit mode
                result_next = operand_a + operand_b;
            end
        endcase
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
    
    // =========================================================================
    // Verification and Debug Support
    // =========================================================================
    `ifdef DEBUG_LSE_ADD
        always_ff @(posedge clk) begin
            if (enable && pe_mode == 2'b00 && 
                operand_a != NEG_INF_VAL && operand_b != NEG_INF_VAL) begin
                $display("[LSE_ADD] Time=%0t: a=%h, b=%h, result=%h", 
                         $time, operand_a, operand_b, result_next);
            end
        end
    `endif
    
    `ifdef ASSERTIONS_ON
        // Verify that result is monotonic: LSE(a,b) ≥ max(a,b)
        property p_lse_monotonic;
            @(posedge clk) disable iff (rst)
            (enable && pe_mode == 2'b00 && valid_out &&
             operand_a != NEG_INF_VAL && operand_b != NEG_INF_VAL) 
            |-> (result >= operand_a) && (result >= operand_b);
        endproperty
        assert property (p_lse_monotonic) 
            else $error("LSE result %h not monotonic for inputs a=%h, b=%h", 
                        result, operand_a, operand_b);
        
        // Verify commutative property: LSE(a,b) = LSE(b,a)
        property p_lse_commutative;
            logic [WIDTH-1:0] a_saved, b_saved, result_saved;
            @(posedge clk) disable iff (rst)
            (enable && pe_mode == 2'b00, 
             a_saved = operand_a, b_saved = operand_b, result_saved = result) 
            ##1 (enable && pe_mode == 2'b00 && 
                 operand_a == b_saved && operand_b == a_saved)
            |-> (result == result_saved);
        endproperty
        // Note: This assertion is informational and may not fire in typical operation
        
    `endif
    
endmodule : lse_add