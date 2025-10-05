// =============================================================================
// Einsum Multiplication Module (Unified)
// Description: Registered LSE multiplication with bypass option
// Version: Unified standard interface
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module einsum_mult #(
  parameter WORD_WIDTH = 32  // Word width for operands (standardized)
)(
  input  logic                   clk,        // Clock signal (standardized name)
  input  logic                   rst,        // Synchronous reset, active high (standardized name)
  input  logic                   enable,     // Enable signal (standardized name)
  input  logic                   bypass,     // Bypass multiplier (pass through operand_a)
  input  logic [WORD_WIDTH-1:0] operand_a,  // First operand (standardized name)
  input  logic [WORD_WIDTH-1:0] operand_b,  // Second operand (standardized name)
  input  logic [1:0]             pe_mode,    // Processing element mode (standardized name)
  output logic [WORD_WIDTH-1:0] product_out // Multiplication result (standardized name)
);

  // =========================================================================
  // Internal Signals
  // =========================================================================
  logic [WORD_WIDTH-1:0] mult_result;  // Combinational multiplier output

  // =========================================================================
  // LSE Multiplier Instantiation
  // =========================================================================
  lse_mult #(
    .WIDTH(24)  // Use standardized parameter name
  ) u_lse_mult (
    .operand_a(operand_a[23:0]),     // Use standardized port names (24-bit slice)
    .operand_b(operand_b[23:0]),
    .pe_mode(pe_mode),
    .result(mult_result[23:0])       // Use standardized port name
  );

  // Clear upper bits if WORD_WIDTH > 24
  assign mult_result[WORD_WIDTH-1:24] = '0;

  // =========================================================================
  // Output Register with Bypass Logic
  // =========================================================================
  always_ff @(posedge clk) begin : einsum_mult_proc
    if (rst) begin
      // Synchronous reset: clear output
      product_out <= '0;
      
    end else if (enable) begin
      if (bypass) begin
        // Bypass mode: pass through first operand
        product_out <= operand_a;
      end else begin
        // Normal operation: use LSE multiplication result
        product_out <= mult_result;
      end
    end
    // Note: If enable is low, output maintains previous value (implicit latch behavior)
  end

endmodule : einsum_mult