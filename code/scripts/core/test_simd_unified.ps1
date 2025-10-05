# =============================================================================
# SIMD Modules Test Script
# Description: Automated testing for all SIMD LSE modules
# Version: 1.0
# Compatible: PowerShell 5.1+
# =============================================================================

param(
    [string]$ModuleName = "all",      # Specific module to test or "all"
    [switch]$Verbose = $false,        # Show detailed output
    [switch]$Summary = $false         # Show only summary
)

# Project paths
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$MODULES_DIR = "$PROJECT_ROOT\modules\simd"
$TESTBENCHES_DIR = "$PROJECT_ROOT\testbenches\simd"
$CORE_MODULES_DIR = "$PROJECT_ROOT\modules\core"
$WORK_DIR = "$PROJECT_ROOT\work"

# Tools
$IVERILOG = "C:\iverilog\bin\iverilog.exe"
$VVP = "C:\iverilog\bin\vvp.exe"

# SIMD modules configuration
$SIMD_MODULES = @{
    "lse_simd_2x12b" = @{
        "module_file" = "lse_simd_2x12b.sv"
        "testbench_file" = "tb_lse_simd_2x12b_unified.sv"
        "description" = "Dual 12-bit LSE SIMD"
        "dependencies" = @("lse_add_adaptive.sv")
        "expected_tests" = 8
    }
    "lse_simd_4x6b" = @{
        "module_file" = "lse_simd_4x6b.sv"
        "testbench_file" = "tb_lse_simd_4x6b_unified.sv"
        "description" = "Quad 6-bit LSE SIMD"
        "dependencies" = @("lse_add_adaptive.sv")
        "expected_tests" = 15
    }
    "lse_simd_unified" = @{
        "module_file" = "lse_simd_unified.sv"
        "testbench_file" = "tb_lse_simd_unified.sv"
        "description" = "Unified Multi-Precision SIMD"
        "dependencies" = @("lse_add_adaptive.sv", "lse_simd_2x12b.sv", "lse_simd_4x6b.sv")
        "expected_tests" = 20
    }
}

# =============================================================================
# Utility Functions
# =============================================================================

function Write-TestHeader {
    param([string]$ModuleName, [string]$Description)
    
    Write-Host "`n📋 Testing Module: $ModuleName" -ForegroundColor Cyan
    Write-Host "   Description: $Description" -ForegroundColor Gray
    Write-Host "    + ------------------------------------------------------------" -ForegroundColor DarkGray
}

function Write-TestResult {
    param([string]$Level, [string]$Message, [string]$Color = "White")
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Level - $Message" -ForegroundColor $Color
}

