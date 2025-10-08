// =============================================================================
// Generic Register Module (Unified)
// Description: Parameterized register with synchronous reset
// Version: Unified standard interface (no dependencies)
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module register #(
  parameter WIDTH = 32  // Bit width of register (standardized parameter name)
)(
  input  logic              i_clk,    // Clock signal (standardized name)
  input  logic              i_rst,    // Synchronous reset, active high (standardized name)
  input  logic [WIDTH-1:0]  i_data_in,  // Input data (standardized name)
  output logic [WIDTH-1:0]  o_data_out // Output data, registered (standardized name)
);

  // =========================================================================
  // Internal Register Storage
  // =========================================================================
  logic [WIDTH-1:0] data_reg;

  // =========================================================================
  // Sequential Logic: Register Data on Clock Edge
  // =========================================================================
  always_ff @(posedge i_clk) begin : register_proc
    if (i_rst) begin
      // Synchronous reset: clear register to zero
      data_reg <= '0;
    end else begin
      // Normal operation: capture input data
      data_reg <= i_data_in;
    end
  end

  // =========================================================================
  // Output Assignment
  // =========================================================================
  assign o_data_out = data_reg;

endmodule : register