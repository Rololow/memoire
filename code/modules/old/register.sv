// =============================================================================
// Include Dependencies
// =============================================================================
`include "common_pkg.sv"
`include "utils_pkg.sv"
`include "instr_decd_pkg.sv"
`include "module_library.sv"
`include "vec_alu.sv"

// =============================================================================
// Generic Register Module
// Description: Parameterized register with synchronous reset
// =============================================================================
module register #(
  parameter p_width = 32  // bit width of register
) (
  input  logic              i_clk,              // clock signal
  input  logic              i_rst,              // synchronous reset (active high)
  input  logic [p_width-1:0] i_data,            // input data
  output logic [p_width-1:0] o_data             // output data (registered)
);

  // internal register storage
  logic [p_width-1:0] s_data_q;

  // sequential logic: register data on clock edge
  always_ff @(posedge i_clk) begin
    if (i_rst) begin
      s_data_q <= '0;  // reset to zero
    end else begin
      s_data_q <= i_data;  // capture input
    end
  end

  // output assignment
  assign o_data = s_data_q;

endmodule : register
