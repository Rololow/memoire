// =============================================================================
// Constant CLUT Values for LSE-PE
// Provides a 16-entry (10-bit) lookup table used by the LSE adders.
// =============================================================================

module lut #(
    parameter int ENTRIES = 16,
    parameter int ENTRY_WIDTH = 10
)(
    output logic signed [ENTRY_WIDTH-1:0] o_values [0:ENTRIES-1]
);

    // Predefined LSE correction values (log-domain LUT)
    localparam logic signed [ENTRY_WIDTH-1:0] LUT_INIT [0:ENTRIES-1] = '{
        // START LUT VALUES (optimized from reference sweep)
        10'b0000000011,
        10'b0000010101,
        10'b0000101000,
        10'b0000110010,
        10'b0001000011,
        10'b0001000001,
        10'b0001000000,
        10'b0001001000,
        10'b0001010010,
        10'b0001000011,
        10'b0000110010,
        10'b0000100011,
        10'b0000010110,
        10'b0000001101,
        10'b0000000110,
        10'b0000000001
        // END LUT VALUES
    };

    assign o_values = LUT_INIT;

endmodule : lut
