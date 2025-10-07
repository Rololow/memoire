# =============================================================================
# Unified Core Module Test Suite
# Description: Comprehensive test suite for all unified core modules
# Version: Unified test automation for LSE-PE project
# Compatible: Icarus Verilog / Standard Verilog
# =============================================================================

param(
    [string]$ModuleName = "all",           # Specific module to test or "all"
    [switch]$Verbose = $false,             # Enable verbose output
    [switch]$StopOnError = $false,         # Stop testing on first error
    [string]$OutputFormat = "console"     # Output format: console, file, both
)

Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host "              LSE-PE Unified Core Module Test Suite" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan

# =============================================================================
# Configuration
# =============================================================================
$PROJECT_ROOT = "C:\Users\waric\Documents\memoire\code"
$WORK_DIR = "$PROJECT_ROOT\work"
$OUTPUT_DIR = "$PROJECT_ROOT\simulation_output"
$MODULES_DIR = "$PROJECT_ROOT\modules\core"
$TESTBENCHES_DIR = "$PROJECT_ROOT\testbenches\core"

# ModelSim tools
$VLOG = "vlog"
$VSIM = "vsim"

# Test configuration
$TIMEOUT_SECONDS = 30
$script:TEST_RESULTS = @()

# =============================================================================
# Core Module Test Definitions
# =============================================================================
$CORE_MODULES = @{
    "lse_add" = @{
        "module_file" = "lse_add.sv"
        "testbench_file" = "tb_lse_add_unified.sv"
        "description" = "LSE Addition with LUT correction"
        "expected_tests" = 15
    }
    "lse_mult" = @{
        "module_file" = "lse_mult.sv"
        "testbench_file" = "tb_lse_mult_unified.sv"
        "description" = "LSE Multiplication (log-space addition)"
        "expected_tests" = 15
    }
    "lse_acc" = @{
        "module_file" = "lse_acc.sv"
        "testbench_file" = "tb_lse_acc_unified.sv"
        "description" = "LSE Accumulator (16-bit fixed-point)"
        "expected_tests" = 20
    }
    "register" = @{
        "module_file" = "register.sv"
        "testbench_file" = "tb_register_unified.sv"
        "description" = "Generic Register with sync reset"
        "expected_tests" = 15
    }
    "einsum_add" = @{
        "module_file" = "einsum_add.sv"
        "testbench_file" = "tb_einsum_add_unified.sv"
        "description" = "Einsum Add Wrapper with enable/bypass"
        "expected_tests" = 20
        "dependencies" = @("lse_add.sv")
    }
    "einsum_mult" = @{
        "module_file" = "einsum_mult.sv"
        "testbench_file" = "tb_einsum_mult_unified.sv"
        "description" = "Einsum Mult Wrapper with enable/bypass"
        "expected_tests" = 20
        "dependencies" = @("lse_mult.sv")
    }
}

# =============================================================================
# Utility Functions
# =============================================================================
function Write-TestHeader {
    param([string]$ModuleName, [string]$Description)
    Write-Host "`n📋 Testing Module: $ModuleName" -ForegroundColor Yellow
    Write-Host "   Description: $Description" -ForegroundColor Gray
    Write-Host "   " + ("-" * 60) -ForegroundColor Gray
}

