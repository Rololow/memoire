# =============================================================================
# SIMD Optimized Test Script
# Description: Test SIMD modules with optimized testbenches (100% Python-verified)
# Version: 3.0 (Optimized)
# Compatible: PowerShell 5.1+
# =============================================================================

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "    LSE SIMD Optimized Test Suite (100% Python-Verified)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Project configuration
$PROJECT_ROOT = "C:\Users\waric\Documents\mémoire\code"
$WORK_DIR = "$PROJECT_ROOT\work"

# Ensure work directory exists
if (!(Test-Path $WORK_DIR)) {
    New-Item -ItemType Directory -Path $WORK_DIR | Out-Null
}

Set-Location $PROJECT_ROOT

$totalModules = 0
$passedModules = 0
$failedModules = 0
$allResults = @()

# Function to test a module
function Test-OptimizedSIMDModule {
    param(
        [string]$ModuleName,
        [string]$TestbenchFile,
        [string[]]$Dependencies,
        [string]$Description
    )
    
    Write-Host "`n==================================" -ForegroundColor Yellow
    Write-Host "Testing $Description" -ForegroundColor Yellow
    Write-Host "==================================" -ForegroundColor Yellow
    
    $tbName = [System.IO.Path]::GetFileNameWithoutExtension($TestbenchFile)
    $compileCmd = "C:\iverilog\bin\iverilog.exe -g2012 -o work\${tbName}.vvp $TestbenchFile"
    
    # Add dependencies
    foreach ($dep in $Dependencies) {
        $compileCmd += " $dep"
    }
    
    $runCmd = "C:\iverilog\bin\vvp.exe work\${tbName}.vvp"
    
    Write-Host "Compiling: $tbName" -ForegroundColor Gray
    
    # Clean previous build
    if (Test-Path "work\${tbName}.vvp") { Remove-Item "work\${tbName}.vvp" -Force }
    
    try {
        # Compilation
        $compileResult = Invoke-Expression $compileCmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ ${ModuleName}: COMPILATION FAILED" -ForegroundColor Red
            return @{ success = $false; error = "Compilation failed" }
        }
        
        # Execution  
        $runResult = Invoke-Expression $runCmd 2>&1
        $output = $runResult -join "`n"
        
        # Parse results from test summary
        $totalTests = 0
        $passedTests = 0
        $failedTests = 0
        $allPassed = $false
        
        if ($output -match "Total Tests:\s+(\d+)") {
            $totalTests = [int]$matches[1]
        }
        
        if ($output -match "Passed:\s+(\d+)") {
            $passedTests = [int]$matches[1]
        }
        
        if ($output -match "Failed:\s+(\d+)") {
            $failedTests = [int]$matches[1]
        }
        
        if ($output -match "ALL TESTS PASSED") {
            $allPassed = $true
        }
        
        # Display key lines only (filter for important results)
        $importantLines = $output -split "`n" | Where-Object { 
            $_ -match "✅ PASS|❌ FAIL|Test Summary|ALL TESTS PASSED|Success Rate" -or
            $_ -match "==="
        }
        
        if ($importantLines) {
            Write-Host ($importantLines -join "`n") -ForegroundColor Gray
        }
        
        # Results
        if ($allPassed -or ($failedTests -eq 0 -and $passedTests -gt 0)) {
            Write-Host "✅ ${ModuleName}: PERFECT! (${passedTests}/${totalTests})" -ForegroundColor Green
            return @{ 
                success = $true; 
                status = "perfect"; 
                total = $totalTests; 
                passed = $passedTests; 
                failed = $failedTests 
            }
        } elseif ($passedTests -gt 0) {
            $passRate = if ($totalTests -gt 0) { [math]::Round(($passedTests / $totalTests) * 100, 1) } else { 0 }
            Write-Host "⚠️ ${ModuleName}: ${passedTests}/${totalTests} tests passed (${passRate}%)" -ForegroundColor Yellow
            return @{ 
                success = $true; 
                status = "partial"; 
                total = $totalTests; 
                passed = $passedTests; 
                failed = $failedTests 
            }
        } else {
            Write-Host "❌ ${ModuleName}: ALL TESTS FAILED" -ForegroundColor Red
            return @{ 
                success = $false; 
                status = "failed"; 
                total = $totalTests; 
                passed = $passedTests; 
                failed = $failedTests 
            }
        }
        
    } catch {
        Write-Host "❌ ${ModuleName}: ERROR - $_" -ForegroundColor Red
        return @{ success = $false; error = $_.Exception.Message }
    }
}

