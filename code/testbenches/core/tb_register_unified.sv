// =============================================================================
// Unified Testbench for Register Module
// Description: Comprehensive testbench for unified register module
// Version: Unified standard interface testing
// Compatible: Icarus Verilog / Standard Verilog
// =============================================================================

`timescale 1ns/1ps

module tb_register_unified;

  // =========================================================================
  // Parameters (matching unified module parameters)
  // =========================================================================
  parameter WIDTH = 32;
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
  reg [WIDTH-1:0] data_in;
  wire [WIDTH-1:0] data_out;
  
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
  register #(
    .WIDTH(WIDTH)
  ) dut (
    .clk(clk),
    .rst(rst),
    .data_in(data_in),
    .data_out(data_out)
  );
  
  // =========================================================================
  // Test Vector Application Task
  // =========================================================================
  task apply_test_vector;
    input [WIDTH-1:0] test_data;
    input test_reset;
    input [WIDTH-1:0] expected;
    input [200*8-1:0] test_name;  // String for test description
    
    begin
      test_count = test_count + 1;
      
      // Apply reset if required
      rst = test_reset;
      data_in = test_data;
      
      // Wait for clock edge
      @(posedge clk);
      #1;  // Small delay after clock edge
      
      // Check result
      if (data_out == expected) begin
        pass_count = pass_count + 1;
        $display(" PASS - %s", test_name);
        $display("    Input: %h, Reset: %b", test_data, test_reset);
        $display("    Expected: %h, Got: %h", expected, data_out);
      end else begin
        fail_count = fail_count + 1;
        $display(" FAIL - %s", test_name);
        $display("    Input: %h, Reset: %b", test_data, test_reset);
        $display("    Expected: %h, Got: %h", expected, data_out);
      end
      
      $display("");
    end
  endtask
  
  // =========================================================================
  // Main Test Sequence
  // =========================================================================
  initial begin
    $display("=============================================================================");
    $display("             Unified Register Testbench Started");
    $display("=============================================================================");
    
    // Initialize signals
    rst = 1;
    data_in = 0;
    
    // Wait for initial stabilization
    #(CLK_PERIOD * 2);
    
    // =====================================================================
    // Test Suite 1: Reset Functionality
    // =====================================================================
    $display("\n=== Test Suite 1: Reset Functionality ===");
    
    apply_test_vector(32'hFFFFFFFF, 1'b1, 32'h00000000, "Reset: Clear register on reset");
    apply_test_vector(32'hAAAAAAAA, 1'b1, 32'h00000000, "Reset: Reset overrides input");
    apply_test_vector(32'h55555555, 1'b1, 32'h00000000, "Reset: Consistent reset behavior");
    
    // =====================================================================
    // Test Suite 2: Normal Operation
    // =====================================================================
    $display("\n=== Test Suite 2: Normal Operation ===");
    
    rst = 0;  // Release reset for normal operation
    @(posedge clk);
    
    apply_test_vector(32'h12345678, 1'b0, 32'h12345678, "Normal: Store data 1");
    apply_test_vector(32'hABCDEF00, 1'b0, 32'hABCDEF00, "Normal: Store data 2");
    apply_test_vector(32'hDEADBEEF, 1'b0, 32'hDEADBEEF, "Normal: Store data 3");
    apply_test_vector(32'h00000000, 1'b0, 32'h00000000, "Normal: Store zeros");
    apply_test_vector(32'hFFFFFFFF, 1'b0, 32'hFFFFFFFF, "Normal: Store all ones");
    
    // =====================================================================
    // Test Suite 3: Data Persistence
    // =====================================================================
    $display("\n=== Test Suite 3: Data Persistence ===");
    
    // Store value and check it persists when input changes (but no clock edge)
    data_in = 32'h87654321;
    @(posedge clk);
    #1;
    
    if (data_out == 32'h87654321) begin
      $display("✅ Data stored correctly: %h", data_out);
      
      // Change input without clock edge
      data_in = 32'h11111111;
      #(CLK_PERIOD/4);
      
      if (data_out == 32'h87654321) begin
        pass_count = pass_count + 1;
        $display(" PASS - Data Persistence: Output unchanged without clock");
        $display("    Stored: %h, Input changed to: %h, Output: %h", 32'h87654321, 32'h11111111, data_out);
      end else begin
        fail_count = fail_count + 1;
        $display(" FAIL - Data Persistence: Output changed without clock");
        $display("    Expected: %h, Got: %h", 32'h87654321, data_out);
      end
    end else begin
      fail_count = fail_count + 1;
      $display(" FAIL - Initial storage failed");
    end
    
    test_count = test_count + 1;
    $display("");
    
    // =====================================================================
    // Test Suite 4: Reset During Operation
    // =====================================================================
    $display("\n=== Test Suite 4: Reset During Operation ===");
    
    // Store a value
    data_in = 32'hCAFEBABE;
    rst = 0;
    @(posedge clk);
    
    // Then reset it
    apply_test_vector(32'hCAFEBABE, 1'b1, 32'h00000000, "Reset During Op: Reset clears stored data");
    
    // Verify normal operation resumes after reset
    apply_test_vector(32'hFEEDFACE, 1'b0, 32'hFEEDFACE, "Post-Reset: Normal operation resumes");
    
    // =====================================================================
    // Test Suite 5: Edge Cases
    // =====================================================================
    $display("\n=== Test Suite 5: Edge Cases ===");
    
    apply_test_vector(32'h00000001, 1'b0, 32'h00000001, "Edge: Minimum non-zero value");
    apply_test_vector(32'h80000000, 1'b0, 32'h80000000, "Edge: MSB set (sign bit)");
    apply_test_vector(32'h7FFFFFFF, 1'b0, 32'h7FFFFFFF, "Edge: Maximum positive value");
    
    // Rapid changes
    for (integer i = 0; i < 5; i = i + 1) begin
      apply_test_vector(i[WIDTH-1:0], 1'b0, i[WIDTH-1:0], "Edge: Rapid sequential values");
    end
    
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
      $display(" ALL TESTS PASSED! Register module is functioning correctly.");
    end else begin
      $display(" Some tests failed. Please review the implementation.");
    end
    
    $display("=============================================================================");
    $finish;
  end

endmodule : tb_register_unified