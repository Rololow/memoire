// =============================================================================
// LSE Shared System - Complete System with Multiple MAC Units
// Description: Top-level system implementing shared CLUT architecture
//              Multiple LSE MAC units sharing a single CLUT for efficiency  
// Author: LSE-PE Project
// Date: October 2025
// Based on: Yao et al., "LSE-PE: Hardware Efficient for Tractable Probabilistic Reasoning"
// =============================================================================

module lse_shared_system #(
    parameter NUM_MAC_UNITS = 4,         // Number of MAC units
    parameter WIDTH = 24,                // Data path width
    parameter FRAC_BITS = 10,            // Fractional bits for CLUT indexing
    parameter CLUT_DEPTH = 16,           // CLUT depth (2^address_bits)
    parameter PIPELINE_STAGES = 2        // Pipeline stages for MAC units
)(
    input  logic clk,
    input  logic rst_n,
    
    // Global control
    input  logic global_enable,
    input  logic system_reset,
    
    // MAC Unit Array Interfaces
    input  logic [NUM_MAC_UNITS-1:0]                 mac_enable,     // Individual MAC enables
    input  logic [NUM_MAC_UNITS-1:0][WIDTH-1:0]      log_a_array,    // Multiplicand A array
    input  logic [NUM_MAC_UNITS-1:0][WIDTH-1:0]      log_b_array,    // Multiplicand B array  
    input  logic [NUM_MAC_UNITS-1:0][WIDTH-1:0]      acc_array,      // Accumulator array
    input  logic [NUM_MAC_UNITS-1:0]                 load_acc_array, // Load accumulator signals
    input  logic [NUM_MAC_UNITS-1:0]                 bypass_mult_array, // Bypass multiplier signals
    
    // System outputs
    output logic [NUM_MAC_UNITS-1:0][WIDTH-1:0]      mac_results,    // MAC results array
    output logic [NUM_MAC_UNITS-1:0]                 valid_array,    // Valid output array
    
    // System status
    output logic                                      system_ready,   // System ready for operations
    output logic [31:0]                              operation_count, // Total operations counter
    output logic [$clog2(NUM_MAC_UNITS)-1:0]         active_units    // Number of active MAC units
);

    // =============================================================================
    // Internal Signal Declarations
    // =============================================================================
    
    // CLUT interface signals from MAC units (using unpacked arrays for compatibility)
    logic [3:0]  clut_addresses    [NUM_MAC_UNITS];    // CLUT address requests
    logic        clut_valids       [NUM_MAC_UNITS];    // CLUT valid requests
    logic [9:0]  clut_corrections  [NUM_MAC_UNITS];    // CLUT correction values
    logic        clut_readys       [NUM_MAC_UNITS];    // CLUT ready signals
    
    // Internal unpacked versions for MAC unit connections
    logic [WIDTH-1:0] mac_log_a_unpacked   [NUM_MAC_UNITS];
    logic [WIDTH-1:0] mac_log_b_unpacked   [NUM_MAC_UNITS];
    logic [WIDTH-1:0] mac_acc_unpacked     [NUM_MAC_UNITS];
    logic [WIDTH-1:0] mac_results_unpacked [NUM_MAC_UNITS];
    
    // Convert packed arrays to unpacked for internal use
    genvar i;
    generate
        for (i = 0; i < NUM_MAC_UNITS; i++) begin : convert_arrays
            assign mac_log_a_unpacked[i] = log_a_array[i];
            assign mac_log_b_unpacked[i] = log_b_array[i];
            assign mac_acc_unpacked[i] = acc_array[i];
            assign mac_results[i] = mac_results_unpacked[i];
        end
    endgenerate
    
    // System control registers
    logic system_active;
    logic [31:0] cycle_counter;
    
    // =============================================================================
    // Shared CLUT Instance
    // =============================================================================
    
    lse_clut_shared #(
        .NUM_PE(NUM_MAC_UNITS),
        .ENTRIES(16),
        .ENTRY_WIDTH(10)
    ) shared_clut_inst (
        .clk(clk),
        .rst_n(rst_n && !system_reset),
        
        // Multi-port access
        .address(clut_addresses),      // Address array from all PEs
        .valid_in(clut_valids),        // Valid signals from all PEs
        .correction(clut_corrections), // Corrections to all PEs
        .valid_out(clut_readys)        // Ready signals to all PEs (renamed from valid_out)
    );
    
    // =============================================================================
    // Direct Multi-Port CLUT Access (No arbitration needed - CLUT handles it)
    // =============================================================================
    // The lse_clut_shared module has multi-port access built-in,
    // so we can directly connect all MAC units to it
    
    // =============================================================================
    // MAC Unit Array Instantiation
    // =============================================================================
    
    genvar mac_i;
    generate
        for (mac_i = 0; mac_i < NUM_MAC_UNITS; mac_i++) begin : gen_mac_units
            
            lse_log_mac #(
                .WIDTH(WIDTH),
                .MAC_ID(mac_i)
            ) mac_unit_inst (
                .clk(clk),
                .rst_n(rst_n && !system_reset),
                .enable(mac_enable[mac_i] && global_enable),
                
                // MAC operands (using unpacked versions)
                .log_a(mac_log_a_unpacked[mac_i]),
                .log_b(mac_log_b_unpacked[mac_i]),
                .accumulator(mac_acc_unpacked[mac_i]),
                
                // CLUT interface (connected to arbitration)
                .clut_address(clut_addresses[mac_i]),
                .clut_valid(clut_valids[mac_i]),
                .clut_correction(clut_corrections[mac_i]),
                .clut_ready(clut_readys[mac_i]),
                
                // Control
                .load_acc(load_acc_array[mac_i]),
                .bypass_mult(bypass_mult_array[mac_i]),
                
                // Results
                .mac_result(mac_results_unpacked[mac_i]),
                .valid_out(valid_array[mac_i])
            );
        end
    endgenerate
    
    // =============================================================================
    // System Status and Monitoring
    // =============================================================================
    
    // Count active MAC units
    always_comb begin : count_active_units
        active_units = 0;
        for (int i = 0; i < NUM_MAC_UNITS; i++) begin
            if (mac_enable[i]) begin
                active_units++;
            end
        end
    end
    
    // System ready when at least one unit is ready
    always_comb begin : system_ready_logic
        system_ready = 1'b1;  // Optimistic: system is ready
        for (int i = 0; i < NUM_MAC_UNITS; i++) begin
            if (mac_enable[i] && !clut_readys[i]) begin
                system_ready = 1'b0;  // At least one enabled unit not ready
            end
        end
        system_ready = system_ready && global_enable && rst_n && !system_reset;
    end
    
    // Operation counter
    always_ff @(posedge clk or negedge rst_n) begin : operation_counter
        integer i;
        logic [$clog2(NUM_MAC_UNITS+1)-1:0] completed_ops;
        
        if (!rst_n || system_reset) begin
            operation_count <= '0;
            cycle_counter <= '0;
            system_active <= 1'b0;
        end else if (global_enable) begin
            cycle_counter <= cycle_counter + 1;
            
            // Count completed operations
            completed_ops = 0;
            for (i = 0; i < NUM_MAC_UNITS; i = i + 1) begin
                if (valid_array[i]) begin
                    completed_ops = completed_ops + 1;
                end
            end
            
            operation_count <= operation_count + completed_ops;
            system_active <= (active_units > 0);
        end
    end
    
    // =============================================================================
    // Debug and Verification Support
    // =============================================================================
    
    `ifdef DEBUG_SYSTEM
        always_ff @(posedge clk) begin
            if (global_enable && system_ready) begin
                $display("LSE_SYSTEM @ %0t: Active=%0d Ready=%0d Ops=%0d", 
                         $time, active_units, system_ready, operation_count);
                
                for (int i = 0; i < NUM_MAC_UNITS; i++) begin
                    if (valid_array[i]) begin
                        $display("  MAC[%0d]: Result=%h", i, mac_results[i]);
                    end
                end
            end
        end
    `endif
    
    `ifdef ASSERTIONS_ON
        // System-level assertions
        property p_system_reset_behavior;
            @(posedge clk) system_reset |-> ##1 (operation_count == 0);
        endproperty
        assert property (p_system_reset_behavior);
        
        property p_arbitration_fairness;
            @(posedge clk) disable iff (!rst_n || system_reset)
            arb_valid |-> (selected_unit < NUM_MAC_UNITS);
        endproperty
        assert property (p_arbitration_fairness);
        
        // Coverage for system utilization
        covergroup cg_system_utilization @(posedge clk);
            cp_active_units: coverpoint active_units {
                bins idle = {0};
                bins low_util = {[1:NUM_MAC_UNITS/2]};
                bins high_util = {[NUM_MAC_UNITS/2+1:NUM_MAC_UNITS-1]};
                bins full_util = {NUM_MAC_UNITS};
            }
        endgroup
        
        cg_system_utilization cg_util = new();
    `endif

endmodule : lse_shared_system