function Write-TestResult {
    param([string]$Status, [string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Status - $Message" -ForegroundColor $Color
}

function Test-ModelSimInstallation {
    Write-Host "`n🔍 Checking ModelSim installation..." -ForegroundColor Green
    
    try {
        $null = Get-Command $VLOG -ErrorAction Stop
        $null = Get-Command $VSIM -ErrorAction Stop
        Write-Host "✅ ModelSim found and accessible" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "❌ ERROR: ModelSim not found or not in PATH" -ForegroundColor Red
        return $false
    }
}

function Initialize-TestEnvironment {
    Write-Host "`n🔧 Initializing test environment..." -ForegroundColor Green
    
    # Ensure directories exist
    @($WORK_DIR, $OUTPUT_DIR) | ForEach-Object {
        if (!(Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Host "   Created directory: $_" -ForegroundColor Gray
        }
    }
    
    # Change to work directory
    Set-Location $WORK_DIR
    Write-Host "   Working directory: $WORK_DIR" -ForegroundColor Gray
    
    # Clean previous simulation files
    Get-ChildItem -Path $WORK_DIR -Filter "*.vcd" -ErrorAction SilentlyContinue | Remove-Item -Force
    Get-ChildItem -Path $WORK_DIR -Filter "*.out" -ErrorAction SilentlyContinue | Remove-Item -Force
    
    Write-Host "✅ Test environment initialized" -ForegroundColor Green
}

function Test-CoreModule {
    param(
        [string]$ModuleName,
        [hashtable]$ModuleConfig
    )
    
    Write-TestHeader -ModuleName $ModuleName -Description $ModuleConfig.description
    
    $module_path = Join-Path $MODULES_DIR $ModuleConfig.module_file
    $testbench_path = Join-Path $TESTBENCHES_DIR $ModuleConfig.testbench_file
    $vcd_file = "$ModuleName.vcd"
    
    # Verify files exist
    if (!(Test-Path $module_path)) {
        Write-TestResult "ERROR" "Module file not found: $module_path" "Red"
        return @{ success = $false; error = "Module file missing" }
    }
    
    if (!(Test-Path $testbench_path)) {
        Write-TestResult "ERROR" "Testbench file not found: $testbench_path" "Red"
        return @{ success = $false; error = "Testbench file missing" }
    }
    
    Write-TestResult "INFO" "Compiling module and testbench..." "Cyan"
    
    # Create work library if it doesn't exist
    if (!(Test-Path "work")) {
        $null = & vlib work 2>$null
    }
    
    # Prepare compilation files list
    $compile_files = @($module_path, $testbench_path)
    
    # Add dependencies if specified
    if ($ModuleConfig.ContainsKey("dependencies")) {
        foreach ($dep in $ModuleConfig.dependencies) {
            $dep_path = Join-Path $MODULES_DIR $dep
            if (Test-Path $dep_path) {
                $compile_files += $dep_path
                Write-TestResult "INFO" "Including dependency: $dep" "Yellow"
            } else {
                Write-TestResult "WARNING" "Dependency not found: $dep_path" "Yellow"
            }
        }
    }
    
    try {
        $compile_process = Start-Process -FilePath $VLOG -ArgumentList @("-sv", "-work", "work") + $compile_files -Wait -NoNewWindow -PassThru -RedirectStandardError "compile_error.log" -RedirectStandardOutput "compile_output.log"
        
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
    }
    catch {
        Write-TestResult "ERROR" "Compilation exception: $($_.Exception.Message)" "Red"
        return @{ success = $false; error = "Compilation exception" }
    }
    
    # Simulation
    Write-TestResult "INFO" "Running simulation..." "Cyan"
    
    try {
        $testbench_name = [System.IO.Path]::GetFileNameWithoutExtension($ModuleConfig.testbench_file)
        
        # Create temporary do file
        $do_content = @"
run -all
quit
"@
        $do_content | Out-File -FilePath "run_sim.do" -Encoding ASCII
        
        $sim_process = Start-Process -FilePath $VSIM -ArgumentList @("-c", "work.$testbench_name", "-do", "run_sim.do") -Wait -NoNewWindow -PassThru -RedirectStandardError "sim_error.log" -RedirectStandardOutput "sim_output.log"
        
        if ($sim_process.ExitCode -ne 0) {
            $error_content = Get-Content "sim_error.log" -ErrorAction SilentlyContinue
            Write-TestResult "ERROR" "Simulation failed (Exit Code: $($sim_process.ExitCode))" "Red"
            if ($Verbose -and $error_content) {
                Write-Host "   Simulation errors:" -ForegroundColor Red
                $error_content | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
            }
            return @{ success = $false; error = "Simulation failed"; exit_code = $sim_process.ExitCode }
        }
        
        Write-TestResult "SUCCESS" "Simulation completed" "Green"
    }
    catch {
        Write-TestResult "ERROR" "Simulation exception: $($_.Exception.Message)" "Red"
        return @{ success = $false; error = "Simulation exception" }
    }
    
    # Parse results
    $sim_output = Get-Content "sim_output.log" -ErrorAction SilentlyContinue
    
    if ($sim_output) {
        $test_summary = $sim_output | Where-Object { $_ -match "(Total Tests:|Passed:|Failed:)" }
        
        if ($test_summary) {
            Write-Host "   📊 Test Results:" -ForegroundColor Cyan
            $test_summary | ForEach-Object { 
                $color = if ($_ -match "Failed:\s*0") { "Green" } elseif ($_ -match "Failed:") { "Red" } else { "White" }
                Write-Host "     $_" -ForegroundColor $color
            }
            
            # Check for all tests passed
            $all_passed = $sim_output | Where-Object { $_ -match "ALL TESTS PASSED" }
            if ($all_passed) {
                Write-TestResult "SUCCESS" "All tests passed! ✅" "Green"
                return @{ success = $true; status = "all_passed"; output = $sim_output }
            } else {
                $failed_line = $sim_output | Where-Object { $_ -match "Failed:\s*(\d+)" }
                if ($failed_line -and $failed_line -match "Failed:\s*0") {
                    Write-TestResult "SUCCESS" "All tests passed! ✅" "Green"
                    return @{ success = $true; status = "all_passed"; output = $sim_output }
                } else {
                    Write-TestResult "WARNING" "Some tests failed ⚠️" "Yellow"
                    return @{ success = $true; status = "some_failed"; output = $sim_output }
                }
            }
        } else {
            Write-TestResult "WARNING" "Could not parse test results" "Yellow"
            return @{ success = $true; status = "unknown"; output = $sim_output }
        }
    } else {
        Write-TestResult "ERROR" "No simulation output generated" "Red"
        return @{ success = $false; error = "No output" }
    }
}

# =============================================================================
# Main Test Execution
# =============================================================================
function Start-CoreModuleTests {
    Write-Host "`n🚀 Starting unified core module tests..." -ForegroundColor Green
    Write-Host "   Test Mode: $ModuleName" -ForegroundColor Gray
    Write-Host "   Verbose: $Verbose" -ForegroundColor Gray
    Write-Host "   Stop on Error: $StopOnError" -ForegroundColor Gray
    
    # Check prerequisites
    if (!(Test-ModelSimInstallation)) {
        Write-Host "`n❌ Prerequisites not met. Exiting." -ForegroundColor Red
        exit 1
    }
    
    Initialize-TestEnvironment
    
    # Determine modules to test
    $modules_to_test = if ($ModuleName -eq "all") {
        $CORE_MODULES.Keys | Sort-Object
    } else {
        if ($CORE_MODULES.ContainsKey($ModuleName)) {
            @($ModuleName)
        } else {
            Write-Host "`n❌ ERROR: Unknown module '$ModuleName'" -ForegroundColor Red
            Write-Host "   Available modules: $($CORE_MODULES.Keys -join ', ')" -ForegroundColor Gray
            exit 1
        }
    }
    
    Write-Host "`n📋 Testing $($modules_to_test.Count) module(s): $($modules_to_test -join ', ')" -ForegroundColor Cyan
    
    # Execute tests
    $total_modules = $modules_to_test.Count
    $passed_modules = 0
    $failed_modules = 0
    
    foreach ($module in $modules_to_test) {
        $result = Test-CoreModule -ModuleName $module -ModuleConfig $CORE_MODULES[$module]
        
        # Create a new test result entry
        $test_entry = [PSCustomObject]@{
            module = $module
            result = $result
            timestamp = Get-Date
        }
        $script:TEST_RESULTS += $test_entry
        
        if ($result.success) {
            if ($result.status -eq "all_passed") {
                $passed_modules++
            } else {
                $failed_modules++
            }
        } else {
            $failed_modules++
            if ($StopOnError) {
                Write-Host "`n🛑 Stopping tests due to error in module: $module" -ForegroundColor Red
                break
            }
        }
    }
    
    # Final summary
    Write-Host "`n=============================================================================" -ForegroundColor Cyan
    Write-Host "                           Test Suite Summary" -ForegroundColor Cyan
    Write-Host "=============================================================================" -ForegroundColor Cyan
    Write-Host "Total Modules Tested: $total_modules" -ForegroundColor White
    Write-Host "Passed Modules:       $passed_modules" -ForegroundColor Green
    Write-Host "Failed Modules:       $failed_modules" -ForegroundColor $(if ($failed_modules -eq 0) { "Green" } else { "Red" })
    Write-Host "Success Rate:         $(if ($total_modules -gt 0) { [math]::Round(($passed_modules / $total_modules) * 100, 1) } else { 0 })%" -ForegroundColor $(if ($failed_modules -eq 0) { "Green" } else { "Yellow" })
    
    if ($failed_modules -eq 0) {
        Write-Host "`n🎉 ALL CORE MODULES PASSED! The LSE-PE core is ready! 🎉" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️  Some modules need attention. Check the test results above." -ForegroundColor Yellow
    }
    
    Write-Host "=============================================================================" -ForegroundColor Cyan
    
    return $failed_modules
}

# =============================================================================
# Script Entry Point
# =============================================================================
try {
    $exit_code = Start-CoreModuleTests
    exit $exit_code
}
catch {
    Write-Host "`n💥 Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}