// =============================================================================
// LSE Processing Element with Integrated Multiplexer
// Description: LSE-PE unit with built-in MUX for CLUT address generation
//              Designed to work with shared CLUT architecture
// Author: LSE-PE Project
// Date: October 2025  
// Based on: Yao et al., "LSE-PE: Hardware Efficient for Tractable Probabilistic Reasoning"
// =============================================================================

module lse_pe_with_mux #(
    parameter WIDTH = 24,
    parameter FRAC_BITS = 10      // Number of fractional bits for MUX selection
)(
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    
    // LSE operands
    input  logic [WIDTH-1:0]     operand_a,
    input  logic [WIDTH-1:0]     operand_b,
    
    // CLUT interface (connects to shared CLUT)
    output logic [3:0]           clut_address,  // Address to shared CLUT
    output logic                 clut_valid,    // Valid request to CLUT
    input  logic [9:0]           clut_correction, // Correction from shared CLUT
    input  logic                 clut_ready,    // Ready signal from CLUT (valid_out)
    
    // Result output
    output logic [WIDTH-1:0]     result,
    output logic                 valid_out
);

    // =============================================================================
    // Local Parameters
    // =============================================================================
    localparam NEG_INF_VAL = {1'b1, {(WIDTH-1){1'b0}}}; // MSB=1, others=0
    localparam SMALL_CORRECTION = WIDTH/8; // Adaptive correction based on width
    localparam DIFF_THRESHOLD = -(2**(WIDTH-4)); // Adaptive threshold
    
    // =============================================================================
    // Internal Signals
    // =============================================================================
    logic [WIDTH-1:0] larger, smaller;
    logic signed [WIDTH:0] diff;
    logic [WIDTH-1:0] base_result;
    logic [FRAC_BITS-1:0] f_tilde_fraction;
    logic [WIDTH-1:0] result_next;
    logic valid_next;
    
    // Pipeline stages
    logic [WIDTH-1:0] stage1_larger, stage1_smaller;
    logic signed [WIDTH:0] stage1_diff;
    logic [3:0] stage1_clut_addr;
    logic stage1_valid;
    
    logic [WIDTH-1:0] stage2_base_result;
    logic [9:0] stage2_correction;
    logic stage2_valid;
    
    // =============================================================================
    // Stage 1: LSE Computation + MUX Address Generation
    // =============================================================================
    
    always_comb begin : lse_computation_stage1
        
        // Check for special values (negative infinity)
        if (operand_a == NEG_INF_VAL || operand_b == NEG_INF_VAL) begin
            if (operand_a == NEG_INF_VAL && operand_b == NEG_INF_VAL) begin
                larger = NEG_INF_VAL;  // -inf + (-inf) = -inf
                smaller = '0;
                diff = '0;
            end else if (operand_a == NEG_INF_VAL) begin
                larger = operand_b;    // -inf + x = x
                smaller = '0;
                diff = '0;
            end else begin
                larger = operand_a;    // x + (-inf) = x
                smaller = '0;
                diff = '0;
            end
        end else begin
            // Standard LSE comparison
            if (operand_a >= operand_b) begin
                larger = operand_a;
                smaller = operand_b;
            end else begin
                larger = operand_b;
                smaller = operand_a;
            end
            
            diff = $signed({1'b0, smaller}) - $signed({1'b0, larger}); // Always ≤ 0
        end
    end
    
    // MUX Logic: Extract 10 bits for CLUT address generation  
    // According to paper: "each LSE-PE unit is equipped with its own multiplexer (MUX) 
    // to select 10 bits for error correction"
    always_comb begin : mux_address_generation
        
        if (diff > DIFF_THRESHOLD) begin
            // Significant contribution - use fractional part for correction
            // Extract fractional part from difference for CLUT addressing
            logic [WIDTH-1:0] abs_diff;
            abs_diff = (-diff); // Make positive
            
            // MUX selects 10 bits from the result for CLUT addressing
            // Use the fractional part of the approximation result
            f_tilde_fraction = abs_diff[FRAC_BITS-1:0];
            
            // Map 10-bit fraction to 4-bit CLUT address (16 entries)
            clut_address = f_tilde_fraction[FRAC_BITS-1:FRAC_BITS-4];
            clut_valid = 1'b1;
            
        end else begin
            // Very small contribution - no correction needed
            f_tilde_fraction = '0;
            clut_address = 4'h0;
            clut_valid = 1'b0;
        end
    end
    
    // =============================================================================
    // Stage 1 Pipeline Register
    // =============================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin : stage1_pipeline
        if (!rst_n) begin
            stage1_larger <= '0;
            stage1_smaller <= '0;
            stage1_diff <= '0;
            stage1_clut_addr <= 4'h0;
            stage1_valid <= 1'b0;
        end else if (enable) begin
            stage1_larger <= larger;
            stage1_smaller <= smaller;
            stage1_diff <= diff;
            stage1_clut_addr <= clut_address;
            stage1_valid <= 1'b1;
        end else begin
            stage1_valid <= 1'b0;
        end
    end
    
    // =============================================================================
    // Stage 2: Base Result + CLUT Correction
    // =============================================================================
    
    always_comb begin : lse_final_computation
        
        // Compute base LSE result (without CLUT correction)
        if (stage1_diff > DIFF_THRESHOLD) begin
            // Significant contribution from smaller value
            if (stage1_larger <= ({{(WIDTH-4){1'b1}}, 4'b0000}) - SMALL_CORRECTION) begin
                base_result = stage1_larger + WIDTH'(SMALL_CORRECTION);
            end else begin
                base_result = {WIDTH{1'b1}}; // Saturate to maximum value
            end
        end else begin
            // Very small contribution, ignore smaller value  
            base_result = stage1_larger;
        end
    end
    
    // =============================================================================
    // Stage 2 Pipeline Register + Final Result
    // ============================================================================= 
    
    always_ff @(posedge clk or negedge rst_n) begin : stage2_pipeline
        if (!rst_n) begin
            stage2_base_result <= '0;
            stage2_correction <= '0;
            stage2_valid <= 1'b0;
        end else if (stage1_valid) begin
            // Always progress if stage1 is valid
            stage2_base_result <= base_result;
            // Use CLUT correction if ready, otherwise use 0
            stage2_correction <= clut_ready ? clut_correction : '0;
            stage2_valid <= 1'b1;
        end else begin
            stage2_valid <= 1'b0;
        end
    end
    
    // Final result with CLUT correction
    always_comb begin : final_result_computation
        if (stage2_valid) begin
            // Add CLUT correction to base result
            // Scale correction appropriately (may need adjustment based on precision)
            logic [WIDTH-1:0] scaled_correction;
            scaled_correction = {{(WIDTH-10){1'b0}}, stage2_correction};
            
            // Prevent overflow
            if (stage2_base_result <= ({WIDTH{1'b1}} - scaled_correction)) begin
                result_next = stage2_base_result + scaled_correction;
            end else begin
                result_next = {WIDTH{1'b1}}; // Saturate
            end
            
            valid_next = 1'b1;
        end else begin
            result_next = '0;
            valid_next = 1'b0;
        end
    end
    
    // =============================================================================
    // Output Assignment
    // =============================================================================
    
    assign result = result_next;
    assign valid_out = valid_next;
    
    // =============================================================================
    // Verification Support
    // =============================================================================
    
    `ifdef ASSERTIONS_ON
        // Check CLUT address bounds
        always_comb begin
            assert (!clut_valid || clut_address < 16)
                else $error("CLUT address %0d exceeds bounds", clut_address);
        end
        
        // Check for proper handshaking
        property p_clut_handshake;
            @(posedge clk) disable iff (!rst_n)
            clut_valid |-> ##[1:5] clut_ready;
        endproperty
        
        assert property (p_clut_handshake);
        
        // Coverage for MUX selection patterns
        covergroup cg_mux_patterns @(posedge clk);
            cp_clut_addr: coverpoint clut_address {
                bins low   = {[0:3]};
                bins mid   = {[4:11]};
                bins high  = {[12:15]};
            }
            cp_valid: coverpoint clut_valid {
                bins active = {1};
                bins idle   = {0};
            }
        endgroup
        
        cg_mux_patterns cg_mux = new();
    `endif

endmodule : lse_pe_with_mux