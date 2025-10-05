// =============================================================================
// SIMD LSE 2×12 bits Module (Unified)
// Description: Dual-channel 12-bit LSE operations with parallel processing
// Version: Unified standard interface
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module lse_simd_2x12b #(
    parameter LUT_SIZE      = 16,    // LUT table size (number of entries)
    parameter LUT_PRECISION = 10,    // LUT entry precision (bits)
    parameter CHANNEL_WIDTH = 12,    // Width per channel (12 bits)
    parameter DATA_WIDTH    = 24     // Total data width (2×12 = 24 bits)
)(
    input  logic                     clk,        // Clock signal
    input  logic                     rst,        // Synchronous reset, active high
    input  logic                     enable,     // Enable signal
    input  logic [DATA_WIDTH-1:0]   x_in,       // Input X: [23:12] = ch1, [11:0] = ch0
    input  logic [DATA_WIDTH-1:0]   y_in,       // Input Y: [23:12] = ch1, [11:0] = ch0
    input  logic [1:0]               pe_mode,    // Processing element mode
    input  logic [LUT_PRECISION-1:0] lut_table[LUT_SIZE],  // LUT for error correction
    output logic [DATA_WIDTH-1:0]   result,     // Output: [23:12] = ch1, [11:0] = ch0
    output logic                     valid_out   // Valid output signal
);

    // =========================================================================
    // Internal Signals and Channel Separation
    // =========================================================================
    
    // Channel 0 (Lower 12 bits)
    logic [CHANNEL_WIDTH-1:0] x_ch0, y_ch0, lse_result_ch0;
    
    // Channel 1 (Upper 12 bits) 
    logic [CHANNEL_WIDTH-1:0] x_ch1, y_ch1, lse_result_ch1;
    
    // Valid signals for each channel
    logic valid_ch0, valid_ch1;
    
    // Input unpacking
    assign x_ch0 = x_in[CHANNEL_WIDTH-1:0];           // Bits [11:0]
    assign x_ch1 = x_in[DATA_WIDTH-1:CHANNEL_WIDTH];  // Bits [23:12]
    assign y_ch0 = y_in[CHANNEL_WIDTH-1:0];           // Bits [11:0]
    assign y_ch1 = y_in[DATA_WIDTH-1:CHANNEL_WIDTH];  // Bits [23:12]
    
    // =========================================================================
    // LSE Channel 0 Instance (Lower 12 bits)
    // =========================================================================
    lse_add #(
        .LUT_SIZE(LUT_SIZE),
        .LUT_PRECISION(LUT_PRECISION),
        .WIDTH(CHANNEL_WIDTH)
    ) lse_ch0 (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .operand_a(x_ch0),
        .operand_b(y_ch0),
        .lut_table(lut_table),
        .pe_mode(pe_mode),
        .result(lse_result_ch0),
        .valid_out(valid_ch0)
    );
    
    // =========================================================================
    // LSE Channel 1 Instance (Upper 12 bits)
    // =========================================================================
    lse_add #(
        .LUT_SIZE(LUT_SIZE),
        .LUT_PRECISION(LUT_PRECISION),
        .WIDTH(CHANNEL_WIDTH)
    ) lse_ch1 (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .operand_a(x_ch1),
        .operand_b(y_ch1),
        .lut_table(lut_table),
        .pe_mode(pe_mode),
        .result(lse_result_ch1),
        .valid_out(valid_ch1)
    );
    
    // =========================================================================
    // Output Packing (Combinational - LSE modules now handle synchronous output)
    // =========================================================================
    always_comb begin : simd_2x12b_output_pack
        // Pack results from both channels
        result[CHANNEL_WIDTH-1:0] = lse_result_ch0;           // Channel 0 to [11:0]
        result[DATA_WIDTH-1:CHANNEL_WIDTH] = lse_result_ch1;  // Channel 1 to [23:12]
        
        // Valid output when both channels are valid
        valid_out = valid_ch0 && valid_ch1;
    end
    
    // =========================================================================
    // Carry-over Management (Future Enhancement)
    // =========================================================================
    // Note: In this implementation, channels are independent.
    // Future versions may include carry-over handling between channels
    // for operations that span the 12-bit boundary.
    
    // =========================================================================
    // Overflow Detection and Saturation (12-bit specific)
    // =========================================================================
    // Each channel operates independently with 12-bit saturation
    // The LSE modules handle saturation internally
    
endmodule : lse_simd_2x12b