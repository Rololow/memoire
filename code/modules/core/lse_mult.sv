// =============================================================================
// LSE Multiplication Module (Unified)
// Description: Performs multiplication in log-space (addition in log-domain)
//              Supports both 24-bit and 6-bit (4x packed) modes
// Version: Unified standard interface
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module lse_mult #(
  parameter WIDTH = 24  // Total bit width (standardized parameter name)
)(
  input  logic [WIDTH-1:0] operand_a,  // First operand (log-space) - standardized name
  input  logic [WIDTH-1:0] operand_b,  // Second operand (log-space) - standardized name
  input  logic [1:0]       pe_mode,    // PE mode: 0=24-bit, 1=6-bit - standardized name
  output logic [WIDTH-1:0] result      // Multiplication result (log-space) - standardized name
);

  // =========================================================================
  // Local Parameters (Standardized)
  // =========================================================================
  localparam NEG_INF_24 = 24'h800000;  // -inf for 24-bit mode
  localparam NEG_INF_6  = 6'b010000;   // -inf for 6-bit mode (16)
  localparam SUBWIDTH   = 6;            // Width of each 6-bit subvalue
  localparam NUM_SUB    = 4;            // Number of subvalues in 6-bit mode

  // =========================================================================
  // Main LSE Multiplication Logic
  // =========================================================================
  always_comb begin : lse_mult_proc
    
    if (pe_mode == 2'b00) begin
      // =====================================================================
      // 24-bit Mode: Single Precision Operation
      // =====================================================================
      
      // Check for special values (negative infinity)
      if (operand_a == NEG_INF_24 || operand_b == NEG_INF_24) begin
        result = NEG_INF_24;  // log(0) * anything = log(0) = -inf
      end else begin
        // Standard log-space multiplication: log(a*b) = log(a) + log(b)
        result = operand_a + operand_b;
      end
      
    end else begin
      // =====================================================================
      // 6-bit Mode: 4 Parallel Operations
      // =====================================================================
      
      // Process each 6-bit subvalue independently
      for (int i = 0; i < NUM_SUB; i++) begin
        logic [4:0] mag_a, mag_b, mag_result;
        logic sign_a, sign_b, sign_result;
        
        // Extract 5-bit magnitude and 1-bit sign for each subvalue
        mag_a   = operand_a[i*SUBWIDTH +: 5];  // Bits [4:0] of subvalue
        sign_a  = operand_a[i*SUBWIDTH + 5];   // Bit [5] is sign
        mag_b   = operand_b[i*SUBWIDTH +: 5];  // Bits [4:0] of subvalue  
        sign_b  = operand_b[i*SUBWIDTH + 5];   // Bit [5] is sign
        
        // Sign calculation: XOR for multiplication
        sign_result = sign_a ^ sign_b;
        
        // Check for special values (negative infinity in 6-bit: magnitude = 16)
        if (mag_a == 5'd16 || mag_b == 5'd16) begin
          result[i*SUBWIDTH +: SUBWIDTH] = NEG_INF_6;
        end else begin
          // Log-space multiplication: add magnitudes
          mag_result = mag_a + mag_b;
          
          // Overflow protection for 5-bit magnitude
          if (mag_result > 5'd15) begin
            mag_result = 5'd15;  // Saturate at maximum value
          end
          
          // Combine sign and magnitude
          result[i*SUBWIDTH +: SUBWIDTH] = {sign_result, mag_result};
        end
      end
    end
  end

endmodule : lse_mult