// =============================================================================
// Include Dependencies
// =============================================================================
`include "common_pkg.sv"
`include "utils_pkg.sv"
`include "instr_decd_pkg.sv"
`include "module_library.sv"
`include "vec_alu.sv"

// =============================================================================
// lse Addition Module
// Description: log-sum-exp addition with lut-based error correction
//              Supports both 24-bit and 6-bit (4x packed) modes
// =============================================================================
module lse_add #(
  parameter p_int_bits_24    = 14,  // integer bits for 24-bit mode
  parameter p_frac_bits_24   = 10,  // fractional bits for 24-bit mode
  parameter p_int_bits_6     = 4,   // integer bits for 6-bit mode
  parameter p_frac_bits_6    = 1    // fractional bits for 6-bit mode
)(
  input  logic [p_int_bits_24+p_frac_bits_24-1:0] i_operand_a,       // first operand
  input  logic [p_int_bits_24+p_frac_bits_24-1:0] i_operand_b,       // second operand
  input  logic [LUT_PRECISION-1:0]                i_lut_table[LUT_SIZE], // lut for error correction
  input  logic [1:0]                              i_pe_mode,         // pe mode: 0=24-bit, 1=6-bit
  output logic [p_int_bits_24+p_frac_bits_24-1:0] o_sum              // addition result
);

  // local parameters
  localparam p_lut_addr_width = $clog2(LUT_SIZE);

  // -------------------------------------------------------------------------
  // 24-bit mode signals
  // -------------------------------------------------------------------------
  logic signed [p_int_bits_24+p_frac_bits_24-1:0] s_larger_24, s_smaller_24;  // max and min of inputs
  logic signed [p_int_bits_24+p_frac_bits_24-1:0] s_diff_24;                  // difference (smaller - larger)
  logic signed [p_int_bits_24+p_frac_bits_24-1:0] s_mantissa_diff_24;         // mantissa of difference
  logic signed [p_int_bits_24+p_frac_bits_24-1:0] s_mantissa_sum_24;          // 1 + mantissa
  logic signed [p_int_bits_24+p_frac_bits_24-1:0] s_mantissa_shifted_24;      // mantissa shifted by exponent
  logic signed [p_int_bits_24-1:0]                s_exponent_diff_24;          // exponent of difference
  logic signed [p_frac_bits_24-1:0]               s_error_correction_24;       // error correction from lut
  logic signed [p_frac_bits_24-1:0]               s_next_error_corr_24;        // next lut entry
  logic signed [p_frac_bits_24-1:0]               s_interpolation_24;          // interpolation result
  logic signed [p_frac_bits_24-1:0]               s_final_error_corr_24;       // final error correction
  logic        [p_frac_bits_24-p_lut_addr_width-1:0] s_lut_residual_24;        // lut key residual
  logic        [p_lut_addr_width-1:0]             s_lut_index;                 // lut address
  logic        [LUT_PRECISION-1:0]                s_lut_values[2];             // lut entries (current and next)
  logic signed [2*p_frac_bits_24-p_lut_addr_width-1:0] s_interp_product;      // temporary interpolation value

  // -------------------------------------------------------------------------
  // 6-bit mode signals (4 parallel operations)
  // -------------------------------------------------------------------------
  logic [5:0] s_operand_a_packed[4];  // input a split into 4x 6-bit values
  logic [5:0] s_operand_b_packed[4];  // input b split into 4x 6-bit values
  logic [3:0] s_compare_results;      // comparison results for each sub-operation

  logic signed [p_int_bits_6+p_frac_bits_6-1:0] s_magnitude_a_6[4], s_magnitude_b_6[4];
  logic signed [p_int_bits_6+p_frac_bits_6-1:0] s_larger_6[4], s_smaller_6[4];
  logic signed [p_int_bits_6+p_frac_bits_6-1:0] s_diff_6[4], s_mantissa_diff_6[4];
  logic signed [p_int_bits_6+p_frac_bits_6-1:0] s_mantissa_sum_6[4], s_mantissa_shifted_6[4];
  logic signed [p_int_bits_6-1:0]               s_exponent_diff_6[4];
  logic                                         s_sign_a_6[4], s_sign_b_6[4], s_sign_result_6[4];

  // lut access
  assign s_lut_values[0] = i_lut_table[s_lut_index];
  assign s_lut_values[1] = i_lut_table[s_lut_index + 1];

  // -------------------------------------------------------------------------
  // combinational logic
  // -------------------------------------------------------------------------
  always_comb begin
    // split inputs into 6-bit sub-values for parallel processing
    for (int i = 0; i < 4; i++) begin
      s_operand_a_packed[i] = i_operand_a[i*6 +: 6];
      s_operand_b_packed[i] = i_operand_b[i*6 +: 6];
      s_compare_results[i] = s_operand_a_packed[i] > s_operand_b_packed[i];
    end

    if (i_pe_mode == 0) begin
      // =====================================================================
      // 24-bit mode: full precision lse addition
      // =====================================================================
      
      // find larger and smaller of inputs
      s_larger_24 = (i_operand_a > i_operand_b) ? i_operand_a : i_operand_b;
      s_smaller_24 = (i_operand_a < i_operand_b) ? i_operand_a : i_operand_b;
      
      // calculate difference in log-space
      s_diff_24 = s_smaller_24 - s_larger_24;
      
      // extract exponent (integer part)
      s_exponent_diff_24 = s_diff_24[p_int_bits_24+p_frac_bits_24-1:p_frac_bits_24];
      
      // extract mantissa (fractional part)
      s_mantissa_diff_24 = s_diff_24[p_frac_bits_24-1:0];
      
      // compute mantissa_sum = 1 + mantissa_diff
      s_mantissa_sum_24 = (1 <<< p_frac_bits_24) + s_mantissa_diff_24;
      
      // shift mantissa by exponent (arithmetic right shift)
      s_mantissa_shifted_24 = s_mantissa_sum_24 >>> -s_exponent_diff_24;
      
      // lut lookup for error correction
      s_lut_index = s_mantissa_shifted_24[p_frac_bits_24-1:p_frac_bits_24-p_lut_addr_width];
      s_lut_residual_24 = s_mantissa_shifted_24[p_frac_bits_24-p_lut_addr_width-1:0];
      s_error_correction_24 = s_lut_values[0];
      s_next_error_corr_24 = (&s_lut_index) ? s_lut_values[0] : s_lut_values[1];
      
      // linear interpolation between lut entries
      s_interp_product = (s_next_error_corr_24 - s_error_correction_24) * s_lut_residual_24;
      s_interpolation_24 = s_interp_product >>> (p_frac_bits_24 - p_lut_addr_width);
      s_final_error_corr_24 = s_error_correction_24 + s_interpolation_24;
      
      // handle special values (negative infinity representation: 800000)
      if (i_operand_a == 24'd800000) begin
        o_sum = i_operand_b;  // -inf + x = x
      end else if (i_operand_b == 24'd800000) begin
        o_sum = i_operand_a;  // x + (-inf) = x
      end else begin
        // final lse computation with error correction
        o_sum = s_smaller_24 - s_mantissa_shifted_24 - 
                {{p_int_bits_24{s_final_error_corr_24[p_frac_bits_24-1]}}, s_final_error_corr_24};
      end

    end else begin
      // =====================================================================
      // 6-bit mode: 4 parallel lse additions
      // =====================================================================
      
      for (int i = 0; i < 4; i++) begin
        // extract 5-bit magnitudes and sign bits
        s_magnitude_a_6[i] = i_operand_a[i*6 +: 5];
        s_magnitude_b_6[i] = i_operand_b[i*6 +: 5];
        s_sign_a_6[i] = i_operand_a[i*6 + 5];  // 6th bit is sign
        s_sign_b_6[i] = i_operand_b[i*6 + 5];
        
        // find larger and smaller magnitudes
        s_larger_6[i] = (s_magnitude_a_6[i] > s_magnitude_b_6[i]) ? s_magnitude_a_6[i] : s_magnitude_b_6[i];
        s_smaller_6[i] = (s_magnitude_a_6[i] < s_magnitude_b_6[i]) ? s_magnitude_a_6[i] : s_magnitude_b_6[i];
        
        // lse computation (simplified without lut)
        s_diff_6[i] = s_smaller_6[i] - s_larger_6[i];
        s_exponent_diff_6[i] = s_diff_6[i][p_int_bits_6+p_frac_bits_6-1:p_frac_bits_6];
        s_mantissa_diff_6[i] = s_diff_6[i] - (s_exponent_diff_6[i] <<< p_frac_bits_6);
        s_mantissa_sum_6[i] = (1 <<< p_frac_bits_6) + s_mantissa_diff_6[i];
        s_mantissa_shifted_6[i] = s_mantissa_sum_6[i] >>> -s_exponent_diff_6[i];
        
        // handle sign logic and special values
        if (s_sign_a_6[i] == s_sign_b_6[i]) begin
          // same sign: direct addition in log-space
          s_sign_result_6[i] = s_sign_a_6[i];
          
          if (s_magnitude_a_6[i] == 5'd16) begin  // special value (negative infinity)
            o_sum[i*6 +: 6] = {s_sign_b_6[i], s_magnitude_b_6[i]};
          end else if (s_magnitude_b_6[i] == 5'd16) begin
            o_sum[i*6 +: 6] = {s_sign_a_6[i], s_magnitude_a_6[i]};
          end else begin
            o_sum[i*6 +: 6] = {s_sign_result_6[i], s_mantissa_shifted_6[i] + s_larger_6[i]};
          end
          
        end else begin
          // different signs: subtraction in log-space
          s_sign_result_6[i] = (s_magnitude_a_6[i] >= s_magnitude_b_6[i]) ? s_sign_a_6[i] : s_sign_b_6[i];
          
          if (s_magnitude_a_6[i] == 5'd16) begin
            o_sum[i*6 +: 6] = {s_sign_b_6[i], s_magnitude_b_6[i]};
          end else if (s_magnitude_b_6[i] == 5'd16) begin
            o_sum[i*6 +: 6] = {s_sign_a_6[i], s_magnitude_a_6[i]};
          end else begin
            o_sum[i*6 +: 6] = {s_sign_result_6[i], s_larger_6[i] - s_mantissa_shifted_6[i]};
          end
        end
      end
    end
  end

endmodule : lse_add
