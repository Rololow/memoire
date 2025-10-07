# =============================================================================
# PowerShell Script: Test LSE Shared System Architecture
# Description: Compiles and simulates the complete shared CLUT architecture
# Author: LSE-PE Project
# Date: October 2025
# =============================================================================

param(
    [switch]$Clean = $false,
    [switch]$Verbose = $false,
    [switch]$WaveView = $false,
    [string]$TestName = "tb_lse_shared_system"
)

# Script configuration
$WorkDir = "C:\Users\waric\Documents\memoire\code"
$ModulesDir = "$WorkDir\modules"
$TestbenchDir = "$WorkDir\testbenches"
$OutputDir = "$WorkDir\simulation_output"
$WaveDir = "$WorkDir\gtkwave_configs"

# Set paths
Set-Location $WorkDir

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "LSE Shared System Architecture Test Suite" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

# Clean previous simulation if requested
if ($Clean) {
    Write-Host "🧹 Cleaning previous simulation..." -ForegroundColor Yellow
    if (Test-Path "work") {
        Remove-Item -Path "work" -Recurse -Force
    }
    if (Test-Path "$OutputDir\*.wlf") {
        Remove-Item -Path "$OutputDir\*.wlf" -Force
    }
}

# Create work library
Write-Host "📚 Creating work library..." -ForegroundColor Green
if (!(Test-Path "work")) {
    & vlib work
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to create work library" -ForegroundColor Red
        exit 1
    }
}

