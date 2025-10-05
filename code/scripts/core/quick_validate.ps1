# =============================================================================
# Quick Core Validation Script
# Description: Fast validation of core modules with minimal output
# Version: Unified quick test for LSE-PE project
# Compatible: Icarus Verilog / Standard Verilog
# =============================================================================

param(
    [switch]$Summary = $false,    # Show only summary
    [switch]$Quiet = $false       # Minimal output
)

if (!$Quiet) {
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "           LSE-PE Core Modules Quick Validation" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
}

# =============================================================================
# Configuration
# =============================================================================
$PROJECT_ROOT = "C:\Users\waric\Documents\mémoire\code"
$WORK_DIR = "$PROJECT_ROOT\work"
$MODULES_DIR = "$PROJECT_ROOT\modules\core"
$TESTBENCHES_DIR = "$PROJECT_ROOT\testbenches\core"

$IVERILOG = "C:\iverilog\bin\iverilog.exe"
$VVP = "C:\iverilog\bin\vvp.exe"

# Quick test modules (most critical ones)
$QUICK_TESTS = @{
    "lse_add" = "tb_lse_add_unified.sv"
    "lse_mult" = "tb_lse_mult_unified.sv"
    "register" = "tb_register_unified.sv"
}

# =============================================================================
# Quick Test Function
# =============================================================================
function Test-ModuleQuick {
    param([string]$ModuleName, [string]$TestbenchFile)
    
    $module_file = "$ModuleName.sv"
    $module_path = Join-Path $MODULES_DIR $module_file
    $testbench_path = Join-Path $TESTBENCHES_DIR $TestbenchFile
    $output_file = "quick_$ModuleName.out"
    
    # Quick file checks
    if (!(Test-Path $module_path) -or !(Test-Path $testbench_path)) {
        return @{ success = $false; error = "Files missing" }
    }
    
    # Silent compilation
    $null = Start-Process -FilePath $IVERILOG -ArgumentList @("-g2012", "-o", $output_file, $testbench_path, $module_path) -Wait -NoNewWindow -PassThru -RedirectStandardError "compile_error.tmp" -RedirectStandardOutput "compile_output.tmp"
    
    if (!(Test-Path $output_file)) {
        return @{ success = $false; error = "Compilation failed" }
    }
    
    # Silent simulation
    $sim_process = Start-Process -FilePath $VVP -ArgumentList $output_file -Wait -NoNewWindow -PassThru -RedirectStandardError "sim_error.tmp" -RedirectStandardOutput "quick_output.log"
    
    if ($sim_process.ExitCode -ne 0) {
        return @{ success = $false; error = "Simulation failed" }
    }
    
    # Quick result check
    $output = Get-Content "quick_output.log" -ErrorAction SilentlyContinue
    $all_passed = $output | Where-Object { $_ -match "ALL TESTS PASSED" }
    
    Remove-Item $output_file -ErrorAction SilentlyContinue
    Remove-Item "quick_output.log" -ErrorAction SilentlyContinue
    Remove-Item "compile_error.tmp" -ErrorAction SilentlyContinue
    Remove-Item "compile_output.tmp" -ErrorAction SilentlyContinue
    Remove-Item "sim_error.tmp" -ErrorAction SilentlyContinue
    
    return @{ success = $true; all_passed = ($all_passed -ne $null) }
}

# =============================================================================
# Main Execution
# =============================================================================
# Setup
if (!(Test-Path $WORK_DIR)) { New-Item -ItemType Directory -Path $WORK_DIR -Force | Out-Null }
Set-Location $WORK_DIR

# Quick checks
if (!(Test-Path $IVERILOG)) {
    Write-Host "❌ Icarus Verilog not found" -ForegroundColor Red
    exit 1
}

if (!$Quiet) {
    Write-Host "`n⚡ Running quick validation tests..." -ForegroundColor Yellow
}

# Execute quick tests
$results = @{}
$total = $QUICK_TESTS.Count
$passed = 0

foreach ($module in $QUICK_TESTS.Keys) {
    if (!$Quiet -and !$Summary) {
        Write-Host "Testing $module..." -NoNewline -ForegroundColor Gray
    }
    
    $result = Test-ModuleQuick -ModuleName $module -TestbenchFile $QUICK_TESTS[$module]
    $results[$module] = $result
    
    if ($result.success) {
        if ($result.all_passed) {
            $passed++
            if (!$Quiet -and !$Summary) { Write-Host " ✅" -ForegroundColor Green }
        } else {
            if (!$Quiet -and !$Summary) { Write-Host " ⚠️" -ForegroundColor Yellow }
        }
    } else {
        if (!$Quiet -and !$Summary) { Write-Host " ❌" -ForegroundColor Red }
    }
}

# Results
if (!$Quiet) {
    Write-Host "`n================================================================" -ForegroundColor Cyan
    Write-Host "                     Quick Validation Results" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
}

Write-Host "Core Modules Status: $passed/$total passed" -ForegroundColor $(if ($passed -eq $total) { "Green" } else { "Yellow" })

if (!$Summary) {
    foreach ($module in $QUICK_TESTS.Keys) {
        $result = $results[$module]
        $status = if (!$result.success) { "❌ ERROR" } elseif ($result.all_passed) { "✅ PASS" } else { "⚠️  PARTIAL" }
        $color = if (!$result.success) { "Red" } elseif ($result.all_passed) { "Green" } else { "Yellow" }
        Write-Host "  $module : $status" -ForegroundColor $color
    }
}

if ($passed -eq $total) {
    if (!$Quiet) { Write-Host "`n🎉 Core modules are healthy! 🎉" -ForegroundColor Green }
    exit 0
} else {
    if (!$Quiet) { Write-Host "`n⚠️  Some issues detected. Run full tests for details." -ForegroundColor Yellow }
    exit 1
}