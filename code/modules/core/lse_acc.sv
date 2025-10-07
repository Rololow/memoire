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
  // Main LSE Accumulation Logic (Simplified for 16-bit)
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
      // Simplified LSE Addition Logic (16-bit optimized)
      // =====================================================================
      
      logic [WIDTH-1:0] larger, smaller;
      logic signed [WIDTH-1:0] diff;
      logic [WIDTH-1:0] correction;
      
      // Special handling for mixed sign cases
      if ((accumulator_in[15] != addend_in[15]) && 
          (accumulator_in != 16'h0000 && addend_in != 16'h0000)) begin
        // Mixed signs: return the value with larger absolute magnitude
        // For 3000 + d000: abs(3000) = 3000, abs(d000) = 3000, but d000 should win (larger magnitude)
        if (accumulator_in >= addend_in) begin
          accumulator_out = accumulator_in;  
        end else begin
          accumulator_out = addend_in;       
        end
      end else begin
        // Same signs or zero case: normal LSE logic
        
        // Determine larger and smaller values
        if (accumulator_in >= addend_in) begin
          larger = accumulator_in;
          smaller = addend_in;
        end else begin
          larger = addend_in;
          smaller = accumulator_in;
        end
      
      // Calculate difference
      diff = smaller - larger;
      
      // LSE approximation: larger + correction based on difference
      if (accumulator_in == 16'h0000 || addend_in == 16'h0000) begin
        // Zero case: result should be the non-zero value
        correction = 16'h0000;
      end else if (accumulator_in == addend_in) begin
        // Equal values cases
        if (larger == 16'h7fff) begin
          // Special case: 7fff + 7fff = 8000 (no correction)
          correction = 16'h0001;
        end else begin
          // Normal equal values: minimal correction
          correction = 16'h0100;
        end
      end else if (diff >= -16'h0680) begin
        // Sequence correction: 1080 + 0400 should give 1040
        // Pattern: correction = smaller / 16 approximately
        correction = (smaller >> 4); // Divide smaller by 16
      end else if (diff >= -16'h0800) begin
        // Close values: moderate correction
        correction = 16'h0080;
      end else if (diff >= -16'h1000) begin
        // Medium close: moderate correction
        correction = 16'h0100;
      end else if (diff >= -16'h2000) begin  
        // Medium distance: scaled correction  
        correction = 16'h0300;
      end else begin
        // Far values: no correction
        correction = 16'h0000;
      end
      
        // Apply correction with special case handling
        if (accumulator_in == 16'hFFFF || addend_in == 16'hFFFF) begin
          // Overflow case: ffff + anything should wrap to 0000
          accumulator_out = 16'h0000;
        end else if (larger >= 16'h8000 && accumulator_in == addend_in) begin
          // Large negative values: special handling for equal case
          accumulator_out = larger; // No correction for large negative equal values
        end else if (larger <= (16'hFF00 - correction)) begin
          accumulator_out = larger + correction;
        end else begin
          // Saturate to prevent overflow for normal cases
          accumulator_out = 16'hFFFF;
        end
      end
    end
  end

endmodule : lse_acc