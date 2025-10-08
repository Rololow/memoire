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
  input  logic [1:0]       pe_mode,    // PE mode (kept for compatibility; SIMD removed)
  output logic [WIDTH-1:0] result      // Multiplication result (log-space) - standardized name
);

  // =========================================================================
  // Local Parameters
  // =========================================================================
  localparam NEG_INF_24 = 24'h800000;  // -inf for 24-bit mode

  // =========================================================================
  // Main LSE Multiplication Logic (24-bit only)
  // SIMD/packed 6-bit mode has been removed from this module.
  // The interface is preserved for compatibility but any pe_mode != 0
  // will behave like 24-bit scalar mode.
  // =========================================================================
  always_comb begin : lse_mult_proc
    // Treat any non-zero pe_mode as scalar 24-bit mode to keep compatibility
    if (operand_a == NEG_INF_24 || operand_b == NEG_INF_24) begin
      result = NEG_INF_24;  // log(0) * anything = log(0) = -inf
    end else begin
      // Standard log-space multiplication: log(a*b) = log(a) + log(b)
      result = operand_a + operand_b;
    end
  end

endmodule : lse_mult