// =============================================================================
// Unified Testbench for LSE Add Module (Algorithm 1 Implementation)
// Description: Comprehensive testbench for LSE-PE algorithm implementation
// Version: Testing Algorithm 1 from NeurIPS 2024 paper
// Reference: Yao et al., "LSE-PE: Hardware Efficient for Tractable Probabilistic Reasoning"
// =============================================================================

`timescale 1ns/1ps

`include "reference/lse_add_reference_vectors.svh"

module tb_lse_add_unified;

  // =========================================================================
  // Parameters (matching unified module parameters)
  // =========================================================================
  parameter WIDTH = 24;
  parameter LUT_SIZE = 16;
  parameter LUT_PRECISION = 10;
  parameter FRAC_BITS = 10;
  parameter CLK_PERIOD = 10;  // 10ns = 100MHz
  
  // Mathematical constants for verification
  parameter real LOG2_E = 1.442695040888963;  // log2(e)
  
  // =========================================================================
  // Test Control Variables
  // =========================================================================
  integer test_count = 0;
  integer pass_count = 0;
  integer fail_count = 0;
  
  // =========================================================================
  // DUT Interface Signals (standardized names)
  // =========================================================================
  reg clk;
  reg rst;
  reg enable;
  reg [WIDTH-1:0] operand_a;
  reg [WIDTH-1:0] operand_b;
  reg [LUT_PRECISION-1:0] clut_values [0:LUT_SIZE-1];
  reg [1:0] pe_mode;
  wire [WIDTH-1:0] result;
  wire valid_out;
  
  // =========================================================================
  // DUT Instantiation (unified module)
  // =========================================================================
  lse_add #(
    .WIDTH(WIDTH),
    .LUT_PRECISION(LUT_PRECISION)
  ) dut (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .clut_values(clut_values),
    .pe_mode(pe_mode),
    .result(result),
    .valid_out(valid_out)
  );
  
  // =========================================================================
  // Helper Functions for LSE Calculation
  // =========================================================================
  
  // Convert fixed-point to real
  function real fixed_to_real;
    input [WIDTH-1:0] fixed_val;
    begin
      // Special encoding: highest-bit pattern reserved for NEG_INF sentinel
      // e.g., 24'h800000 is used by the tests to indicate -infinity in log-domain
      if (fixed_val == {1'b1, {(WIDTH-1){1'b0}}}) begin
        // Return negative infinity so lse_reference and comparisons behave correctly
        fixed_to_real = -1.0/0.0; // -inf
      end else begin
        fixed_to_real = $itor(fixed_val) / (2.0 ** FRAC_BITS);
      end
    end
  endfunction
  
  // Convert real to fixed-point
  function [WIDTH-1:0] real_to_fixed;
    input real real_val;
    begin
      real_to_fixed = $rtoi(real_val * (2.0 ** FRAC_BITS));
    end
  endfunction
  
  // Calculate expected LSE result (software reference)
  function real lse_reference;
    input real x;
    input real y;
    real max_val, min_val, delta;
    begin
      if (x >= y) begin
        max_val = x;
        min_val = y;
      end else begin
        max_val = y;
        min_val = x;
      end
      
      delta = max_val - min_val;
      
      // LSE(x,y) = max + log2(1 + 2^(-delta))
      if (delta > 20.0) begin
        // For large delta, contribution is negligible
        lse_reference = max_val;
      end else begin
        lse_reference = max_val + ($ln(1.0 + $pow(2.0, -delta)) / $ln(2.0));
      end
    end
  endfunction
  
  // =========================================================================
  // Test Vector Application Task with Tolerance
  // =========================================================================
  task automatic apply_test_vector(
    input [WIDTH-1:0] test_a,
    input [WIDTH-1:0] test_b,
    input [1:0] test_mode,
    input [WIDTH-1:0] expected_min,  // Minimum acceptable value
    input [WIDTH-1:0] expected_max,  // Maximum acceptable value
    input string test_name,          // Human-readable label
    input bit has_reference_exact = 1'b0,
    input real reference_exact = 0.0,
    input real reference_tolerance = 0.0
  );
  real a_real, b_real, result_real, reference_real, tolerance_real, error_value;

    begin
      test_count = test_count + 1;
      
      // Apply inputs at positive clock edge
      @(posedge clk);
      operand_a = test_a;
      operand_b = test_b;
      pe_mode = test_mode;
      
      // Wait for pipeline to process and valid_out to assert
      @(posedge clk);
      wait(valid_out);
      #1; // Small delay for signal stabilization
      
      // Convert to real for display
      a_real = fixed_to_real(test_a);
      b_real = fixed_to_real(test_b);
      result_real = fixed_to_real(result);
      
      if (has_reference_exact) begin
        reference_real = reference_exact;
        tolerance_real = reference_tolerance;
      end else begin
        reference_real = lse_reference(a_real, b_real);
        tolerance_real = (fixed_to_real(expected_max) - fixed_to_real(expected_min)) / 2.0;
      end
      
      // Check result within tolerance range
      if (result >= expected_min && result <= expected_max) begin
        pass_count = pass_count + 1;
        $display(" PASS - %s", test_name);
        $display("    Inputs: A=%h (%.3f), B=%h (%.3f), Mode=%b", 
                 test_a, a_real, test_b, b_real, test_mode);
        $display("    Expected: [%h, %h], Got: %h (%.3f)", 
                 expected_min, expected_max, result, result_real);
      end else begin
        fail_count = fail_count + 1;
        $display(" FAIL - %s", test_name);
        $display("    Inputs: A=%h (%.3f), B=%h (%.3f), Mode=%b", 
                 test_a, a_real, test_b, b_real, test_mode);
        $display("    Expected: [%h, %h], Got: %h (%.3f)", 
                 expected_min, expected_max, result, result_real);
      end

      error_value = result_real - reference_real;
      $display("    Error (Result - Reference): %.6f", error_value);

      if (has_reference_exact) begin
        $display("    Exact reference: %.6f", reference_real);
        $display("    Allowed tolerance: +/-%.6f", tolerance_real);
      end else begin
        $display("    Reference (computed): %.3f", reference_real);
        if (expected_max != expected_min) begin
          $display("    Allowed tolerance: +/-%.6f", tolerance_real);
        end
      end
      
      $display("");
    end
  endtask
  
  // Exact test vector (for special cases)
  task automatic apply_exact_test(
    input [WIDTH-1:0] test_a,
    input [WIDTH-1:0] test_b,
    input [1:0] test_mode,
    input [WIDTH-1:0] expected,
    input string test_name
  );
    begin
      apply_test_vector(test_a, test_b, test_mode, expected, expected, test_name);
    end
  endtask
  
  // =========================================================================
  // LUT Initialization Task (CLUT values)
  // =========================================================================
  task initialize_lut;
    integer i;
    const logic [LUT_PRECISION-1:0] CLUT_INIT [0:LUT_SIZE-1] = '{
      10'b0000000000,
      10'b0000011001,
      10'b0000101101,
      10'b0000110000,
      10'b0001001001,
      10'b0001000000,
      10'b0000111111,
      10'b0001000110,
      10'b0001010110,
      10'b0001000010,
      10'b0000110001,
      10'b0000100010,
      10'b0000010110,
      10'b0000001100,
      10'b0000000101,
      10'b0000000001
    };
    begin
      $display("Initializing CLUT with %d entries...", LUT_SIZE);
      for (i = 0; i < LUT_SIZE; i = i + 1) begin
        clut_values[i] = CLUT_INIT[i];
        $display("  Entry %0d: %010b", i, clut_values[i]);
      end
      $display("CLUT initialization complete.");
    end
  endtask
  
  // =========================================================================
  // Clock Generation
  // =========================================================================
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  // =========================================================================
  // Main Test Sequence
  // =========================================================================
  initial begin
    int ref_idx;
    $display("=============================================================================");
    $display("              Unified LSE Add Testbench Started");
    $display("=============================================================================");
    
    // Initialize control signals
    rst = 1;
    enable = 0;
    operand_a = 0;
    operand_b = 0;
    pe_mode = 0;
    
    // Initialize LUT
    initialize_lut();
    
    // Release reset and enable module
    #(CLK_PERIOD * 2);
    rst = 0;
    enable = 1;
    
    // Wait for initial stabilization
    #(CLK_PERIOD);

    // =====================================================================
    // Test Suite 0: Auto-generated high-precision reference vectors
    // =====================================================================
    if (LSE_ADD_REFERENCE_VECTOR_COUNT > 0) begin
      $display("\n=== Test Suite 0: Auto-generated Reference Vectors ===");
      for (ref_idx = 0; ref_idx < LSE_ADD_REFERENCE_VECTOR_COUNT; ref_idx++) begin
        automatic lse_add_reference_vector_t vec = LSE_ADD_REFERENCE_VECTORS[ref_idx];
        automatic string label = (vec.label.len() != 0)
          ? vec.label
          : $sformatf("reference_vector_%0d", ref_idx);
        apply_test_vector(
          vec.operand_a,
          vec.operand_b,
          2'b00,
          vec.min_expected,
          vec.max_expected,
          label,
          1'b1,
          vec.exact_value,
          vec.error_tolerance
        );
      end
    end else begin
      $display("\n=== Test Suite 0: Auto-generated Reference Vectors (missing) ===");
      $display("No reference vectors found. Run scripts/python/generate_lse_add_vectors.py to populate them.");
    end
    
    // =====================================================================
    // Test Suite 1: Special Values (Exact matches required)
    // =====================================================================
    $display("\n=== Test Suite 1: Special Values (NEG_INF handling) ===");
    
    apply_exact_test(24'h800000, 24'h123456, 2'b00, 24'h123456, "NEG_INF + Normal = Normal");
    apply_exact_test(24'h123456, 24'h800000, 2'b00, 24'h123456, "Normal + NEG_INF = Normal");
    apply_exact_test(24'h800000, 24'h800000, 2'b00, 24'h800000, "NEG_INF + NEG_INF = NEG_INF");
    
    // =====================================================================
    // Test Suite 2: Close Values (Small Delta)
    // =====================================================================
    $display("\n=== Test Suite 2: Close Values (Small Delta) ===");
    
    // Test: 5.0 + 4.5 (delta = 0.5)
    // Expected: max(5.0, 4.5) + log2(1 + 2^(-0.5)) ≈ 5.0 + 0.585 = 5.585
    apply_test_vector(24'h001400, 24'h001200, 2'b00, 24'h001580, 24'h0015C0,
                     "LSE(5.0, 4.5) ≈ 5.585");
    
    // Test: 10.0 + 10.0 (equal values)
    // Expected: 10.0 + log2(2) = 10.0 + 1.0 = 11.0
    apply_test_vector(24'h002800, 24'h002800, 2'b00, 24'h002BF0, 24'h002C10,
                     "LSE(10.0, 10.0) = 11.0");
    
    // Test: 3.0 + 2.0 (delta = 1.0)
    // Expected: 3.0 + log2(1 + 2^(-1.0)) ≈ 3.0 + 0.585 = 3.585
    apply_test_vector(24'h000C00, 24'h000800, 2'b00, 24'h000E50, 24'h000E90,
                     "LSE(3.0, 2.0) ≈ 3.585");
    
    // =====================================================================
    // Test Suite 3: Medium Distance (Medium Delta)
    // =====================================================================
    $display("\n=== Test Suite 3: Medium Distance Values ===");
    
    // Test: 10.0 + 5.0 (delta = 5.0)
    // Expected: 10.0 + log2(1 + 2^(-5.0)) ≈ 10.0 + 0.044 = 10.044
    apply_test_vector(24'h002800, 24'h001400, 2'b00, 24'h002820, 24'h002850,
                     "LSE(10.0, 5.0) ≈ 10.044");
    
    // Test: 8.0 + 4.0 (delta = 4.0)
    // Expected: 8.0 + log2(1 + 2^(-4.0)) ≈ 8.0 + 0.087 = 8.087
    apply_test_vector(24'h002000, 24'h001000, 2'b00, 24'h002050, 24'h002080,
                     "LSE(8.0, 4.0) ≈ 8.087");
    
    // =====================================================================
    // Test Suite 4: Large Distance (Large Delta)
    // =====================================================================
    $display("\n=== Test Suite 4: Large Distance Values ===");
    
    // Test: 20.0 + 2.0 (delta = 18.0)
    // Expected: ≈ 20.0 (negligible contribution)
    apply_test_vector(24'h005000, 24'h000800, 2'b00, 24'h005000, 24'h005010,
                     "LSE(20.0, 2.0) ≈ 20.0");
    
    // Test: 15.0 + 5.0 (delta = 10.0)
    // Expected: ≈ 15.0 (very small contribution)
    apply_test_vector(24'h003C00, 24'h001400, 2'b00, 24'h003C00, 24'h003C08,
                     "LSE(15.0, 5.0) ≈ 15.0");
    
    // =====================================================================
    // Test Suite 5: Commutative Property
    // =====================================================================
    $display("\n=== Test Suite 5: Commutative Property LSE(a,b) = LSE(b,a) ===");
    
    // Store first result
    operand_a = 24'h001800; // 6.0
    operand_b = 24'h001000; // 4.0
    pe_mode = 2'b00;
    @(posedge clk);
    @(posedge clk);
    wait(valid_out);
    #1;
    begin
      automatic logic [WIDTH-1:0] result1 = result;
      
      // Swap and test again
      operand_a = 24'h001000; // 4.0
      operand_b = 24'h001800; // 6.0
      @(posedge clk);
      @(posedge clk);
      wait(valid_out);
      #1;
      
      test_count = test_count + 1;
      if (result == result1) begin
        pass_count = pass_count + 1;
        $display(" PASS - Commutative: LSE(6.0, 4.0) = LSE(4.0, 6.0)");
        $display("    Both results: %h", result);
      end else begin
        fail_count = fail_count + 1;
        $display(" FAIL - Commutative: LSE(6.0, 4.0) != LSE(4.0, 6.0)");
        $display("    Result1: %h, Result2: %h", result1, result);
      end
      $display("");
    end
    
    // =====================================================================
    // Test Suite 6: Zero Handling
    // =====================================================================
    $display("\n=== Test Suite 6: Zero Value Handling ===");
    
    apply_test_vector(24'h000000, 24'h001000, 2'b00, 24'h001000, 24'h001020,
                     "LSE(0.0, 4.0)");
    apply_test_vector(24'h001000, 24'h000000, 2'b00, 24'h001000, 24'h001020,
                     "LSE(4.0, 0.0)");
    apply_test_vector(24'h000000, 24'h000000, 2'b00, 24'h000000, 24'h000010,
                     "LSE(0.0, 0.0)");
    
  // SIMD mode deprecated: only scalar 24-bit tests remain in this testbench.
    // =====================================================================
    // Test Suite 8: Edge Cases and Overflow
    // =====================================================================
    $display("\n=== Test Suite 8: Edge Cases and Overflow ===");
    
    // Large values that might overflow
    apply_test_vector(24'h7FFFFF, 24'h7FFFFE, 2'b00, 24'h7FFFFF, 24'hFFFFFF,
                     "Large values near overflow");
    
    // Maximum representable value
    apply_test_vector(24'h7FFFFF, 24'h000001, 2'b00, 24'h7FFFFF, 24'h800010,
                     "Max value + small value");
    
    // =====================================================================
    // Test Results Summary
    // =====================================================================
    #(CLK_PERIOD * 5);
    
    $display("\n=============================================================================");
    $display("                        Test Results Summary");
    $display("=============================================================================");
    $display("Total Tests: %0d", test_count);
    $display("Passed:      %0d (%.1f%%)", pass_count, (pass_count * 100.0) / test_count);
    $display("Failed:      %0d (%.1f%%)", fail_count, (fail_count * 100.0) / test_count);
    $display("=============================================================================");
    
    if (fail_count == 0) begin
      $display(" ALL TESTS PASSED! LSE Add module is functioning correctly.");
    end else begin
      $display(" Some tests failed. Please review the implementation.");
    end
    
    $display("=============================================================================");
    $finish;
  end

endmodule : tb_lse_add_unified