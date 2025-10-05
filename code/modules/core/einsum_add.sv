// =============================================================================
// Einsum Addition Module (Unified)
// Description: Registered LSE addition with LUT-based correction and bypass
// Version: Unified standard interface
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module einsum_add #(
  parameter LUT_SIZE      = 1024,  // LUT table size (number of entries)
  parameter LUT_PRECISION = 10,    // LUT entry precision (bits)
  parameter WORD_WIDTH    = 32     // Word width for operands (standardized)
)(
  input  logic                     clk,        // Clock signal (standardized name)
  input  logic                     rst,        // Synchronous reset, active high (standardized name)
  input  logic                     enable,     // Enable signal (standardized name)
  input  logic                     bypass,     // Bypass adder (pass through operand_a)
  input  logic [WORD_WIDTH-1:0]   operand_a,  // First operand (standardized name)
  input  logic [WORD_WIDTH-1:0]   operand_b,  // Second operand (standardized name)
  input  logic [1:0]               pe_mode,    // Processing element mode (standardized name)
  input  logic [LUT_PRECISION-1:0] lut_table[LUT_SIZE],  // LUT registers for error correction
  output logic [WORD_WIDTH-1:0]   sum_out     // Addition result (standardized name)
);

  // =========================================================================
  // Internal Signals
  // =========================================================================
  logic [23:0] add_result_24;  // 24-bit result from LSE adder
  
  // =========================================================================
  // LSE Adder Instantiation
  // =========================================================================
  lse_add #(
    .LUT_SIZE(LUT_SIZE),
    .LUT_PRECISION(LUT_PRECISION),
    .WIDTH(24)  // Use standardized parameter names
  ) u_lse_add (
    .operand_a(operand_a[23:0]),     // Use standardized port names
    .operand_b(operand_b[23:0]),
    .lut_table(lut_table),
    .pe_mode(pe_mode),
    .result(add_result_24)           // Use standardized port name
  );

  // =========================================================================
  // Output Register with Bypass Logic
  // =========================================================================
  always_ff @(posedge clk) begin : einsum_add_proc
    if (rst) begin
      // Synchronous reset: clear output
      sum_out <= '0;
      
    end else if (enable) begin
      if (bypass) begin
        // Bypass mode: pass through first operand
        sum_out <= operand_a;
      end else begin
        // Normal operation: use LSE addition result
        sum_out[23:0] <= add_result_24;
        sum_out[WORD_WIDTH-1:24] <= '0;  // Clear upper bits if WORD_WIDTH > 24
      end
    end
    // Note: If enable is low, output maintains previous value (implicit latch behavior)
  end

endmodule : einsum_add