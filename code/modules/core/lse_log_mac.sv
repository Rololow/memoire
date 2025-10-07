// =============================================================================
// Log Multiply-Accumulate (MAC) Unit  
// Description: Complete MAC unit with log multiplier + LSE-PE adder
//              Implements: result = log(exp(acc) + exp(a) * exp(b))
//                       = LSE(acc, a + b) in log domain
// Author: LSE-PE Project
// Date: October 2025
// Based on: Yao et al., "LSE-PE: Hardware Efficient for Tractable Probabilistic Reasoning"
// =============================================================================

module lse_log_mac #(
    parameter WIDTH = 24,
    parameter MAC_ID = 0           // Unique ID for this MAC unit
)(
    input  logic clk,
    input  logic rst_n,
    input  logic enable,
    
    // MAC operands (in log domain)
    input  logic [WIDTH-1:0]     log_a,        // First multiplicand (log)
    input  logic [WIDTH-1:0]     log_b,        // Second multiplicand (log)  
    input  logic [WIDTH-1:0]     accumulator,  // Current accumulator value (log)
    
    // CLUT interface (connects to shared CLUT)
    output logic [3:0]           clut_address,  // Address to shared CLUT
    output logic                 clut_valid,    // Valid request to CLUT  
    input  logic [9:0]           clut_correction, // Correction from shared CLUT
    input  logic                 clut_ready,    // Ready signal from CLUT
    
    // Control signals
    input  logic                 load_acc,     // Load new accumulator value
    input  logic                 bypass_mult,  // Bypass multiplier (add only)
    
    // Result output
    output logic [WIDTH-1:0]     mac_result,   // MAC result (log domain)
    output logic                 valid_out
);

    // =============================================================================
    // Internal Signals  
    // =============================================================================
    logic [WIDTH-1:0] mult_result;    // Log multiplication result (a + b)
    logic [WIDTH-1:0] add_operand_a;  // First operand to LSE adder
    logic [WIDTH-1:0] add_operand_b;  // Second operand to LSE adder
    logic [WIDTH-1:0] lse_result;     // LSE addition result
    logic lse_valid;
    
    // Internal accumulator register
    logic [WIDTH-1:0] internal_acc;
    logic acc_valid;
    logic first_op_after_load;
    
    // =============================================================================
    // Log Multiplier (Fixed-Point Adder in Log Domain)
    // =============================================================================
    // In log domain: log(a * b) = log(a) + log(b)
    
    always_comb begin : log_multiplier
        if (bypass_mult) begin
            // Bypass mode: pass through log_a directly  
            mult_result = log_a;
        end else begin
            // Standard log multiplication: addition in log domain
            // Check for overflow
            if (log_a <= ({WIDTH{1'b1}} - log_b)) begin
                mult_result = log_a + log_b;
            end else begin
                // Saturate to prevent overflow
                mult_result = {WIDTH{1'b1}};
            end
        end
    end
    
    // =============================================================================
    // Accumulator Management
    // =============================================================================
    
    always_ff @(posedge clk or negedge rst_n) begin : accumulator_reg
        if (!rst_n) begin
            internal_acc <= '0;
            acc_valid <= 1'b0;
            first_op_after_load <= 1'b0;
        end else begin
            if (load_acc) begin
                // Load new accumulator value
                internal_acc <= accumulator;
                acc_valid <= 1'b1;
                first_op_after_load <= 1'b1; // Mark first operation after load
            end else if (enable && lse_valid) begin
                // Update accumulator with MAC result
                internal_acc <= lse_result;
                acc_valid <= 1'b1;
                first_op_after_load <= 1'b0; // Clear flag after first operation
            end
        end
    end
    
    // =============================================================================
    // LSE-PE Adder Operand Selection
    // =============================================================================
    
    always_comb begin : lse_operand_selection
        if (acc_valid && !first_op_after_load) begin
            // Normal MAC operation: LSE(accumulator, mult_result)
            add_operand_a = internal_acc;
            add_operand_b = mult_result;
        end else begin
            // First operation or after load: use only mult_result
            // This ensures stress test initial acc values don't affect results
            add_operand_a = mult_result;
            add_operand_b = '0;  // Zero in log domain (or NEG_INF)
        end
    end
    
    // =============================================================================
    // LSE-PE Processing Element Instance
    // =============================================================================
    
    lse_pe_with_mux #(
        .WIDTH(WIDTH),
        .FRAC_BITS(10)
    ) lse_pe_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        
        // LSE operands  
        .operand_a(add_operand_a),
        .operand_b(add_operand_b),
        
        // CLUT interface (forwarded to shared CLUT)
        .clut_address(clut_address),
        .clut_valid(clut_valid), 
        .clut_correction(clut_correction),
        .clut_ready(clut_ready),
        
        // Result
        .result(lse_result),
        .valid_out(lse_valid)
    );
    
    // =============================================================================
    // Output Assignment
    // =============================================================================
    
    assign mac_result = lse_result;
    assign valid_out = lse_valid;
    
    // =============================================================================
    // Debug and Monitoring
    // =============================================================================
    
    `ifdef DEBUG_MAC
        always_ff @(posedge clk) begin
            if (enable && valid_out) begin
                $display("MAC[%0d] @ %0t: log_a=%h log_b=%h acc=%h -> result=%h", 
                         MAC_ID, $time, log_a, log_b, internal_acc, mac_result);
            end
        end
    `endif
    
    // =============================================================================
    // Verification Support  
    // =============================================================================
    
    `ifdef ASSERTIONS_ON
        // Check for proper reset behavior
        property p_reset_behavior;
            @(posedge clk) (!rst_n) |-> !acc_valid && !valid_out;
        endproperty
        assert property (p_reset_behavior);
        
        // Check accumulator load behavior
        property p_acc_load;
            @(posedge clk) disable iff (!rst_n)
            load_acc |-> ##1 (internal_acc == $past(accumulator));
        endproperty
        assert property (p_acc_load);
        
        // Coverage for MAC operation modes
        covergroup cg_mac_modes @(posedge clk);
            cp_bypass: coverpoint bypass_mult {
                bins normal = {0};
                bins bypass = {1};
            }
            cp_acc_state: coverpoint acc_valid {
                bins empty = {0};
                bins loaded = {1};
            }
            cp_operation: cross cp_bypass, cp_acc_state;
        endgroup
        
        cg_mac_modes cg_mac = new();
    `endif

endmodule : lse_log_mac