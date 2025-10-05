// =============================================================================
// SIMD LSE Unified Module (Multi-Precision)
// Description: Unified SIMD LSE with mode selection (24b/2×12b/4×6b)
// Version: Unified standard interface
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module lse_simd_unified #(
    parameter LUT_SIZE      = 16,    // LUT table size (number of entries)
    parameter LUT_PRECISION = 10,    // LUT entry precision (bits)
    parameter DATA_WIDTH    = 24     // Total data width (24 bits)
)(
    input  logic                     clk,        // Clock signal
    input  logic                     rst,        // Synchronous reset, active high
    input  logic                     enable,     // Enable signal
    input  logic [1:0]               simd_mode,  // SIMD mode: 00=24b, 01=2×12b, 10=4×6b, 11=reserved
    input  logic [DATA_WIDTH-1:0]   x_in,       // Input X (format depends on mode)
    input  logic [DATA_WIDTH-1:0]   y_in,       // Input Y (format depends on mode)
    input  logic [1:0]               pe_mode,    // Processing element mode
    input  logic [LUT_PRECISION-1:0] lut_table[LUT_SIZE],  // LUT for error correction
    output logic [DATA_WIDTH-1:0]   result,     // Output (format depends on mode)
    output logic                     valid_out   // Valid output signal
);

    // =========================================================================
    // Mode Definitions
    // =========================================================================
    typedef enum logic [1:0] {
        MODE_24B  = 2'b00,  // Single 24-bit operation
        MODE_2X12 = 2'b01,  // Dual 12-bit operations  
        MODE_4X6  = 2'b10,  // Quad 6-bit operations
        MODE_RSVD = 2'b11   // Reserved for future use
    } simd_mode_t;
    
    // =========================================================================
    // Internal Result Signals for Each Mode
    // =========================================================================
    logic [DATA_WIDTH-1:0] result_24b, result_2x12b, result_4x6b;
    logic valid_24b, valid_2x12b, valid_4x6b;
    
    // =========================================================================
    // Mode 00: Single 24-bit LSE Operation
    // =========================================================================
    lse_add #(
        .LUT_SIZE(LUT_SIZE),
        .LUT_PRECISION(LUT_PRECISION),
        .WIDTH(24)
    ) lse_24b (
        .clk(clk),
        .rst(rst),
        .enable(enable && (simd_mode == MODE_24B)),
        .operand_a(x_in),
        .operand_b(y_in),
        .lut_table(lut_table),
        .pe_mode(pe_mode),
        .result(result_24b),
        .valid_out(valid_24b)
    );
    
    // =========================================================================
    // Mode 01: Dual 12-bit LSE Operations (2×12b)
    // =========================================================================
    lse_simd_2x12b #(
        .LUT_SIZE(LUT_SIZE),
        .LUT_PRECISION(LUT_PRECISION),
        .CHANNEL_WIDTH(12),
        .DATA_WIDTH(DATA_WIDTH)
    ) lse_2x12b (
        .clk(clk),
        .rst(rst),
        .enable(enable && (simd_mode == MODE_2X12)),
        .x_in(x_in),
        .y_in(y_in),
        .pe_mode(pe_mode),
        .lut_table(lut_table),
        .result(result_2x12b),
        .valid_out(valid_2x12b)
    );
    
    // =========================================================================
    // Mode 10: Quad 6-bit LSE Operations (4×6b)
    // =========================================================================
    lse_simd_4x6b #(
        .LUT_SIZE(LUT_SIZE),
        .LUT_PRECISION(LUT_PRECISION),
        .CHANNEL_WIDTH(6),
        .DATA_WIDTH(DATA_WIDTH)
    ) lse_4x6b (
        .clk(clk),
        .rst(rst),
        .enable(enable && (simd_mode == MODE_4X6)),
        .x_in(x_in),
        .y_in(y_in),
        .pe_mode(pe_mode),
        .lut_table(lut_table),
        .result(result_4x6b),
        .valid_out(valid_4x6b)
    );
    
    // =========================================================================
    // Output Multiplexing and Pipeline Register
    // =========================================================================
    always_ff @(posedge clk) begin : unified_output_mux
        if (rst) begin
            result <= '0;
            valid_out <= 1'b0;
        end else begin
            case (simd_mode)
                MODE_24B: begin
                    result <= result_24b;
                    valid_out <= valid_24b;
                end
                
                MODE_2X12: begin
                    result <= result_2x12b;
                    valid_out <= valid_2x12b;
                end
                
                MODE_4X6: begin
                    result <= result_4x6b;
                    valid_out <= valid_4x6b;
                end
                
                MODE_RSVD: begin
                    result <= '0;
                    valid_out <= 1'b0;
                end
                
                default: begin
                    result <= '0;
                    valid_out <= 1'b0;
                end
            endcase
        end
    end
    
    // =========================================================================
    // Resource Sharing and Optimization Notes
    // =========================================================================
    // This unified architecture allows for:
    //
    // 1. **Shared LUT Resources**: All modes use the same lut_table
    // 2. **Mode-specific Pipeline**: Different latencies per mode
    // 3. **Dynamic Switching**: Mode can change cycle-by-cycle
    // 4. **Power Optimization**: Unused modes can be clock-gated
    //
    // Performance characteristics:
    // - MODE_24B:  1 operation  per cycle, full precision
    // - MODE_2X12: 2 operations per cycle, medium precision  
    // - MODE_4X6:  4 operations per cycle, reduced precision
    //
    // Latency characteristics:
    // - MODE_24B:  Combinational (0 cycles) + output register (1 cycle)
    // - MODE_2X12: 1 cycle (pipelined)
    // - MODE_4X6:  1 cycle (pipelined)
    
    // =========================================================================
    // Mode Transition Handling
    // =========================================================================
    // Note: When switching modes mid-operation, the pipeline may contain
    // results from the previous mode. Applications should:
    // 1. Wait for valid_out to go low before changing modes
    // 2. Or insert appropriate pipeline flushes
    // 3. Or use the mode transition as a natural pipeline boundary
    
endmodule : lse_simd_unified