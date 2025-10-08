// =============================================================================
// LSE Mult SIMD Adder
// Description: addition dans l'espace log avec support de modes SIMD
//  - 00 : 1 × 24 bits (carry propagé sur tout le mot)
//  - 01 : 2 × 12 bits (carry réinitialisé à 12 bits)
//  - 10 : 4 × 6  bits (carry réinitialisé tous les 6 bits)
// Les carries sont gérés via des multiplexeurs pour couper la propagation
// lorsque plusieurs lanes parallèles sont utilisées.
// =============================================================================

`timescale 1ns/1ps

module lse_mult_simd (
  input  logic [23:0] operand_a,
  input  logic [23:0] operand_b,
  input  logic [1:0]  simd_mode,   // 00:1x24, 01:2x12, 10:4x6
  output logic [23:0] result       // Résultat additionné (log-space)
);

  localparam int WIDTH = 24;

  logic [WIDTH:0] carry_chain;
  assign carry_chain[0] = 1'b0;  // pas de carry-in global

  genvar i;
  generate
    for (i = 0; i < WIDTH; i++) begin : gen_simd_adders
      localparam bit BOUNDARY_12 = (i == 12);
      localparam bit BOUNDARY_6  = ((i % 6) == 0) && (i != 0);

      logic reset_segment;
      logic carry_in_bit;

      if (i == 0) begin : first_bit
        assign reset_segment = 1'b0;
        assign carry_in_bit  = carry_chain[i];
      end else begin : subsequent_bits
        assign reset_segment = ((simd_mode == 2'b01) && BOUNDARY_12) ||
                               ((simd_mode == 2'b10) && BOUNDARY_6);

        mux2 #(.WIDTH(1)) carry_mux (
          .in0(carry_chain[i]),   // propagation du carry précédent
          .in1(1'b0),             // coupe le carry entre lanes
          .sel(reset_segment),
          .out(carry_in_bit)
        );
      end

      full_adder adder_bit (
        .a   (operand_a[i]),
        .b   (operand_b[i]),
        .cin (carry_in_bit),
        .sum (result[i]),
        .cout(carry_chain[i+1])
      );
    end
  endgenerate

  // Les carries de sortie de chaque lane sont ignorés
  // (comportement wrap-around). Ajouter une saturation si nécessaire.

endmodule : lse_mult_simd
