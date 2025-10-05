// =============================================================================
// Unified Testbench for Einsum Mult Module
// Description: Comprehensive testbench for unified einsum_mult module
// Version: Unified standard interface testing
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

`timescale 1ns/1ps

module tb_einsum_mult_unified;

  // =========================================================================
  // Parameters (matching unified module parameters)
  // =========================================================================
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
  wire [WORD_WIDTH-1:0] product_out;
  
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
  einsum_mult #(
    .WORD_WIDTH(WORD_WIDTH)
  ) dut (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .bypass(bypass),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .pe_mode(pe_mode),
    .product_out(product_out)
  );
  
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
      if (product_out == expected) begin
        pass_count = pass_count + 1;
        $display("✅ PASS - %s", test_name);
        $display("    Inputs: A=%h, B=%h, Mode=%b, En=%b, Byp=%b", test_a, test_b, test_mode, test_enable, test_bypass);
        $display("    Expected: %h, Got: %h", expected, product_out);
      end else begin
        fail_count = fail_count + 1;
        $display("❌ FAIL - %s", test_name);
        $display("    Inputs: A=%h, B=%h, Mode=%b, En=%b, Byp=%b", test_a, test_b, test_mode, test_enable, test_bypass);
        $display("    Expected: %h, Got: %h", expected, product_out);
        if (!test_bypass) begin
          $display("    Difference: %h", (product_out > expected) ? (product_out - expected) : (expected - product_out));
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
    $display("          Unified Einsum Mult Testbench Started");
    $display("=============================================================================");
    
    // Initialize signals
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
    apply_test_vector(32'h00100000, 32'h00200000, 2'b00, 1'b1, 1'b0, 32'h00300000, "Enable=1: Normal LSE mult (log(a*b)=log(a)+log(b))");
    
    // =====================================================================
    // Test Suite 3: Bypass Functionality
    // =====================================================================
    $display("\n=== Test Suite 3: Bypass Functionality ===");
    
    apply_test_vector(32'hCAFEBABE, 32'hDEADBEEF, 2'b00, 1'b1, 1'b1, 32'hCAFEBABE, "Bypass=1: Pass operand_a");
    apply_test_vector(32'hFEEDFACE, 32'h12345678, 2'b00, 1'b1, 1'b1, 32'hFEEDFACE, "Bypass=1: Pass operand_a (test 2)");
    
    // =====================================================================
    // Test Suite 4: Normal LSE Multiplication (24-bit mode)
    // =====================================================================
    $display("\n=== Test Suite 4: Normal LSE Multiplication (24-bit mode) ===");
    
    // log(a*b) = log(a) + log(b) in log-space
    apply_test_vector(32'h00100000, 32'h00200000, 2'b00, 1'b1, 1'b0, 32'h00300000, "24-bit: Basic LSE mult 1 (1+2=3)");
    apply_test_vector(32'h00050000, 32'h00030000, 2'b00, 1'b1, 1'b0, 32'h00080000, "24-bit: Basic LSE mult 2 (0.5+0.3=0.8)");
    apply_test_vector(32'h00000000, 32'h00123456, 2'b00, 1'b1, 1'b0, 32'h00123456, "24-bit: Zero + Value");
    apply_test_vector(32'h00123456, 32'h00000000, 2'b00, 1'b1, 1'b0, 32'h00123456, "24-bit: Value + Zero");
    
    // =====================================================================
    // Test Suite 5: LSE Multiplication (6-bit mode)
    // =====================================================================
    $display("\n=== Test Suite 5: LSE Multiplication (6-bit mode) ===");
    
    apply_test_vector(32'h00010203, 32'h00040506, 2'b01, 1'b1, 1'b0, 32'h00050709, "6-bit: Packed LSE mult 1");
    apply_test_vector(32'h00111111, 32'h00111111, 2'b01, 1'b1, 1'b0, 32'h00222222, "6-bit: Packed LSE mult 2");
    apply_test_vector(32'h00000000, 32'h00123456, 2'b01, 1'b1, 1'b0, 32'h00123456, "6-bit: Zero + Packed value");
    
    // =====================================================================
    // Test Suite 6: Special Values
    // =====================================================================
    $display("\n=== Test Suite 6: Special Values ===");
    
    apply_test_vector(32'h00800000, 32'h00123456, 2'b00, 1'b1, 1'b0, 32'h00800000, "Special: NEG_INF * Normal = NEG_INF");
    apply_test_vector(32'h00123456, 32'h00800000, 2'b00, 1'b1, 1'b0, 32'h00800000, "Special: Normal * NEG_INF = NEG_INF");
    apply_test_vector(32'h00800000, 32'h00800000, 2'b00, 1'b1, 1'b0, 32'h00800000, "Special: NEG_INF * NEG_INF = NEG_INF");
    
    // =====================================================================
    // Test Suite 7: Sequential Operations
    // =====================================================================
    $display("\n=== Test Suite 7: Sequential Operations ===");
    
    // Test sequential multiplications
    apply_test_vector(32'h00100000, 32'h00020000, 2'b00, 1'b1, 1'b0, 32'h00120000, "Seq1: First multiplication");
    apply_test_vector(32'h00080000, 32'h00040000, 2'b00, 1'b1, 1'b0, 32'h000C0000, "Seq2: Second multiplication");
    apply_test_vector(32'h00060000, 32'h00050000, 2'b00, 1'b1, 1'b0, 32'h000B0000, "Seq3: Third multiplication");
    
    // =====================================================================
    // Test Suite 8: Edge Cases
    // =====================================================================
    $display("\n=== Test Suite 8: Edge Cases ===");
    
    apply_test_vector(32'h00FFFFFF, 32'h00000001, 2'b00, 1'b1, 1'b0, 32'h00000000, "Edge: Max + 1 (overflow to 0)");
    apply_test_vector(32'h007FFFFF, 32'h00000001, 2'b00, 1'b1, 1'b0, 32'h00800000, "Edge: Near-max + 1");
    
    // Test overflow protection in 6-bit mode
    apply_test_vector(32'h000F0F0F, 32'h000F0F0F, 2'b01, 1'b1, 1'b0, 32'h000F0F0F, "Edge: 6-bit overflow saturation");
    
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
      $display("🎉 ALL TESTS PASSED! Einsum Mult module is functioning correctly.");
    end else begin
      $display("⚠️  Some tests failed. Please review the implementation.");
    end
    
    $display("=============================================================================");
    $finish;
  end

endmodule : tb_einsum_mult_unified