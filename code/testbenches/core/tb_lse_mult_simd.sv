// =============================================================================
// Testbench: tb_lse_mult_simd
// Objectif : valider le module lse_mult_simd pour les trois modes SIMD
//  - 00 : addition complète 24 bits
//  - 01 : deux lanes indépendantes de 12 bits
//  - 10 : quatre lanes indépendantes de 6 bits
// =============================================================================

`timescale 1ns/1ps

module tb_lse_mult_simd;

  // ---------------------------------------------------------------------------
  // DUT interface
  // ---------------------------------------------------------------------------
  logic [23:0] operand_a;
  logic [23:0] operand_b;
  logic [1:0]  simd_mode;
  logic [23:0] result;

  // Instantiation du DUT
  lse_mult_simd dut (
    .operand_a (operand_a),
    .operand_b (operand_b),
    .simd_mode (simd_mode),
    .result    (result)
  );

  // Compteurs de tests
  int total_tests = 0;
  int pass_count  = 0;
  int fail_count  = 0;

  // ---------------------------------------------------------------------------
  // Fonctions utilitaires
  // ---------------------------------------------------------------------------

  function automatic logic [11:0] lane_add12(input logic [11:0] x, input logic [11:0] y);
    logic [12:0] tmp;
    begin
      tmp = x + y;
      return tmp[11:0];
    end
  endfunction

  function automatic logic [5:0] lane_add6(input logic [5:0] x, input logic [5:0] y);
    logic [6:0] tmp;
    begin
      tmp = x + y;
      return tmp[5:0];
    end
  endfunction

  // Calcule l'attendu en fonction du mode SIMD
  function automatic logic [23:0] expected_sum(
    input logic [23:0] a,
    input logic [23:0] b,
    input logic [1:0]  mode
  );
    case (mode)
      2'b00: expected_sum = (a + b) & 24'hFFFFFF; // addition scalaire 24 bits
      2'b01: begin
        expected_sum[11:0]  = lane_add12(a[11:0],  b[11:0]);
        expected_sum[23:12] = lane_add12(a[23:12], b[23:12]);
      end
      2'b10: begin
        expected_sum[5:0]   = lane_add6(a[5:0],   b[5:0]);
        expected_sum[11:6]  = lane_add6(a[11:6],  b[11:6]);
        expected_sum[17:12] = lane_add6(a[17:12], b[17:12]);
        expected_sum[23:18] = lane_add6(a[23:18], b[23:18]);
      end
      default: expected_sum = 24'hXXXXXX;
    endcase
  endfunction

  // Applique un test et vérifie la sortie
  task automatic run_test(
    input string       name,
    input logic [23:0] a,
    input logic [23:0] b,
    input logic [1:0]  mode
  );
    logic [23:0] expected;
    begin
      total_tests++;

      operand_a = a;
      operand_b = b;
      simd_mode = mode;

      #1;  // temps de convergence combinatoire

      expected = expected_sum(a, b, mode);

      if (result === expected) begin
        pass_count++;
        $display(" PASS - %s | mode=%b | A=%h B=%h -> %h", name, mode, a, b, result);
      end else begin
        fail_count++;
        $display(" FAIL - %s | mode=%b", name, mode);
        $display("    A       : %h", a);
        $display("    B       : %h", b);
        $display("    Expected: %h", expected);
        $display("    Got     : %h", result);
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Séquence de tests
  // ---------------------------------------------------------------------------
  initial begin
    $display("===============================================================");
    $display("           Testbench lse_mult_simd - Validation modes");
    $display("===============================================================");

    // Mode 00 : 1 × 24 bits
    run_test("24-bit simple",       24'h000123, 24'h000111, 2'b00);
    run_test("24-bit carry propagate", 24'h00FFFF, 24'h000001, 2'b00);
    run_test("24-bit overflow wrap",   24'hFFFFFF, 24'h000001, 2'b00);

    // Mode 01 : 2 × 12 bits
    run_test("2×12 independent",    24'hABCDEF, 24'h111111, 2'b01);
    run_test("2×12 carry cut",       24'hFFF000, 24'h001FFF, 2'b01);
    run_test("2×12 wrap both lanes", 24'hFFFEEE, 24'h001234, 2'b01);

    // Mode 10 : 4 × 6 bits
    run_test("4×6 independent",      24'h123456, 24'h010101, 2'b10);
    run_test("4×6 carry cut",        24'h3F003F, 24'h010101, 2'b10);
    run_test("4×6 wrap",             24'h3F3F3F, 24'h010101, 2'b10);

    // Résumé
    $display("===============================================================");
    $display("Tests terminés : %0d", total_tests);
    $display("Pass           : %0d", pass_count);
    $display("Fail           : %0d", fail_count);
    if (fail_count == 0) begin
      $display("Tous les tests ont réussi !");
    end else begin
      $display("Des erreurs subsistent. Voir logs ci-dessus.");
    end
    $display("===============================================================");

    $finish;
  end

endmodule : tb_lse_mult_simd