function Test-SIMDModule {
    param(
        [string]$ModuleName,
        [hashtable]$ModuleConfig
    )
    
    Write-TestHeader -ModuleName $ModuleName -Description $ModuleConfig.description
    
    $module_path = Join-Path $MODULES_DIR $ModuleConfig.module_file
    $testbench_path = Join-Path $TESTBENCHES_DIR $ModuleConfig.testbench_file
    $output_file = "test_simd_$ModuleName.out"
    
    # Verify files exist
    if (!(Test-Path $module_path)) {
        Write-TestResult "ERROR" "Module file not found: $module_path" "Red"
        return @{ success = $false; error = "Module file missing" }
    }
    
    if (!(Test-Path $testbench_path)) {
        Write-TestResult "ERROR" "Testbench file not found: $testbench_path" "Red"
        return @{ success = $false; error = "Testbench file missing" }
    }
    
    Write-TestResult "INFO" "Compiling SIMD module and testbench..." "Cyan"
    
    # Prepare compilation arguments
    $compile_args = @(
        "-g2012"                    # SystemVerilog 2012
        "-o", $output_file          # Output executable
        $testbench_path             # Testbench file
        $module_path                # Module file
    )
    
    # Add dependencies from core modules
    if ($ModuleConfig.ContainsKey("dependencies")) {
        foreach ($dep in $ModuleConfig.dependencies) {
            # Check if it's a core module or SIMD module
            $core_dep_path = Join-Path $CORE_MODULES_DIR $dep
            $simd_dep_path = Join-Path $MODULES_DIR $dep
            
            if (Test-Path $core_dep_path) {
                $compile_args += $core_dep_path
                Write-TestResult "INFO" "Including core dependency: $dep" "Yellow"
            } elseif (Test-Path $simd_dep_path) {
                $compile_args += $simd_dep_path
                Write-TestResult "INFO" "Including SIMD dependency: $dep" "Yellow"
            } else {
                Write-TestResult "WARNING" "Dependency not found: $dep" "Yellow"
            }
        }
    }
    
    try {
        # Change to work directory for compilation
        Set-Location $WORK_DIR
        
        $compile_process = Start-Process -FilePath $IVERILOG -ArgumentList $compile_args -Wait -NoNewWindow -PassThru -RedirectStandardError "compile_error.log" -RedirectStandardOutput "compile_output.log"
        
        if ($compile_process.ExitCode -ne 0) {
            $error_content = Get-Content "compile_error.log" -ErrorAction SilentlyContinue
            Write-TestResult "ERROR" "Compilation failed (Exit Code: $($compile_process.ExitCode))" "Red"
            if ($Verbose -and $error_content) {
                Write-Host "   Compilation errors:" -ForegroundColor Red
                $error_content | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
            }
            return @{ success = $false; error = "Compilation failed"; exit_code = $compile_process.ExitCode }
        }
        
        Write-TestResult "SUCCESS" "Compilation successful" "Green"
        
        # Run simulation
        Write-TestResult "INFO" "Running SIMD simulation..." "Cyan"
        
        $sim_process = Start-Process -FilePath $VVP -ArgumentList @($output_file) -Wait -NoNewWindow -PassThru -RedirectStandardOutput "sim_output.log" -RedirectStandardError "sim_error.log"
        
        if ($sim_process.ExitCode -ne 0) {
            Write-TestResult "ERROR" "Simulation failed (Exit Code: $($sim_process.ExitCode))" "Red"
            return @{ success = $false; error = "Simulation failed" }
        }
        
        Write-TestResult "SUCCESS" "Simulation completed" "Green"
        
        # Parse results
        $sim_output = Get-Content "sim_output.log" -ErrorAction SilentlyContinue
        $test_results = Parse-SIMDTestResults -Output $sim_output -ModuleName $ModuleName
        
        # Display results
        Write-Host "   📊 Test Results:" -ForegroundColor White
        Write-Host "     Total Tests: $($test_results.total)" -ForegroundColor White
        Write-Host "     Passed:      $($test_results.passed) ($($test_results.pass_rate)%)" -ForegroundColor Green
        Write-Host "     Failed:      $($test_results.failed) ($($test_results.fail_rate)%)" -ForegroundColor Red
        
        if ($test_results.failed -eq 0) {
            Write-TestResult "SUCCESS" "All tests passed! ✅" "Green"
            return @{ success = $true; status = "all_passed"; results = $test_results }
        } else {
            Write-TestResult "WARNING" "Some tests failed ⚠️" "Yellow"
            return @{ success = $true; status = "some_failed"; results = $test_results }
        }
        
    }
    catch {
        Write-TestResult "ERROR" "Exception during testing: $($_.Exception.Message)" "Red"
        return @{ success = $false; error = $_.Exception.Message }
    }
    finally {
        # Return to original directory
        Set-Location $PROJECT_ROOT
    }
}

function Parse-SIMDTestResults {
    param([string[]]$Output, [string]$ModuleName)
    
    $total_tests = 0
    $passed_tests = 0
    $failed_tests = 0
    
    foreach ($line in $Output) {
        if ($line -match "Total Tests:\s+(\d+)") {
            $total_tests = [int]$matches[1]
        }
        elseif ($line -match "Passed:\s+(\d+)") {
            $passed_tests = [int]$matches[1]
        }
        elseif ($line -match "Failed:\s+(\d+)") {
            $failed_tests = [int]$matches[1]
        }
    }
    
    $pass_rate = if ($total_tests -gt 0) { [math]::Round(($passed_tests / $total_tests) * 100, 1) } else { 0 }
    $fail_rate = if ($total_tests -gt 0) { [math]::Round(($failed_tests / $total_tests) * 100, 1) } else { 0 }
    
    return @{
        total = $total_tests
        passed = $passed_tests
        failed = $failed_tests
        pass_rate = $pass_rate
        fail_rate = $fail_rate
    }
}

