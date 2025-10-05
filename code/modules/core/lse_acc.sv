// =============================================================================
// LSE Accumulator Module (Unified)
// Description: 16-bit LSE addition optimized for accumulation operations
//              Handles log-space addition with fixed-point arithmetic
// Version: Unified standard interface
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module lse_acc #(
  parameter INT_BITS  = 12,  // Integer bits (standardized name)
  parameter FRAC_BITS = 3,   // Fractional bits (standardized name)
  parameter WIDTH = INT_BITS + FRAC_BITS + 1  // Total width including sign
)(
  input  logic [WIDTH-1:0] accumulator_in,  // Accumulator input (standardized name)
  input  logic [WIDTH-1:0] addend_in,       // Value to add (standardized name)
  output logic [WIDTH-1:0] accumulator_out  // Accumulator output (standardized name)
);

  // =========================================================================
  // Local Parameters (Standardized)
  // =========================================================================
  localparam NEG_INF_16 = 16'b0100000000000000;  // -inf for 16-bit accumulator
  localparam MAGNITUDE_BITS = INT_BITS + FRAC_BITS;
  localparam FRAC_SCALE = 1 << FRAC_BITS;  // 2^FRAC_BITS for scaling

  // =========================================================================
  // Internal Signals
  // =========================================================================
  logic signed [MAGNITUDE_BITS-1:0] mag_acc, mag_add;
  logic signed [MAGNITUDE_BITS-1:0] larger_mag, smaller_mag;
  logic signed [MAGNITUDE_BITS-1:0] diff_mag, mantissa_diff;
  logic signed [MAGNITUDE_BITS-1:0] mantissa_sum, mantissa_shifted;
  logic signed [INT_BITS-1:0] exponent_diff;
  logic sign_acc, sign_add, sign_result;

  // =========================================================================
  // Main LSE Accumulation Logic
  // =========================================================================
  always_comb begin : lse_acc_proc
    
    // Check for special values (negative infinity)
    if (accumulator_in == NEG_INF_16) begin
      // If accumulator is -inf, result is the addend
      accumulator_out = addend_in;
      
    end else if (addend_in == NEG_INF_16) begin
      // If addend is -inf, result is the accumulator
      accumulator_out = accumulator_in;
      
    end else begin
      // =====================================================================
      // Normal LSE Addition Process
      // =====================================================================
      
      // Extract sign bits (MSB)
      sign_acc = accumulator_in[WIDTH-1];
      sign_add = addend_in[WIDTH-1];
      
      // Extract magnitudes (all bits except sign)
      mag_acc = accumulator_in[MAGNITUDE_BITS-1:0];
      mag_add = addend_in[MAGNITUDE_BITS-1:0];
      
      // Determine larger and smaller magnitudes for LSE computation
      if (mag_acc > mag_add) begin
        larger_mag  = mag_acc;
        smaller_mag = mag_add;
      end else begin
        larger_mag  = mag_add;
        smaller_mag = mag_acc;
      end
      
      // LSE approximation computation
      diff_mag = smaller_mag - larger_mag;
      exponent_diff = diff_mag[MAGNITUDE_BITS-1:FRAC_BITS];
      mantissa_diff = diff_mag - (exponent_diff << FRAC_BITS);
      mantissa_sum = FRAC_SCALE + mantissa_diff;
      
      // Shift mantissa based on exponent difference
      // Note: Using arithmetic right shift for proper sign extension
      if (exponent_diff < 0) begin
        mantissa_shifted = mantissa_sum >> (-exponent_diff);
      end else begin
        mantissa_shifted = mantissa_sum;
      end
      
      // Handle sign logic and final computation
      if (sign_acc == sign_add) begin
        // Same signs: LSE addition
        sign_result = sign_acc;
        accumulator_out = {sign_result, mantissa_shifted + larger_mag};
        
      end else begin
        // Different signs: LSE subtraction
        // Result sign follows the larger magnitude's original sign
        sign_result = (mag_acc >= mag_add) ? sign_acc : sign_add;
        
        // Compute absolute difference
        if (larger_mag >= mantissa_shifted) begin
          accumulator_out = {sign_result, larger_mag - mantissa_shifted};
        end else begin
          // Handle underflow case
          accumulator_out = NEG_INF_16;
        end
      end
    end
  end

endmodule : lse_acc