// =============================================================================
// Unified Testbench for LSE Acc Module
// Description: Comprehensive testbench for unified lse_acc module
// Version: Unified standard interface testing
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

`timescale 1ns/1ps

module tb_lse_acc_unified;

  // =========================================================================
  // Parameters (matching unified module parameters)
  // =========================================================================
  parameter INT_BITS = 12;
  parameter FRAC_BITS = 3;
  parameter WIDTH = INT_BITS + FRAC_BITS + 1;  // 16 bits total
  parameter CLK_PERIOD = 10;  // 10ns = 100MHz
  
  // =========================================================================
  // Test Control Variables
  // =========================================================================
  integer test_count = 0;
  integer pass_count = 0;
  integer fail_count = 0;
  
  // =========================================================================
  // DUT Interface Signals (standardized names)
  // =========================================================================
  reg [WIDTH-1:0] accumulator_in;
  reg [WIDTH-1:0] addend_in;
  wire [WIDTH-1:0] accumulator_out;
  
  // =========================================================================
  // DUT Instantiation (unified module)
  // =========================================================================
  lse_acc #(
    .INT_BITS(INT_BITS),
    .FRAC_BITS(FRAC_BITS),
    .WIDTH(WIDTH)
  ) dut (
    .accumulator_in(accumulator_in),
    .addend_in(addend_in),
    .accumulator_out(accumulator_out)
  );
  
  // =========================================================================
  // Test Vector Application Task
  // =========================================================================
  task apply_test_vector;
    input [WIDTH-1:0] test_acc;
    input [WIDTH-1:0] test_add;
    input [WIDTH-1:0] expected;
    input [200*8-1:0] test_name;  // String for test description
    
    begin
      test_count = test_count + 1;
      
      // Apply inputs
      accumulator_in = test_acc;
      addend_in = test_add;
      
      // Wait for combinational propagation
      #1;
      
      // Check result (allow small tolerance for LSE approximation)
      if (accumulator_out == expected || 
          ((accumulator_out > expected) ? (accumulator_out - expected) : (expected - accumulator_out)) <= 16'h0008) begin
        pass_count = pass_count + 1;
        $display("✅ PASS - %s", test_name);
        $display("    Inputs: Acc=%h, Add=%h", test_acc, test_add);
        $display("    Expected: %h, Got: %h", expected, accumulator_out);
      end else begin
        fail_count = fail_count + 1;
        $display("❌ FAIL - %s", test_name);
        $display("    Inputs: Acc=%h, Add=%h", test_acc, test_add);
        $display("    Expected: %h, Got: %h", expected, accumulator_out);
        $display("    Difference: %h", (accumulator_out > expected) ? (accumulator_out - expected) : (expected - accumulator_out));
      end
      
      $display("");
    end
  endtask
  
  // =========================================================================
  // Main Test Sequence
  // =========================================================================
  initial begin
    $display("=============================================================================");
    $display("             Unified LSE Acc Testbench Started");
    $display("=============================================================================");
    
    // Initialize test variables
    accumulator_in = 0;
    addend_in = 0;
    
    // Wait for initial stabilization
    #(CLK_PERIOD);
    
    // =====================================================================
    // Test Suite 1: Basic Accumulation Operations
    // =====================================================================
    $display("\n=== Test Suite 1: Basic Accumulation Operations ===");
    
    apply_test_vector(16'h1000, 16'h2000, 16'h2100, "Basic: Acc=0x1000 + Add=0x2000");
    apply_test_vector(16'h5000, 16'h3000, 16'h5300, "Basic: Acc=0x5000 + Add=0x3000");
    apply_test_vector(16'h0000, 16'h1234, 16'h1234, "Basic: Zero + Value");
    apply_test_vector(16'h1234, 16'h0000, 16'h1234, "Basic: Value + Zero");
    
    // =====================================================================
    // Test Suite 2: Special Values (NEG_INF)
    // =====================================================================
    $display("\n=== Test Suite 2: Special Values (NEG_INF) ===");
    
    apply_test_vector(16'b0100000000000000, 16'h1234, 16'h1234, "Special: NEG_INF + Normal = Normal");
    apply_test_vector(16'h1234, 16'b0100000000000000, 16'h1234, "Special: Normal + NEG_INF = Normal");
    apply_test_vector(16'b0100000000000000, 16'b0100000000000000, 16'b0100000000000000, "Special: NEG_INF + NEG_INF = NEG_INF");
    
    // =====================================================================
    // Test Suite 3: Sign Handling
    // =====================================================================
    $display("\n=== Test Suite 3: Sign Handling ===");
    
    // Same signs (both positive)
    apply_test_vector(16'h1000, 16'h2000, 16'h2100, "Sign: Positive + Positive");
    
    // Same signs (both negative)
    apply_test_vector(16'h9000, 16'hA000, 16'hA100, "Sign: Negative + Negative");
    
    // Different signs
    apply_test_vector(16'h5000, 16'hB000, 16'h5000, "Sign: Positive + Negative (P>N)");
    apply_test_vector(16'h3000, 16'hD000, 16'hD000, "Sign: Positive + Negative (N>P)");
    
    // =====================================================================
    // Test Suite 4: Accumulation Sequences
    // =====================================================================
    $display("\n=== Test Suite 4: Accumulation Sequences ===");
    
    // Simulate sequential accumulation
    apply_test_vector(16'h0000, 16'h1000, 16'h1000, "Seq1: Start with 0x1000");
    apply_test_vector(16'h1000, 16'h0800, 16'h1080, "Seq2: Add 0x0800");
    apply_test_vector(16'h1080, 16'h0400, 16'h1040, "Seq3: Add 0x0400");
    apply_test_vector(16'h1040, 16'h0200, 16'h1020, "Seq4: Add 0x0200");
    
    // =====================================================================
    // Test Suite 5: Edge Cases and Overflow Protection
    // =====================================================================
    $display("\n=== Test Suite 5: Edge Cases ===");
    
    apply_test_vector(16'hFFFF, 16'h0001, 16'h0000, "Edge: Max + 1 (overflow handling)");
    apply_test_vector(16'h7FFF, 16'h7FFF, 16'h8000, "Edge: Large positive values");
    apply_test_vector(16'h8000, 16'h8000, 16'h8000, "Edge: Large negative values");
    
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
      $display("🎉 ALL TESTS PASSED! LSE Acc module is functioning correctly.");
    end else begin
      $display("⚠️  Some tests failed. Please review the implementation.");
    end
    
    $display("=============================================================================");
    $finish;
  end

endmodule : tb_lse_acc_unified