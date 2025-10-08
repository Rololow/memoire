// =============================================================================
// Generic 2:1 Multiplexer (paramétrable)
// Permet de sélectionner entre deux entrées de largeur arbitraire.
// Réutilisable pour le routage des carries dans lse_mult_simd.
// =============================================================================

`timescale 1ns/1ps

module mux2 #(
  parameter int WIDTH = 1  // Largeur des données multiplexées
)(
  input  logic [WIDTH-1:0] in0,  // Entrée 0
  input  logic [WIDTH-1:0] in1,  // Entrée 1
  input  logic             sel,  // Sélection: 0 -> in0, 1 -> in1
  output logic [WIDTH-1:0] out   // Sortie multiplexée
);

  always_comb begin
    out = sel ? in1 : in0;
  end

endmodule : mux2