# =============================================================================
# Main Test Runner
# =============================================================================

function Start-SIMDModuleTests {
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "                    LSE-PE SIMD Modules Test Suite" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    
    Write-Host "`n🚀 Starting SIMD module tests..." -ForegroundColor White
    Write-Host "   Test Mode: $ModuleName" -ForegroundColor Gray
    Write-Host "   Verbose: $Verbose" -ForegroundColor Gray
    
    # Verify tools
    if (!(Test-Path $IVERILOG)) {
        Write-Host "❌ ERROR: Icarus Verilog not found at $IVERILOG" -ForegroundColor Red
        return 1
    }
    Write-Host "✅ Icarus Verilog installation verified" -ForegroundColor Green
    
    # Initialize work directory
    if (!(Test-Path $WORK_DIR)) {
        New-Item -ItemType Directory -Path $WORK_DIR | Out-Null
    }
    Write-Host "✅ Work directory initialized: $WORK_DIR" -ForegroundColor Green
    
    # Determine modules to test
    $modules_to_test = if ($ModuleName -eq "all") {
        $SIMD_MODULES.Keys
    } else {
        @($ModuleName)
    }
    
    Write-Host "`n📋 Testing $($modules_to_test.Count) SIMD module(s): $($modules_to_test -join ', ')" -ForegroundColor White
    
    # Run tests
    $total_modules = $modules_to_test.Count
    $passed_modules = 0
    $failed_modules = 0
    $test_results = @()
    
    foreach ($module in $modules_to_test) {
        if ($SIMD_MODULES.ContainsKey($module)) {
            $result = Test-SIMDModule -ModuleName $module -ModuleConfig $SIMD_MODULES[$module]
            
            $test_entry = [PSCustomObject]@{
                module = $module
                result = $result
                timestamp = Get-Date
            }
            $test_results += $test_entry
            
            if ($result.success) {
                if ($result.status -eq "all_passed") {
                    $passed_modules++
                } else {
                    $failed_modules++
                }
            } else {
                $failed_modules++
            }
        } else {
            Write-Host "❌ ERROR: Unknown SIMD module: $module" -ForegroundColor Red
            $failed_modules++
        }
    }
    
    # Final summary
    Write-Host "`n==============================================================================" -ForegroundColor Cyan
    Write-Host "                         SIMD Test Suite Summary" -ForegroundColor Cyan
    Write-Host "==============================================================================" -ForegroundColor Cyan
    Write-Host "Total SIMD Modules Tested: $total_modules" -ForegroundColor White
    Write-Host "Passed Modules:            $passed_modules" -ForegroundColor Green
    Write-Host "Failed Modules:            $failed_modules" -ForegroundColor $(if ($failed_modules -eq 0) { "Green" } else { "Red" })
    
    if ($total_modules -gt 0) {
        $success_rate = ($passed_modules * 100) / $total_modules
        Write-Host "Success Rate:              $success_rate%" -ForegroundColor $(if ($failed_modules -eq 0) { "Green" } else { "Yellow" })
    }
    
    if ($failed_modules -eq 0) {
        Write-Host "`n🎉 ALL SIMD MODULES PASSED! Multi-precision LSE-PE is ready! 🎉" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  Some SIMD modules need attention. Check the test results above." -ForegroundColor Yellow
    }
    
    Write-Host "==============================================================================" -ForegroundColor Cyan
    
    if ($failed_modules -eq 0) {
        return 0
    } else {
        return 1
    }
}

# =============================================================================
# Script Entry Point
# =============================================================================
try {
    $exit_code = Start-SIMDModuleTests
    exit $exit_code
}
catch {
    Write-Host "`n💥 Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}