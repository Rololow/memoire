// =============================================================================
// LSE Compact Look-Up Table (CLUT) Module  
// Description: 16-entry correction LUT for LSE approximation error
//              Implements linear interpolation for improved accuracy
// Author: LSE-PE Project
// Date: October 2025
// =============================================================================

module lse_clut #(
    parameter ENTRIES = 16,        // Number of LUT entries  
    parameter ENTRY_WIDTH = 10,    // Bits per entry
    parameter INTERP_MODE = "LINEAR" // "LINEAR" or "NONE"
)(
    input  logic clk,
    input  logic rst_n,
    
    // Address Interface
    input  logic [9:0]              address,    // Normalized address [0,1) → [0,1023] 
    input  logic                    valid_in,   // Input valid
    
    // Output Interface  
    output logic [ENTRY_WIDTH-1:0]  correction, // Correction value
    output logic                    valid_out   // Output valid
);

    // =============================================================================
    // Local Parameters
    // =============================================================================
    localparam ADDR_WIDTH = $clog2(ENTRIES);
    localparam FRAC_WIDTH = 10 - ADDR_WIDTH; // Fractional part for interpolation
    
    // =============================================================================
    // CLUT ROM Data
    // =============================================================================
    // Pre-computed correction values for f(x) = log₂(1 + 2^x) - x approximation error
    // Values computed via Python script for range [0, 1) with 16 uniform samples
    
    // PYTHON SCRIPT START
    logic [ENTRY_WIDTH-1:0] lut_rom [ENTRIES] = '{
        10'h3FF,  // Entry  0: f(0.0000) correction
        10'h3DF,  // Entry  1: f(0.0625) correction
        10'h3C0,  // Entry  2: f(0.1250) correction
        10'h3A2,  // Entry  3: f(0.1875) correction
        10'h385,  // Entry  4: f(0.2500) correction
        10'h368,  // Entry  5: f(0.3125) correction
        10'h34C,  // Entry  6: f(0.3750) correction
        10'h330,  // Entry  7: f(0.4375) correction
        10'h315,  // Entry  8: f(0.5000) correction
        10'h2FB,  // Entry  9: f(0.5625) correction
        10'h2E2,  // Entry 10: f(0.6250) correction
        10'h2C9,  // Entry 11: f(0.6875) correction
        10'h2B1,  // Entry 12: f(0.7500) correction
        10'h299,  // Entry 13: f(0.8125) correction
        10'h282,  // Entry 14: f(0.8750) correction
        10'h26C   // Entry 15: f(0.9375) correction
    };
    // PYTHON SCRIPT END
    
    // =============================================================================
    // Internal Signals
    // =============================================================================
    logic [ADDR_WIDTH-1:0]    base_addr;        // Base LUT address
    logic [ADDR_WIDTH-1:0]    next_addr;        // Next LUT address  
    logic [FRAC_WIDTH-1:0]    frac_addr;        // Fractional address part
    
    logic [ENTRY_WIDTH-1:0]   base_value;       // Value at base address
    logic [ENTRY_WIDTH-1:0]   next_value;       // Value at next address
    logic [ENTRY_WIDTH-1:0]   interp_result;    // Interpolation result
    
    // Pipeline registers
    logic [ENTRY_WIDTH-1:0]   correction_reg;
    logic                     valid_reg;
    
    // =============================================================================
    // Address Decoding
    // =============================================================================
    
    // Split address into base and fractional parts
    // address[9:0] maps [0,1023] to LUT entries [0,15]
    assign base_addr = address[9:9-ADDR_WIDTH+1];  // Top ADDR_WIDTH bits
    assign frac_addr = address[FRAC_WIDTH-1:0];    // Bottom FRAC_WIDTH bits
    assign next_addr = (base_addr == ENTRIES-1) ? ENTRIES-1 : base_addr + 1;
    
    // =============================================================================
    // LUT Access (Combinational)
    // =============================================================================
    
    assign base_value = lut_rom[base_addr];
    assign next_value = lut_rom[next_addr];
    
    // =============================================================================
    // Interpolation Logic
    // =============================================================================
    
    generate
        if (INTERP_MODE == "LINEAR") begin : gen_linear_interp
            // Linear interpolation: result = base + (next-base) * frac / 2^FRAC_WIDTH
            logic signed [ENTRY_WIDTH:0]   diff;
            logic signed [ENTRY_WIDTH+FRAC_WIDTH:0] scaled_diff;
            
            assign diff = $signed({1'b0, next_value}) - $signed({1'b0, base_value});
            assign scaled_diff = diff * $signed({1'b0, frac_addr});
            
            always_comb begin
                logic signed [ENTRY_WIDTH+FRAC_WIDTH:0] temp_result;
                temp_result = $signed({1'b0, base_value}) * (2**FRAC_WIDTH) + scaled_diff;
                
                // Scale back and saturate
                if (temp_result < 0) begin
                    interp_result = '0;
                end else if (temp_result >= (2**(ENTRY_WIDTH+FRAC_WIDTH))) begin
                    interp_result = {ENTRY_WIDTH{1'b1}};  // Saturate to max
                end else begin
                    interp_result = temp_result[ENTRY_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
                end
            end
            
        end else begin : gen_no_interp
            // No interpolation - just return base value
            assign interp_result = base_value;
        end
    endgenerate
    
    // =============================================================================
    // Pipeline Stage (Optional - for timing closure)
    // =============================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            correction_reg <= '0;
            valid_reg <= 1'b0;
        end else begin
            correction_reg <= interp_result;
            valid_reg <= valid_in;
        end
    end
    
    // =============================================================================
    // Output Assignment
    // =============================================================================
    
    assign correction = correction_reg;
    assign valid_out = valid_reg;
    
    // =============================================================================
    // Verification Support
    // =============================================================================
    
    `ifdef ASSERTIONS_ON
        // Check parameter validity
        initial begin
            assert (ENTRIES == 16) 
                else $error("Only 16-entry CLUT supported in this version");
            assert (ENTRY_WIDTH == 10)
                else $error("Entry width must be 10 bits for current ROM data");
        end
        
        // Runtime checks
        always_comb begin
            assert (base_addr < ENTRIES)
                else $error("Base address %0d exceeds LUT size %0d", base_addr, ENTRIES);
        end
        
        // Coverage points for verification
        covergroup cg_lut_access @(posedge clk);
            cp_base_addr: coverpoint base_addr {
                bins low   = {[0:3]};
                bins mid   = {[4:11]};  
                bins high  = {[12:15]};
            }
            cp_frac_addr: coverpoint frac_addr {
                bins zero  = {0};
                bins low   = {[1:15]};
                bins mid   = {[16:47]};
                bins high  = {[48:63]};
            }
        endgroup
        
        cg_lut_access cg_inst = new();
    `endif

endmodule

// =============================================================================
// LUT Value Generator Function (for verification)
// =============================================================================

// This function can be used in testbenches to generate expected values
function automatic real lse_correction_function(real x);
    // Reference function: f(x) = log₂(1 + 2^x) - approximation_error
    // For x in [0,1), returns the correction needed
    real exact_value;
    real approx_value;
    
    exact_value = $ln(1.0 + $pow(2.0, x)) / $ln(2.0);  // log₂(1 + 2^x)
    approx_value = x;  // First-order approximation
    
    return exact_value - approx_value;  // Correction needed
endfunction