// =============================================================================
// SIMD LSE 4×6 bits Module (Unified)
// Description: Quad-channel 6-bit LSE operations for high-performance inference
// Version: Unified standard interface
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

module lse_simd_4x6b #(
    parameter LUT_SIZE      = 16,    // LUT table size (number of entries)
    parameter LUT_PRECISION = 10,    // LUT entry precision (bits)
    parameter CHANNEL_WIDTH = 6,     // Width per channel (6 bits)
    parameter DATA_WIDTH    = 24     // Total data width (4×6 = 24 bits)
)(
    input  logic                     clk,        // Clock signal
    input  logic                     rst,        // Synchronous reset, active high
    input  logic                     enable,     // Enable signal
    input  logic [DATA_WIDTH-1:0]   x_in,       // Input X: [23:18][17:12][11:6][5:0] = ch3,ch2,ch1,ch0
    input  logic [DATA_WIDTH-1:0]   y_in,       // Input Y: [23:18][17:12][11:6][5:0] = ch3,ch2,ch1,ch0
    input  logic [1:0]               pe_mode,    // Processing element mode
    input  logic [LUT_PRECISION-1:0] lut_table[LUT_SIZE],  // LUT for error correction
    output logic [DATA_WIDTH-1:0]   result,     // Output: [23:18][17:12][11:6][5:0] = ch3,ch2,ch1,ch0
    output logic                     valid_out   // Valid output signal
);

    // =========================================================================
    // Internal Signals and Channel Separation
    // =========================================================================
    
    // Four independent 6-bit channels
    logic [CHANNEL_WIDTH-1:0] x_ch0, y_ch0, lse_result_ch0;  // Channel 0: [5:0]
    logic [CHANNEL_WIDTH-1:0] x_ch1, y_ch1, lse_result_ch1;  // Channel 1: [11:6]
    logic [CHANNEL_WIDTH-1:0] x_ch2, y_ch2, lse_result_ch2;  // Channel 2: [17:12]
    logic [CHANNEL_WIDTH-1:0] x_ch3, y_ch3, lse_result_ch3;  // Channel 3: [23:18]
    
    // Valid signals for each channel
    logic valid_ch0, valid_ch1, valid_ch2, valid_ch3;
    
    // Input unpacking - 4 channels of 6 bits each
    assign x_ch0 = x_in[5:0];     // Channel 0
    assign x_ch1 = x_in[11:6];    // Channel 1
    assign x_ch2 = x_in[17:12];   // Channel 2
    assign x_ch3 = x_in[23:18];   // Channel 3
    
    assign y_ch0 = y_in[5:0];     // Channel 0
    assign y_ch1 = y_in[11:6];    // Channel 1
    assign y_ch2 = y_in[17:12];   // Channel 2
    assign y_ch3 = y_in[23:18];   // Channel 3
    
    // =========================================================================
    // LSE Channel 0 Instance (Bits [5:0])
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
    // LSE Channel 1 Instance (Bits [11:6])
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
    // LSE Channel 2 Instance (Bits [17:12])
    // =========================================================================
    lse_add #(
        .LUT_SIZE(LUT_SIZE),
        .LUT_PRECISION(LUT_PRECISION),
        .WIDTH(CHANNEL_WIDTH)
    ) lse_ch2 (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .operand_a(x_ch2),
        .operand_b(y_ch2),
        .lut_table(lut_table),
        .pe_mode(pe_mode),
        .result(lse_result_ch2),
        .valid_out(valid_ch2)
    );
    
    // =========================================================================
    // LSE Channel 3 Instance (Bits [23:18])
    // =========================================================================
    lse_add #(
        .LUT_SIZE(LUT_SIZE),
        .LUT_PRECISION(LUT_PRECISION),
        .WIDTH(CHANNEL_WIDTH)
    ) lse_ch3 (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .operand_a(x_ch3),
        .operand_b(y_ch3),
        .lut_table(lut_table),
        .pe_mode(pe_mode),
        .result(lse_result_ch3),
        .valid_out(valid_ch3)
    );
    
    // =========================================================================
    // Output Packing (Combinational - LSE modules handle synchronous output)
    // =========================================================================
    always_comb begin : simd_4x6b_output_pack
        // Pack results from all four channels
        result[5:0]   = lse_result_ch0;   // Channel 0
        result[11:6]  = lse_result_ch1;   // Channel 1
        result[17:12] = lse_result_ch2;   // Channel 2
        result[23:18] = lse_result_ch3;   // Channel 3
        
        // Valid output when all channels are valid
        valid_out = valid_ch0 && valid_ch1 && valid_ch2 && valid_ch3;
    end
    
    // =========================================================================
    // 6-bit Saturation Management
    // =========================================================================
    // Note: Each 6-bit channel has limited dynamic range.
    // The LSE modules handle internal saturation, but applications
    // should be aware of the reduced precision in 6-bit mode.
    //
    // 6-bit signed range: -32 to +31
    // 6-bit unsigned range: 0 to 63
    // This mode is optimized for inference where reduced precision is acceptable.
    
    // =========================================================================
    // Performance Notes
    // =========================================================================
    // This 4×6b mode provides:
    // - 4× parallelism compared to 24-bit mode
    // - Reduced precision but higher throughput
    // - Ideal for neural network inference
    // - Lower power consumption per operation
    
endmodule : lse_simd_4x6b