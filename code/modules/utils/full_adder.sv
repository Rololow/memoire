// =============================================================================
// Full Adder (1-bit) - Primitive building block
// Simple 1-bit full adder with carry in / carry out
// Auteur: généré automatiquement
// Date: Octobre 2025
// =============================================================================

`timescale 1ns/1ps

module full_adder (
  input  logic i_a,      // premier bit
  input  logic i_b,      // deuxième bit
  input  logic i_cin,    // carry in
  output logic o_sum,    // résultat (a + b + cin) LSB
  output logic o_cout    // carry out
);

  // Comportement combinatoire simple
  // sum = a ^ b ^ cin
  // cout = majority(a,b,cin) = (a & b) | (b & cin) | (a & cin)

  assign o_sum  = i_a ^ i_b ^ i_cin;
  assign o_cout = (i_a & i_b) | (i_b & i_cin) | (i_a & i_cin);

endmodule : full_adder
