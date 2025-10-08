// =============================================================================
// Full Adder (1-bit) - Primitive building block
// Simple 1-bit full adder with carry in / carry out
// Auteur: généré automatiquement
// Date: Octobre 2025
// =============================================================================

`timescale 1ns/1ps

module full_adder (
  input  logic a,      // premier bit
  input  logic b,      // deuxième bit
  input  logic cin,    // carry in
  output logic sum,    // résultat (a + b + cin) LSB
  output logic cout    // carry out
);

  // Comportement combinatoire simple
  // sum = a ^ b ^ cin
  // cout = majority(a,b,cin) = (a & b) | (b & cin) | (a & cin)

  assign sum  = a ^ b ^ cin;
  assign cout = (a & b) | (b & cin) | (a & cin);

endmodule : full_adder
