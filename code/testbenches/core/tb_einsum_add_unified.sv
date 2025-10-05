// =============================================================================
// Unified Testbench for Einsum Add Module
// Description: Comprehensive testbench for unified einsum_add module
// Version: Unified standard interface testing
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

`timescale 1ns/1ps

module tb_einsum_add_unified;

  // =========================================================================
  // Parameters (matching unified module parameters)
  // =========================================================================
  parameter LUT_SIZE = 1024;
  parameter LUT_PRECISION = 10;
  parameter WORD_WIDTH = 32;
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
  reg clk;
  reg rst;
  reg enable;
  reg bypass;
  reg [WORD_WIDTH-1:0] operand_a;
  reg [WORD_WIDTH-1:0] operand_b;
  reg [1:0] pe_mode;
  reg [LUT_PRECISION-1:0] lut_table [0:LUT_SIZE-1];
  wire [WORD_WIDTH-1:0] sum_out;
  
  // =========================================================================
  // Clock Generation
  // =========================================================================
  initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
  end
  
  // =========================================================================
  // DUT Instantiation (unified module)
  // =========================================================================
  einsum_add #(
    .LUT_SIZE(LUT_SIZE),
    .LUT_PRECISION(LUT_PRECISION),
    .WORD_WIDTH(WORD_WIDTH)
  ) dut (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .bypass(bypass),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .pe_mode(pe_mode),
    .lut_table(lut_table),
    .sum_out(sum_out)
  );
  
  // =========================================================================
  // LUT Initialization Task
  // =========================================================================
  task initialize_lut;
    integer i;
    begin
      for (i = 0; i < LUT_SIZE; i = i + 1) begin
        lut_table[i] = i[LUT_PRECISION-1:0];
      end
    end
  endtask
  
  // =========================================================================
  // Test Vector Application Task
  // =========================================================================
  task apply_test_vector;
    input [WORD_WIDTH-1:0] test_a;
    input [WORD_WIDTH-1:0] test_b;
    input [1:0] test_mode;
    input test_enable;
    input test_bypass;
    input [WORD_WIDTH-1:0] expected;
    input [200*8-1:0] test_name;  // String for test description
    
    begin
      test_count = test_count + 1;
      
      // Apply inputs
      operand_a = test_a;
      operand_b = test_b;
      pe_mode = test_mode;
      enable = test_enable;
      bypass = test_bypass;
      
      // Wait for clock edge and propagation
      @(posedge clk);
      #1;
      
      // Check result
      if (sum_out == expected) begin
        pass_count = pass_count + 1;
        $display("✅ PASS - %s", test_name);
        $display("    Inputs: A=%h, B=%h, Mode=%b, En=%b, Byp=%b", test_a, test_b, test_mode, test_enable, test_bypass);
        $display("    Expected: %h, Got: %h", expected, sum_out);
      end else begin
        fail_count = fail_count + 1;
        $display("❌ FAIL - %s", test_name);
        $display("    Inputs: A=%h, B=%h, Mode=%b, En=%b, Byp=%b", test_a, test_b, test_mode, test_enable, test_bypass);
        $display("    Expected: %h, Got: %h", expected, sum_out);
        if (!test_bypass) begin
          $display("    Difference: %h", (sum_out > expected) ? (sum_out - expected) : (expected - sum_out));
        end
      end
      
      $display("");
    end
  endtask
  
  // =========================================================================
  // Main Test Sequence
  // =========================================================================
  initial begin
    $display("=============================================================================");
    $display("           Unified Einsum Add Testbench Started");
    $display("=============================================================================");
    
    // Initialize LUT and signals
    initialize_lut();
    rst = 1;
    enable = 0;
    bypass = 0;
    operand_a = 0;
    operand_b = 0;
    pe_mode = 0;
    
    // Wait for reset
    #(CLK_PERIOD * 2);
    rst = 0;
    #(CLK_PERIOD);
    
    // =====================================================================
    // Test Suite 1: Reset Functionality
    // =====================================================================
    $display("\n=== Test Suite 1: Reset Functionality ===");
    
    rst = 1;
    apply_test_vector(32'hFFFFFFFF, 32'hAAAAAAAA, 2'b00, 1'b1, 1'b0, 32'h00000000, "Reset: Output cleared on reset");
    rst = 0;
    
    // =====================================================================
    // Test Suite 2: Enable/Disable Functionality
    // =====================================================================
    $display("\n=== Test Suite 2: Enable/Disable Functionality ===");
    
    // Test with enable = 0 (should maintain previous value or stay at 0)
    apply_test_vector(32'h12345678, 32'h87654321, 2'b00, 1'b0, 1'b0, 32'h00000000, "Enable=0: Output should not change");
    
    // Test with enable = 1
    apply_test_vector(32'h00100000, 32'h00200000, 2'b00, 1'b1, 1'b0, 32'h00210000, "Enable=1: Normal LSE operation");
    
    // =====================================================================
    // Test Suite 3: Bypass Functionality
    // =====================================================================
    $display("\n=== Test Suite 3: Bypass Functionality ===");
    
    apply_test_vector(32'hCAFEBABE, 32'hDEADBEEF, 2'b00, 1'b1, 1'b1, 32'hCAFEBABE, "Bypass=1: Pass operand_a");
    apply_test_vector(32'hFEEDFACE, 32'h12345678, 2'b00, 1'b1, 1'b1, 32'hFEEDFACE, "Bypass=1: Pass operand_a (test 2)");
    
    // =====================================================================
    // Test Suite 4: Normal LSE Addition (24-bit mode)
    // =====================================================================
    $display("\n=== Test Suite 4: Normal LSE Addition (24-bit mode) ===");
    
    apply_test_vector(32'h00100000, 32'h00200000, 2'b00, 1'b1, 1'b0, 32'h00210000, "24-bit: Basic LSE add 1");
    apply_test_vector(32'h00500000, 32'h00300000, 2'b00, 1'b1, 1'b0, 32'h00530000, "24-bit: Basic LSE add 2");
    apply_test_vector(32'h00000000, 32'h00123456, 2'b00, 1'b1, 1'b0, 32'h00123456, "24-bit: Zero + Value");
    
    // =====================================================================
    // Test Suite 5: LSE Addition (6-bit mode)
    // =====================================================================
    $display("\n=== Test Suite 5: LSE Addition (6-bit mode) ===");
    
    apply_test_vector(32'h00012345, 32'h00543210, 2'b01, 1'b1, 1'b0, 32'h00555555, "6-bit: Packed LSE add 1");
    apply_test_vector(32'h00111111, 32'h00222222, 2'b01, 1'b1, 1'b0, 32'h00333333, "6-bit: Packed LSE add 2");
    
    // =====================================================================
    // Test Suite 6: Special Values
    // =====================================================================
    $display("\n=== Test Suite 6: Special Values ===");
    
    apply_test_vector(32'h00800000, 32'h00123456, 2'b00, 1'b1, 1'b0, 32'h00123456, "Special: NEG_INF + Normal");
    apply_test_vector(32'h00123456, 32'h00800000, 2'b00, 1'b1, 1'b0, 32'h00123456, "Special: Normal + NEG_INF");
    
    // =====================================================================
    // Test Suite 7: Sequential Operations
    // =====================================================================
    $display("\n=== Test Suite 7: Sequential Operations ===");
    
    // Test accumulative behavior
    apply_test_vector(32'h00100000, 32'h00080000, 2'b00, 1'b1, 1'b0, 32'h00108000, "Seq1: First addition");
    apply_test_vector(32'h00200000, 32'h00040000, 2'b00, 1'b1, 1'b0, 32'h00204000, "Seq2: Second addition");
    apply_test_vector(32'h00300000, 32'h00020000, 2'b00, 1'b1, 1'b0, 32'h00302000, "Seq3: Third addition");
    
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
      $display("🎉 ALL TESTS PASSED! Einsum Add module is functioning correctly.");
    end else begin
      $display("⚠️  Some tests failed. Please review the implementation.");
    end
    
    $display("=============================================================================");
    $finish;
  end

endmodule : tb_einsum_add_unified