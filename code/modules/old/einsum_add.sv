// =============================================================================
// Include Dependencies
// =============================================================================
`include "common_pkg.sv"
`include "utils_pkg.sv"
`include "instr_decd_pkg.sv"
`include "module_library.sv"
`include "vec_alu.sv"

// =============================================================================
// Einsum Adder Module
// Description: Performs addition in log-space (lse) with lut-based correction
// =============================================================================
module einsum_add (
  input  logic                     i_clk,       // clock signal
  input  logic                     i_rst,       // synchronous reset
  input  logic                     i_en,        // enable signal
  input  logic                     i_bypass,    // bypass adder (pass through i_operand_a)
  input  word_t                    i_operand_a, // first operand
  input  word_t                    i_operand_b, // second operand
  input  logic [1:0]               i_pe_mode,   // processing element mode
  input  logic [LUT_PRECISION-1:0] i_lut_table[LUT_SIZE],  // lut registers for error correction
  output word_t                    o_sum  // addition result
);

  logic [23:0] s_add_result;
  // lse adder instantiation
  lse_add u_lse_add (
    .i_operand_a(i_operand_a[23:0]),
    .i_operand_b(i_operand_b[23:0]),
    .i_lut_table(i_lut_table),
    .i_pe_mode(i_pe_mode),
    .o_sum(s_add_result[23:0])
  );

  // output register with bypass logic
  always_ff @(posedge i_clk) begin
    if (i_rst == RESET_STATE) begin
      o_sum <= '0;
    end else if (i_en) begin
      if (i_bypass) begin
        o_sum <= i_operand_a;  // bypass: pass through first operand
      end else begin
        o_sum[23:0] <= s_add_result;
      end
    end
  end

endmodule : einsum_add
