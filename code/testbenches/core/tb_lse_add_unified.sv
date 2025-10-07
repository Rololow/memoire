// =============================================================================
// Unified Testbench for LSE Add Module
// Description: Comprehensive testbench for unified lse_add module
// Version: Unified standard interface testing
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

`timescale 1ns/1ps

module tb_lse_add_unified;

  // =========================================================================
  // Parameters (matching unified module parameters)
  // =========================================================================
  parameter WIDTH = 24;
  parameter LUT_SIZE = 1024;
  parameter LUT_PRECISION = 10;
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
  reg [WIDTH-1:0] operand_a;
  reg [WIDTH-1:0] operand_b;
  reg [LUT_PRECISION-1:0] lut_table [0:LUT_SIZE-1];
  reg [1:0] pe_mode;
  wire [WIDTH-1:0] result;
  wire valid_out;
  
  // =========================================================================
  // DUT Instantiation (unified module)
  // =========================================================================
  lse_add #(
    .WIDTH(WIDTH),
    .LUT_SIZE(LUT_SIZE),
    .LUT_PRECISION(LUT_PRECISION)
  ) dut (
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .lut_table(lut_table),
    .pe_mode(pe_mode),
    .result(result),
    .valid_out(valid_out)
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
      
      // Apply inputs at positive clock edge
      @(posedge clk);
      operand_a = test_a;
      operand_b = test_b;
      pe_mode = test_mode;
      
      // Wait for pipeline to process and valid_out to assert
      @(posedge clk);
      wait(valid_out);
      #1; // Small delay for signal stabilization
      
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
  // LUT Initialization Task
  // =========================================================================
  task initialize_lut;
    integer i;
    begin
      $display("Initializing LUT with %d entries...", LUT_SIZE);
      for (i = 0; i < LUT_SIZE; i = i + 1) begin
        // Simple linear correction values for testing
        lut_table[i] = i[LUT_PRECISION-1:0];
      end
      $display("LUT initialization complete.");
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
    // Test Suite 1: 24-bit Mode Basic Operations
    // =====================================================================
    $display("\n=== Test Suite 1: 24-bit Mode Basic Operations ===");
    
    apply_test_vector(24'h100000, 24'h200000, 2'b00, 24'h210000, "24-bit: Basic addition 1");
    apply_test_vector(24'h500000, 24'h300000, 2'b00, 24'h530000, "24-bit: Basic addition 2");
    apply_test_vector(24'h000000, 24'h123456, 2'b00, 24'h123456, "24-bit: Zero + Value");
    apply_test_vector(24'h123456, 24'h000000, 2'b00, 24'h123456, "24-bit: Value + Zero");
    
    // =====================================================================
    // Test Suite 2: 24-bit Mode Special Values
    // =====================================================================
    $display("\n=== Test Suite 2: 24-bit Mode Special Values ===");
    
    apply_test_vector(24'h800000, 24'h123456, 2'b00, 24'h123456, "24-bit: NEG_INF + Normal");
    apply_test_vector(24'h123456, 24'h800000, 2'b00, 24'h123456, "24-bit: Normal + NEG_INF");
    apply_test_vector(24'h800000, 24'h800000, 2'b00, 24'h800000, "24-bit: NEG_INF + NEG_INF");
    
    // =====================================================================
    // Test Suite 3: 6-bit Mode Operations
    // =====================================================================
    $display("\n=== Test Suite 3: 6-bit Mode Operations ===");
    
    apply_test_vector(24'h012345, 24'h543210, 2'b01, 24'h555555, "6-bit: Basic packed addition 1");
    apply_test_vector(24'h111111, 24'h222222, 2'b01, 24'h333333, "6-bit: Basic packed addition 2");
    apply_test_vector(24'h000000, 24'h123456, 2'b01, 24'h123456, "6-bit: Zero + Packed value");
    
    // =====================================================================
    // Test Suite 4: Edge Cases
    // =====================================================================
    $display("\n=== Test Suite 4: Edge Cases ===");
    
    apply_test_vector(24'hFFFFFF, 24'h000001, 2'b00, 24'hFFFFFF, "24-bit: Max + Min");
    apply_test_vector(24'h7FFFFF, 24'h7FFFFF, 2'b00, 24'h800000, "24-bit: Large + Large");
    
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
      $display("🎉 ALL TESTS PASSED! LSE Add module is functioning correctly.");
    end else begin
      $display("⚠️  Some tests failed. Please review the implementation.");
    end
    
    $display("=============================================================================");
    $finish;
  end

endmodule : tb_lse_add_unified