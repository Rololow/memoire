// =============================================================================
// Shared LSE CLUT Module for Multiple LSE-PE Units
// Description: Single CLUT shared by multiple LSE-PE processing elements
//              Each PE accesses via dedicated address/data interface
// Author: LSE-PE Project  
// Date: October 2025
// Based on: Yao et al., "LSE-PE: Hardware Efficient for Tractable Probabilistic Reasoning"
// =============================================================================

module lse_clut_shared #(
    parameter ENTRIES = 16,        // Number of LUT entries
    parameter ENTRY_WIDTH = 10,    // Bits per entry
    parameter NUM_PE = 4,          // Number of PE units sharing this CLUT
    parameter INTERP_MODE = "NONE" // "LINEAR" or "NONE" for simplicity
)(
    input  logic clk,
    input  logic rst_n,
    
    // Multi-port Address Interface (one per PE)
    input  logic [3:0]              address    [NUM_PE], // 4-bit address for 16 entries
    input  logic                    valid_in   [NUM_PE], // Input valid per PE
    
    // Multi-port Output Interface (one per PE)
    output logic [ENTRY_WIDTH-1:0]  correction [NUM_PE], // Correction value per PE
    output logic                    valid_out  [NUM_PE]  // Output valid per PE
);

    // =============================================================================
    // Local Parameters
    // =============================================================================
    localparam ADDR_WIDTH = $clog2(ENTRIES);
    
    // =============================================================================
    // Shared CLUT ROM Data  
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
    // Multi-port ROM Access Logic
    // =============================================================================
    
    // Generate individual access logic for each PE
    genvar i;
    generate
        for (i = 0; i < NUM_PE; i++) begin : gen_pe_access
            
            // Each PE gets its own pipeline stage
            always_ff @(posedge clk or negedge rst_n) begin : pe_access_proc
                if (!rst_n) begin
                    correction[i] <= '0;
                    valid_out[i] <= 1'b0;
                end else begin
                    valid_out[i] <= valid_in[i];
                    
                    if (valid_in[i]) begin
                        // Direct ROM access - all PEs can read simultaneously
                        correction[i] <= lut_rom[address[i]];
                    end
                end
            end
            
        end
    endgenerate
    
    // =============================================================================
    // Resource Sharing Analysis (for synthesis reports)
    // =============================================================================
    
    `ifdef SYNTHESIS_REPORTS
        // Synthesis directives for resource sharing
        (* ram_style = "block" *) logic [ENTRY_WIDTH-1:0] lut_rom_synth [ENTRIES];
        
        initial begin
            $display("CLUT Shared Resource Analysis:");
            $display("  ROM Size: %0d entries x %0d bits = %0d bits total", 
                     ENTRIES, ENTRY_WIDTH, ENTRIES * ENTRY_WIDTH);
            $display("  Sharing Factor: %0d PE units", NUM_PE);
            $display("  Area Efficiency: %0d%% vs individual CLUTs", 
                     100 / NUM_PE);
        end
    `endif
    
    // =============================================================================
    // Verification Support
    // =============================================================================
    
    `ifdef ASSERTIONS_ON
        // Check that all PEs have valid addresses
        genvar j;
        generate
            for (j = 0; j < NUM_PE; j++) begin : gen_assertions
                always_comb begin
                    assert (!valid_in[j] || address[j] < ENTRIES)
                        else $error("PE%0d: Address %0d exceeds LUT size %0d", 
                                   j, address[j], ENTRIES);
                end
            end
        endgenerate
        
        // Coverage for multi-port access patterns
        covergroup cg_multiport_access @(posedge clk);
            cp_concurrent_access: coverpoint $countones(valid_in) {
                bins single = {1};
                bins dual   = {2}; 
                bins triple = {3};
                bins quad   = {4};
            }
        endgroup
        
        cg_multiport_access cg_mp = new();
    `endif

endmodule : lse_clut_shared