// =============================================================================
// LSE Addition Module (LSE-PE Implementation)
// =============================================================================

module lse_add #(
    parameter int WIDTH          = 24,
    parameter int LUT_PRECISION  = 10,
    parameter int FRAC_BITS      = 10  // Number of fractional bits for CLUT addressing
)(
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic [WIDTH-1:0] operand_a,
    input  logic [WIDTH-1:0] operand_b,
    input  logic [LUT_PRECISION-1:0] clut_values [0:15],
    input  logic [1:0] pe_mode,
    output logic [WIDTH-1:0] result,
    output logic valid_out
);

    localparam logic [WIDTH-1:0] NEG_INF_VAL   = {1'b1, {(WIDTH-1){1'b0}}};
    localparam int                INT_BITS     = WIDTH - FRAC_BITS;
    localparam int                CLUT_SIZE    = 16;
    localparam int                CLUT_ADDR_BITS  = 4;
    localparam int                CLUT_ADDR_SHIFT = (FRAC_BITS > CLUT_ADDR_BITS)
                                                    ? (FRAC_BITS - CLUT_ADDR_BITS)
                                                    : 0;

    logic [WIDTH-1:0] result_next;

    always_comb begin : lse_add_comb
        result_next = '0;

        unique case (pe_mode)
            2'b00: begin
                if (operand_a == NEG_INF_VAL || operand_b == NEG_INF_VAL) begin
                    if (operand_a == NEG_INF_VAL && operand_b == NEG_INF_VAL) begin
                        result_next = NEG_INF_VAL;
                    end else if (operand_a == NEG_INF_VAL) begin
                        result_next = operand_b;
                    end else begin
                        result_next = operand_a;
                    end
                end else begin
                    logic [WIDTH-1:0] x, y;
                    logic signed [WIDTH:0] sub;
                    logic signed [INT_BITS-1:0] I_yx;
                    logic [FRAC_BITS-1:0] F_yx;
                    logic [WIDTH-1:0] one_plus_frac;
                    logic [WIDTH-1:0] f_tilde;
                    logic [5:0] shift_amount;
                    logic [FRAC_BITS-1:0] frac_part;
                    logic [CLUT_ADDR_BITS:0] rounded_index;
                    logic [CLUT_ADDR_BITS-1:0] clut_index;
                    logic [LUT_PRECISION-1:0] clut_correction;
                    logic [WIDTH:0] temp_result;

                    if (operand_a >= operand_b) begin
                        x = operand_a;
                        y = operand_b;
                    end else begin
                        x = operand_b;
                        y = operand_a;
                    end

                    sub = $signed({1'b0, y}) - $signed({1'b0, x});

                    I_yx = sub[WIDTH:FRAC_BITS];
                    F_yx = sub[FRAC_BITS-1:0];

                    one_plus_frac = {{(INT_BITS-1){1'b0}}, 1'b1, F_yx};

                    shift_amount = (-I_yx < 6'd24) ? -I_yx[5:0] : 6'd24;
                    f_tilde      = one_plus_frac >> shift_amount;

                    frac_part = f_tilde[FRAC_BITS-1:0];
                    if (CLUT_ADDR_SHIFT > 0) begin
                        rounded_index = (frac_part + (1 << (CLUT_ADDR_SHIFT-1))) >> CLUT_ADDR_SHIFT;
                    end else begin
                        rounded_index = {1'b0, frac_part[CLUT_ADDR_BITS-1:0]};
                    end

                    if (rounded_index[CLUT_ADDR_BITS]) begin
                        clut_index = {CLUT_ADDR_BITS{1'b1}};
                    end else begin
                        clut_index = rounded_index[CLUT_ADDR_BITS-1:0];
                    end

                    clut_correction = clut_values[clut_index];

                    temp_result = x + f_tilde + {{(WIDTH-LUT_PRECISION){1'b0}}, clut_correction};

                    if (temp_result[WIDTH]) begin
                        result_next = {WIDTH{1'b1}};
                    end else begin
                        result_next = temp_result[WIDTH-1:0];
                    end
                end
            end

            default: begin
                result_next = operand_a + operand_b;
            end
        endcase
    end

    always_ff @(posedge clk) begin : lse_add_sync
        if (rst) begin
            result    <= '0;
            valid_out <= 1'b0;
        end else if (enable) begin
            result    <= result_next;
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

    `ifdef DEBUG_LSE_ADD
        always_ff @(posedge clk) begin
            if (enable && pe_mode == 2'b00 &&
                operand_a != NEG_INF_VAL && operand_b != NEG_INF_VAL) begin
                $display("[LSE_ADD] t=%0t : a=%h, b=%h, result=%h",
                         $time, operand_a, operand_b, result_next);
            end
        end
    `endif

endmodule : lse_add