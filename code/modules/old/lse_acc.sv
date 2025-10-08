// =============================================================================
// Include Dependencies
// =============================================================================
`include "common_pkg.sv"
`include "utils_pkg.sv"
`include "instr_decd_pkg.sv"
`include "module_library.sv"
`include "vec_alu.sv"

// =============================================================================
// lse Accumulator Module
// Description: 16-bit lse addition for accumulation operations
//              Similar to lse_add but optimized for 16-bit accumulation
// =============================================================================
module lse_acc #(
  parameter p_int_bits  = 12,  // integer bits
  parameter p_frac_bits = 3    // fractional bits
)(
  input  logic [p_int_bits+p_frac_bits:0] i_accumulator,  // accumulator input (with sign bit)
  input  logic [p_int_bits+p_frac_bits:0] i_addend,       // value to add (with sign bit)
  output logic [p_int_bits+p_frac_bits:0] o_accumulator   // accumulator output
);

  // internal signals (without sign bit)
  logic signed [p_int_bits+p_frac_bits-1:0] s_magnitude_acc, s_magnitude_add;
  logic signed [p_int_bits+p_frac_bits-1:0] s_larger_16, s_smaller_16;
  logic signed [p_int_bits+p_frac_bits-1:0] s_diff_16, s_mantissa_diff_16;
  logic signed [p_int_bits+p_frac_bits-1:0] s_mantissa_sum_16, s_mantissa_shifted_16;
  logic signed [p_int_bits-1:0]             s_exponent_diff_16;
  logic                                     s_sign_acc, s_sign_add, s_sign_result;

  always_comb begin
    // handle special values (negative infinity: 0100000000000000)
    if (i_accumulator == 16'b0100000000000000) begin
      o_accumulator = i_addend;
    end else if (i_addend == 16'b0100000000000000) begin
      o_accumulator = i_accumulator;
    end else begin
      // extract sign bits
      s_sign_acc = i_accumulator[p_int_bits+p_frac_bits];
      s_sign_add = i_addend[p_int_bits+p_frac_bits];
      
      // extract magnitude (lower bits)
      s_magnitude_acc = i_accumulator[p_int_bits+p_frac_bits-1:0];
      s_magnitude_add = i_addend[p_int_bits+p_frac_bits-1:0];
      
      // find larger and smaller magnitudes
      s_larger_16 = (s_magnitude_acc > s_magnitude_add) ? s_magnitude_acc : s_magnitude_add;
      s_smaller_16 = (s_magnitude_acc < s_magnitude_add) ? s_magnitude_acc : s_magnitude_add;
      
      // lse computation
      s_diff_16 = s_smaller_16 - s_larger_16;
      s_exponent_diff_16 = s_diff_16[p_int_bits+p_frac_bits-1:p_frac_bits];
      s_mantissa_diff_16 = s_diff_16 - (s_exponent_diff_16 <<< p_frac_bits);
      s_mantissa_sum_16 = (1 <<< p_frac_bits) + s_mantissa_diff_16;
      s_mantissa_shifted_16 = s_mantissa_sum_16 >>> -s_exponent_diff_16;
      
      // handle sign logic
      if (s_sign_acc == s_sign_add) begin
        // same sign: addition
        s_sign_result = s_sign_acc;
        o_accumulator = {s_sign_result, s_mantissa_shifted_16 + s_larger_16};
      end else begin
        // different signs: subtraction
        s_sign_result = (s_magnitude_acc >= s_magnitude_add) ? s_sign_acc : s_sign_add;
        o_accumulator = {s_sign_result, s_larger_16 - s_mantissa_shifted_16};
      end
    end
  end

endmodule : lse_acc
