// =============================================================================
// Include Dependencies
// =============================================================================
`include "common_pkg.sv"
`include "utils_pkg.sv"
`include "instr_decd_pkg.sv"
`include "module_library.sv"
`include "vec_alu.sv"

// =============================================================================
// Einsum Multiplier Module
// Description: Performs multiplication in log-space (lse) with bypass option
// =============================================================================
module einsum_mult (
  input  logic       i_clk,       // clock signal
  input  logic       i_rst,       // synchronous reset
  input  logic       i_en,        // enable signal
  input  logic       i_bypass,    // bypass multiplier (pass through i_operand_a)
  input  word_t      i_operand_a, // first operand
  input  word_t      i_operand_b, // second operand
  input  logic [1:0] i_pe_mode,   // processing element mode (0: 24-bit, 1: 6-bit packed)
  output word_t      o_product    // multiplication result
);

  // internal signals
  word_t s_mult_result;  // combinational multiplier output

  // lse multiplier instantiation (24-bit width)
  lse_mult #(
    .p_width(24)
  ) u_lse_mul (
    .i_operand_a(i_operand_a),
    .i_operand_b(i_operand_b),
    .i_pe_mode(i_pe_mode),
    .o_product(s_mult_result)
  );

  // output register with bypass logic
  always_ff @(posedge i_clk) begin
    if (i_rst == RESET_STATE) begin
      o_product <= '0;
    end else if (i_en) begin
      if (i_bypass) begin
        o_product <= i_operand_a;  // bypass: pass through first operand
      end else begin
        o_product <= s_mult_result;  // normal operation
      end
    end
  end

endmodule : einsum_mult