# Update CLUT values before compilation
Write-Host "🔄 Updating CLUT values..." -ForegroundColor Green
try {
    $PythonScript = "$WorkDir\scripts\generate_clut_values.py"
    if (Test-Path $PythonScript) {
        & python $PythonScript
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ CLUT values updated successfully" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Warning: CLUT update failed, continuing with existing values" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "⚠️  Warning: Could not update CLUT values, continuing..." -ForegroundColor Yellow
}

# Compile design files
Write-Host "🔨 Compiling design files..." -ForegroundColor Green

# Define compilation order for shared architecture
$DesignFiles = @(
    # Core modules first
    "$ModulesDir\core\register.sv",
    "$ModulesDir\core\lse_add.sv",
    
    # LUT directory modules
    "$ModulesDir\lut\lse_clut_shared.sv",
    
    # Core processing elements
    "$ModulesDir\core\lse_pe_with_mux.sv",
    "$ModulesDir\core\lse_log_mac.sv",
    
    # Top-level system
    "$ModulesDir\lse_shared_system.sv",
    
    # Testbench
    "$TestbenchDir\$TestName.sv"
)

$CompileSuccess = $true

foreach ($File in $DesignFiles) {
    if (Test-Path $File) {
        Write-Host "  Compiling: $File" -ForegroundColor White
        
        if ($Verbose) {
            & vlog -sv +define+DEBUG_SYSTEM +define+ASSERTIONS_ON $File
        } else {
            & vlog -sv +define+DEBUG_SYSTEM +define+ASSERTIONS_ON $File 2>$null
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ❌ Compilation failed for: $File" -ForegroundColor Red
            $CompileSuccess = $false
        } else {
            Write-Host "  ✅ Compiled successfully: $File" -ForegroundColor Green
        }
    } else {
        Write-Host "  ⚠️  File not found: $File" -ForegroundColor Yellow
        $CompileSuccess = $false
    }
}

if (!$CompileSuccess) {
    Write-Host "❌ Compilation failed. Please fix errors and try again." -ForegroundColor Red
    exit 1
}

Write-Host "✅ All design files compiled successfully!" -ForegroundColor Green

# Run simulation
Write-Host "🚀 Starting simulation..." -ForegroundColor Green

$SimArgs = @(
    "-t", "1ps",
    "-voptargs=+acc",
    "+notimingchecks"
)

if ($WaveView) {
    $SimArgs += @("-do", "add wave -r /*; run -all; quit")
    $WaveFile = "$OutputDir\lse_shared_system.wlf"
    $SimArgs += @("-wlf", $WaveFile)
}

# Start simulation
$SimProcess = Start-Process -FilePath "vsim" -ArgumentList ($SimArgs + @($TestName)) -Wait -PassThru -NoNewWindow

if ($SimProcess.ExitCode -eq 0) {
    Write-Host "✅ Simulation completed successfully!" -ForegroundColor Green
    
    # Check simulation output for test results
    $LogFile = "transcript"
    if (Test-Path $LogFile) {
        $LogContent = Get-Content $LogFile
        
        # Extract test results
        $PassedTests = $LogContent | Select-String "PASSED" | Measure-Object | Select-Object -ExpandProperty Count
        $FailedTests = $LogContent | Select-String "FAILED" | Measure-Object | Select-Object -ExpandProperty Count
        $TotalTests = $LogContent | Select-String "Total Tests:" | ForEach-Object { 
            if ($_ -match "Total Tests:\s*(\d+)") { $Matches[1] } 
        }
        
        Write-Host ""
        Write-Host "📊 Test Results Summary:" -ForegroundColor Cyan
        Write-Host "  Total Tests: $TotalTests" -ForegroundColor White
        Write-Host "  Passed:      $PassedTests" -ForegroundColor Green  
        Write-Host "  Failed:      $FailedTests" -ForegroundColor $(if($FailedTests -eq 0){"Green"}else{"Red"})
        
        # Check for specific success indicators
        $AllTestsPassed = $LogContent | Select-String "ALL TESTS PASSED"
        $SomeTestsFailed = $LogContent | Select-String "SOME TESTS FAILED"
        
        if ($AllTestsPassed) {
            Write-Host "🎉 ALL TESTS PASSED! ARCHITECTURE IS WORKING CORRECTLY! 🎉" -ForegroundColor Green
        } elseif ($SomeTestsFailed) {
            Write-Host "⚠️  SOME TESTS FAILED - PLEASE REVIEW RESULTS" -ForegroundColor Yellow
        }
        
        # Show operation count
        $OpCount = $LogContent | Select-String "Final system status: Operations=" | ForEach-Object {
            if ($_ -match "Operations=(\d+)") { $Matches[1] }
        }
        if ($OpCount) {
            Write-Host "  Operations Completed: $OpCount" -ForegroundColor Cyan
        }
    }
    
} else {
    Write-Host "❌ Simulation failed with exit code: $($SimProcess.ExitCode)" -ForegroundColor Red
    exit 1
}

# Launch waveform viewer if requested
if ($WaveView -and (Test-Path $WaveFile)) {
    Write-Host "🌊 Launching waveform viewer..." -ForegroundColor Blue
    
    $GtkWaveConfig = "$WaveDir\lse_shared_system.gtkw"
    
    # Create basic GTKWave config if it doesn't exist
    if (!(Test-Path $GtkWaveConfig)) {
        $GtkWaveContent = @"
[*] GTKWave save file for LSE Shared System
[dumpfile] "$WaveFile"
[timestart] 0
[size] 1200 800
[pos] 100 100
@28
tb_lse_shared_system.clk
tb_lse_shared_system.rst_n
tb_lse_shared_system.global_enable
@22
tb_lse_shared_system.dut.active_units[1:0]
tb_lse_shared_system.dut.operation_count[31:0]
@28
tb_lse_shared_system.dut.system_ready
@24
tb_lse_shared_system.mac_results[3:0][23:0]
@28
tb_lse_shared_system.valid_array[3:0]
@22
tb_lse_shared_system.dut.selected_unit[1:0]
@28
tb_lse_shared_system.dut.arb_valid
@22
tb_lse_shared_system.dut.shared_clut_addr[3:0]
@28
tb_lse_shared_system.dut.shared_clut_valid
@22
tb_lse_shared_system.dut.shared_clut_correction[9:0]
"@
        Set-Content -Path $GtkWaveConfig -Value $GtkWaveContent
    }
    
    try {
        & gtkwave $WaveFile --save $GtkWaveConfig &
        Write-Host "✅ GTKWave launched with waveform data" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Could not launch GTKWave. Waveform saved to: $WaveFile" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "LSE Shared System Test Complete!" -ForegroundColor Cyan
Write-Host "Architecture Status: $(if($AllTestsPassed){"VERIFIED ✅"}else{"NEEDS REVIEW ⚠️"})" -ForegroundColor $(if($AllTestsPassed){"Green"}else{"Yellow"})
Write-Host "==============================================================================" -ForegroundColor Cyan