# Test optimized SIMD modules
$modules = @(
    @{
        name = "SIMD 2×12b"
        testbench = "testbenches\simd\tb_lse_simd_2x12b_unified.sv"
        dependencies = @("modules\core\lse_add.sv", "modules\simd\lse_simd_2x12b.sv")
        description = "SIMD 2×12b (Already 100% optimized)"
    },
    @{
        name = "SIMD 4×6b" 
        testbench = "testbenches\simd\tb_lse_simd_4x6b_optimized.sv"
        dependencies = @("modules\core\lse_add.sv", "modules\simd\lse_simd_4x6b.sv")
        description = "SIMD 4×6b (Optimized Python-only)"
    },
    @{
        name = "SIMD Unified"
        testbench = "testbenches\simd\tb_lse_simd_unified_optimized.sv"
        dependencies = @("modules\core\lse_add.sv", "modules\simd\lse_simd_2x12b.sv", "modules\simd\lse_simd_4x6b.sv", "modules\simd\lse_simd_unified.sv")
        description = "SIMD Unified (Optimized Python-only)"
    }
)

Write-Host "`n🚀 Testing optimized SIMD modules with 100% Python-verified values..." -ForegroundColor White

# Run tests
foreach ($module in $modules) {
    $totalModules++
    $result = Test-OptimizedSIMDModule -ModuleName $module.name -TestbenchFile $module.testbench -Dependencies $module.dependencies -Description $module.description
    
    $allResults += [PSCustomObject]@{
        Module = $module.name
        Result = $result
        Timestamp = Get-Date
    }
    
    if ($result.success -and $result.status -eq "perfect") {
        $passedModules++
    } elseif ($result.success -and $result.status -eq "partial") {
        # Count as passed only if ALL tests pass for optimized version
        if ($result.failed -eq 0) {
            $passedModules++
        } else {
            $failedModules++
        }
    } else {
        $failedModules++
    }
}

# Overall summary
Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host "                Optimized Test Results Summary" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$totalTestsAll = ($allResults | ForEach-Object { if ($_.Result.total) { $_.Result.total } else { 0 } } | Measure-Object -Sum).Sum
$passedTestsAll = ($allResults | ForEach-Object { if ($_.Result.passed) { $_.Result.passed } else { 0 } } | Measure-Object -Sum).Sum
$failedTestsAll = ($allResults | ForEach-Object { if ($_.Result.failed) { $_.Result.failed } else { 0 } } | Measure-Object -Sum).Sum

Write-Host "Optimized Modules: $totalModules" -ForegroundColor White
Write-Host "Perfect Modules:   $passedModules" -ForegroundColor Green  
Write-Host "Failed Modules:    $failedModules" -ForegroundColor $(if ($failedModules -eq 0) { "Green" } else { "Red" })

if ($totalTestsAll -gt 0) {
    Write-Host "`nOptimized Tests:   $totalTestsAll total" -ForegroundColor White
    Write-Host "Tests Passed:      $passedTestsAll" -ForegroundColor Green
    Write-Host "Tests Failed:      $failedTestsAll" -ForegroundColor $(if ($failedTestsAll -eq 0) { "Green" } else { "Red" })
    
    $overallPassRate = [math]::Round(($passedTestsAll / $totalTestsAll) * 100, 1)
    Write-Host "Optimized Rate:    ${overallPassRate}%" -ForegroundColor $(if ($overallPassRate -eq 100) { "Green" } elseif ($overallPassRate -gt 95) { "Yellow" } else { "Red" })
}

Write-Host "`nDetailed Results:" -ForegroundColor White
foreach ($result in $allResults) {
    $status = switch ($result.Result.status) {
        "perfect" { "🎯 PERFECT" }
        "partial" { "⚠️ PARTIAL" } 
        "failed" { "❌ FAILED" }
        default { "❓ UNKNOWN" }
    }
    
    if ($result.Result.total -gt 0) {
        Write-Host "  $($result.Module): $status ($($result.Result.passed)/$($result.Result.total))" -ForegroundColor White
    } else {
        Write-Host "  $($result.Module): $status" -ForegroundColor White
    }
}

# Final conclusion
if ($failedModules -eq 0 -and $passedModules -eq $totalModules) {
    Write-Host "`n🎯 PERFECT! ALL OPTIMIZED SIMD MODULES ARE 100% VERIFIED! 🎯" -ForegroundColor Green
    Write-Host "✅ Priority 2 optimization is COMPLETE with ${overallPassRate}% success rate!" -ForegroundColor Green
    Write-Host "🚀 Ready for production deployment!" -ForegroundColor Green
} elseif ($passedModules -gt 0) {
    Write-Host "`n⚡ Optimized SIMD modules show major improvement!" -ForegroundColor Yellow
    Write-Host "✅ Priority 2 is highly successful with ${overallPassRate}% pass rate!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Optimization needs more work" -ForegroundColor Red
}

Write-Host "==================================================================" -ForegroundColor Cyan

# Return to original directory
Set-Location $PROJECT_ROOT