// =============================================================================
// Unified Testbench for LSE Mult Module
// Description: Comprehensive testbench for unified lse_mult module
// Version: Unified standard interface testing
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

`timescale 1ns/1ps

module tb_lse_mult_unified;

  // =========================================================================
  // Parameters (matching unified module parameters)
  // =========================================================================
  parameter WIDTH = 24;
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
  reg [WIDTH-1:0] operand_a;
  reg [WIDTH-1:0] operand_b;
  reg [1:0] pe_mode;
  wire [WIDTH-1:0] result;
  
  // =========================================================================
  // DUT Instantiation (unified module)
  // =========================================================================
  lse_mult #(
    .WIDTH(WIDTH)
  ) dut (
    .operand_a(operand_a),
    .operand_b(operand_b),
    .pe_mode(pe_mode),
    .result(result)
  );
  
  // =========================================================================
  // Test Vector Application Task
  // =========================================================================
  task apply_test_vector;
    input [WIDTH-1:0] test_a;
    input [WIDTH-1:0] test_b;
    input [1:0] test_mode;
    input [WIDTH-1:0] expected;
    input [200*8-1:0] test_name;  // String for test description
    
    begin
      test_count = test_count + 1;
      
      // Apply inputs
      operand_a = test_a;
      operand_b = test_b;
      pe_mode = test_mode;
      
      // Wait for combinational propagation
      #1;
      
      // Check result
      if (result == expected) begin
        pass_count = pass_count + 1;
        $display("✅ PASS - %s", test_name);
        $display("    Inputs: A=%h, B=%h, Mode=%b", test_a, test_b, test_mode);
        $display("    Expected: %h, Got: %h", expected, result);
      end else begin
        fail_count = fail_count + 1;
        $display("❌ FAIL - %s", test_name);
        $display("    Inputs: A=%h, B=%h, Mode=%b", test_a, test_b, test_mode);
        $display("    Expected: %h, Got: %h", expected, result);
        $display("    Difference: %h", result - expected);
      end
      
      $display("");
    end
  endtask
  
  // =========================================================================
  // Main Test Sequence
  // =========================================================================
  initial begin
    $display("=============================================================================");
    $display("             Unified LSE Mult Testbench Started");
    $display("=============================================================================");
    
    // Initialize test variables
    operand_a = 0;
    operand_b = 0;
    pe_mode = 0;
    
    // Wait for initial stabilization
    #(CLK_PERIOD);
    
    // =====================================================================
    // Test Suite 1: 24-bit Mode Basic Operations
    // =====================================================================
    $display("\n=== Test Suite 1: 24-bit Mode Basic Multiplication ===");
    
    // log(a*b) = log(a) + log(b) in log-space
    apply_test_vector(24'h100000, 24'h200000, 2'b00, 24'h300000, "24-bit: Basic mult 1 (1+2=3)");
    apply_test_vector(24'h050000, 24'h030000, 2'b00, 24'h080000, "24-bit: Basic mult 2 (0.5+0.3=0.8)");
    apply_test_vector(24'h000000, 24'h123456, 2'b00, 24'h123456, "24-bit: Zero + Value");
    apply_test_vector(24'h123456, 24'h000000, 2'b00, 24'h123456, "24-bit: Value + Zero");
    
    // =====================================================================
    // Test Suite 2: 24-bit Mode Special Values
    // =====================================================================
    $display("\n=== Test Suite 2: 24-bit Mode Special Values ===");
    
    apply_test_vector(24'h800000, 24'h123456, 2'b00, 24'h800000, "24-bit: NEG_INF * Normal = NEG_INF");
    apply_test_vector(24'h123456, 24'h800000, 2'b00, 24'h800000, "24-bit: Normal * NEG_INF = NEG_INF");
    apply_test_vector(24'h800000, 24'h800000, 2'b00, 24'h800000, "24-bit: NEG_INF * NEG_INF = NEG_INF");
    
    // =====================================================================
    // Test Suite 3: 6-bit Mode Operations
    // =====================================================================
    $display("\n=== Test Suite 3: 6-bit Mode Operations ===");
    
    // Each 6-bit subvalue: [5:0] where bit 5 is sign, bits [4:0] are magnitude
    // Test simple additions in each lane
    apply_test_vector(24'h010203, 24'h040506, 2'b01, 24'h050709, "6-bit: Simple lane additions");
    apply_test_vector(24'h111111, 24'h111111, 2'b01, 24'h222222, "6-bit: Identical values");
    apply_test_vector(24'h000000, 24'h123456, 2'b01, 24'h123456, "6-bit: Zero + Packed value");
    
    // =====================================================================
    // Test Suite 4: 6-bit Mode Special Values
    // =====================================================================
    $display("\n=== Test Suite 4: 6-bit Mode Special Values ===");
    
    // NEG_INF in 6-bit mode is 6'b010000 (magnitude = 16)
    apply_test_vector(24'h101010, 24'h101010, 2'b01, 24'h101010, "6-bit: NEG_INF in all lanes");
    
    // =====================================================================
    // Test Suite 5: Edge Cases
    // =====================================================================
    $display("\n=== Test Suite 5: Edge Cases ===");
    
    apply_test_vector(24'hFFFFFF, 24'h000001, 2'b00, 24'h000000, "24-bit: Max + 1 (potential overflow)");
    apply_test_vector(24'h7FFFFF, 24'h000001, 2'b00, 24'h800000, "24-bit: Near-max + 1");
    
    // Test overflow protection in 6-bit mode
    apply_test_vector(24'h0F0F0F, 24'h0F0F0F, 2'b01, 24'h0F0F0F, "6-bit: Max magnitude saturation test");
    
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
      $display("🎉 ALL TESTS PASSED! LSE Mult module is functioning correctly.");
    end else begin
      $display("⚠️  Some tests failed. Please review the implementation.");
    end
    
    $display("=============================================================================");
    $finish;
  end

endmodule : tb_lse_mult_unified