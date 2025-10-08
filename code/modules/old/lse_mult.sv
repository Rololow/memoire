// =============================================================================
// Include Dependencies
// =============================================================================
`include "common_pkg.sv"
`include "utils_pkg.sv"
`include "instr_decd_pkg.sv"
`include "module_library.sv"
`include "vec_alu.sv"

// =============================================================================
// lse Multiplication Module
// Description: Performs multiplication in log-space (addition in log-domain)
//              Supports both 24-bit and 6-bit (4x packed) modes
// =============================================================================
module lse_mult #(
  parameter p_width = 24  // total bit width
)(
  input  logic [p_width-1:0] i_operand_a, // first operand (log-space)
  input  logic [p_width-1:0] i_operand_b, // second operand (log-space)
  input  logic [1:0]         i_pe_mode,   // pe mode: 0=24-bit, 1=6-bit
  output logic [p_width-1:0] o_product    // multiplication result (log-space)
);

  // 6-bit mode: split inputs into 4 sub-values
  logic [5:0] s_operand_a_packed[4];
  logic [5:0] s_operand_b_packed[4];

  always_comb begin : proc_lse_mult
    if (i_pe_mode == 0) begin
      // =====================================================================
      // 24-bit mode: single precision
      // =====================================================================
      
      // check for special value (negative infinity in log-space: 800000)
      if (i_operand_a == 24'd800000 || i_operand_b == 24'd800000) begin
        o_product = 24'd800000;  // log(0) = -inf, so result is -inf
      end else begin
        o_product = i_operand_a + i_operand_b;  // log(a*b) = log(a) + log(b)
      end
      
    end else begin
      // =====================================================================
      // 6-bit mode: 4 parallel operations
      // =====================================================================
      
      for (int i = 0; i < 4; i++) begin
        logic signed [4:0] s_magnitude_a_6, s_magnitude_b_6, s_magnitude_product_6;
        logic s_sign_a_6, s_sign_b_6, s_sign_product_6;
        
        // extract 5-bit magnitudes and sign bits
        s_magnitude_a_6 = i_operand_a[i*6 +: 5];
        s_magnitude_b_6 = i_operand_b[i*6 +: 5];
        s_sign_a_6 = i_operand_a[i*6 + 5];  // 6th bit is sign
        s_sign_b_6 = i_operand_b[i*6 + 5];
        
        // sign multiplication (xor for sign of product)
        s_sign_product_6 = s_sign_a_6 ^ s_sign_b_6;
        
        // check for special values (negative infinity: 16)
        if (s_magnitude_a_6 == 5'd16 || s_magnitude_b_6 == 5'd16) begin
          o_product[i*6 +: 6] = 6'd16;  // negative infinity
        end else begin
          s_magnitude_product_6 = s_magnitude_a_6 + s_magnitude_b_6;  // add in log-space
          o_product[i*6 +: 6] = {s_sign_product_6, s_magnitude_product_6};
        end
      end
    end
  end

endmodule : lse_mult
