# =============================================================================
# Project Status Report Script
# Description: Generate comprehensive status report for LSE-PE project
# Version: Unified status reporting for LSE-PE project
# =============================================================================

param(
    [switch]$Detailed = $false,    # Show detailed file information
    [switch]$Export = $false       # Export report to file
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "              LSE-PE Project Status Report" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# =============================================================================
# Configuration
# =============================================================================
$PROJECT_ROOT = "C:\Users\waric\Documents\mémoire\code"
$REPORT_FILE = "$PROJECT_ROOT\PROJECT_STATUS_REPORT.md"

# =============================================================================
# Analysis Functions
# =============================================================================
function Get-DirectoryStats {
    param([string]$Directory, [string]$FilePattern = "*")
    
    if (!(Test-Path $Directory)) {
        return @{ exists = $false; count = 0; size = 0; files = @() }
    }
    
    $files = Get-ChildItem -Path $Directory -Filter $FilePattern -File -ErrorAction SilentlyContinue
    $total_size = ($files | Measure-Object -Property Length -Sum).Sum
    
    return @{
        exists = $true
        count = $files.Count
        size = $total_size
        files = $files.Name
    }
}

function Format-FileSize {
    param([long]$Bytes)
    
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    elseif ($Bytes -lt 1MB) { return "$([math]::Round($Bytes/1KB, 2)) KB" }
    elseif ($Bytes -lt 1GB) { return "$([math]::Round($Bytes/1MB, 2)) MB" }
    else { return "$([math]::Round($Bytes/1GB, 2)) GB" }
}

function Test-ModuleIntegrity {
    param([string]$ModulePath)
    
    if (!(Test-Path $ModulePath)) { return @{ exists = $false } }
    
    $content = Get-Content $ModulePath -ErrorAction SilentlyContinue
    $has_module = $content | Where-Object { $_ -match "^\s*module\s+\w+" }
    $has_endmodule = $content | Where-Object { $_ -match "^\s*endmodule" }
    $line_count = $content.Count
    
    return @{
        exists = $true
        has_module = ($has_module -ne $null)
        has_endmodule = ($has_endmodule -ne $null)
        line_count = $line_count
        is_valid = ($has_module -ne $null) -and ($has_endmodule -ne $null)
    }
}

# =============================================================================
# Report Generation
# =============================================================================
$report = @()
$report += "# LSE-PE Project Status Report"
$report += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += ""

Write-Host "`n📊 Analyzing project structure..." -ForegroundColor Yellow

# Project Overview
$report += "## Project Overview"
$report += "- **Project Root:** ``$PROJECT_ROOT``"
$report += "- **Project Type:** LSE-PE (Log-Sum-Exp Processing Element)"
$report += "- **Target:** Hardware acceleration for probabilistic reasoning"
$report += ""

# Core Modules Analysis
Write-Host "   🔍 Analyzing core modules..." -ForegroundColor Gray
$core_modules_dir = "$PROJECT_ROOT\modules\core"
$core_stats = Get-DirectoryStats -Directory $core_modules_dir -FilePattern "*.sv"

$report += "## Core Modules Status"
$report += "**Location:** ``modules/core/``"
$report += ""

if ($core_stats.exists) {
    $report += "| Module | Status | Lines | Description |"
    $report += "|--------|--------|-------|-------------|"
    
    $core_modules = @{
        "lse_add.sv" = "LSE Addition with LUT correction"
        "lse_mult.sv" = "LSE Multiplication (log-space)"
        "lse_acc.sv" = "LSE Accumulator (16-bit)"
        "register.sv" = "Generic Register"
        "einsum_add.sv" = "Einsum Add Wrapper"
        "einsum_mult.sv" = "Einsum Mult Wrapper"
    }
    
    $valid_modules = 0
    foreach ($module in $core_modules.Keys) {
        $module_path = Join-Path $core_modules_dir $module
        $integrity = Test-ModuleIntegrity -ModulePath $module_path
        
        $status = if ($integrity.exists -and $integrity.is_valid) { "✅ Valid" } elseif ($integrity.exists) { "⚠️ Issues" } else { "❌ Missing" }
        $lines = if ($integrity.exists) { $integrity.line_count } else { "N/A" }
        
        if ($integrity.exists -and $integrity.is_valid) { $valid_modules++ }
        
        $report += "| ``$module`` | $status | $lines | $($core_modules[$module]) |"
    }
    
    $report += ""
    $report += "**Summary:** $valid_modules/$($core_modules.Count) modules are valid"
    $report += "**Total Files:** $($core_stats.count) SystemVerilog files"
    $report += "**Total Size:** $(Format-FileSize $core_stats.size)"
} else {
    $report += "❌ **Core modules directory not found**"
}

$report += ""

# Testbenches Analysis
Write-Host "   🔍 Analyzing testbenches..." -ForegroundColor Gray
$testbench_dirs = @{
    "core" = "$PROJECT_ROOT\testbenches\core"
    "simd" = "$PROJECT_ROOT\testbenches\simd"
    "integration" = "$PROJECT_ROOT\testbenches\integration"
}

$report += "## Testbenches Status"
$report += ""

foreach ($tb_type in $testbench_dirs.Keys) {
    $tb_stats = Get-DirectoryStats -Directory $testbench_dirs[$tb_type] -FilePattern "*.sv"
    
    $report += "### $($tb_type.ToUpper()) Testbenches"
    $report += "**Location:** ``testbenches/$tb_type/``"
    
    if ($tb_stats.exists) {
        $report += "- **Files:** $($tb_stats.count) testbenches"
        $report += "- **Size:** $(Format-FileSize $tb_stats.size)"
        
        if ($Detailed -and $tb_stats.files.Count -gt 0) {
            $report += "- **Files List:**"
            foreach ($file in $tb_stats.files) {
                $report += "  - ``$file``"
            }
        }
    } else {
        $report += "- ❌ **Directory not found**"
    }
    $report += ""
}

# Scripts Analysis
Write-Host "   🔍 Analyzing scripts..." -ForegroundColor Gray
$scripts_stats = Get-DirectoryStats -Directory "$PROJECT_ROOT\scripts" -FilePattern "*.ps1"

$report += "## Scripts Status"
$report += "**Location:** ``scripts/``"
$report += ""

if ($scripts_stats.exists) {
    $report += "- **PowerShell Scripts:** $($scripts_stats.count)"
    $report += "- **Total Size:** $(Format-FileSize $scripts_stats.size)"
    
    # Check for unified scripts
    $unified_scripts = @(
        "scripts\core\test_core_unified.ps1",
        "scripts\core\quick_validate.ps1",
        "scripts\core\cleanup_project.ps1"
    )
    
    $report += "- **Unified Scripts:**"
    foreach ($script_rel_path in $unified_scripts) {
        $script_path = Join-Path $PROJECT_ROOT $script_rel_path
        $status = if (Test-Path $script_path) { "✅" } else { "❌" }
        $script_name = Split-Path $script_rel_path -Leaf
        $report += "  - $status ``$script_name``"
    }
} else {
    $report += "❌ **Scripts directory not found**"
}

$report += ""

# Work Directory Analysis
Write-Host "   🔍 Analyzing work directory..." -ForegroundColor Gray
$work_stats = Get-DirectoryStats -Directory "$PROJECT_ROOT\work"

$report += "## Work Directory Status"
$report += "**Location:** ``work/``"
$report += ""

if ($work_stats.exists) {
    $sim_files = Get-DirectoryStats -Directory "$PROJECT_ROOT\work" -FilePattern "*.vcd"
    $log_files = Get-DirectoryStats -Directory "$PROJECT_ROOT\work" -FilePattern "*.log"
    $out_files = Get-DirectoryStats -Directory "$PROJECT_ROOT\work" -FilePattern "*.out"
    
    $report += "- **Total Files:** $($work_stats.count)"
    $report += "- **VCD Files:** $($sim_files.count) ($(Format-FileSize $sim_files.size))"
    $report += "- **Log Files:** $($log_files.count) ($(Format-FileSize $log_files.size))"
    $report += "- **Output Files:** $($out_files.count) ($(Format-FileSize $out_files.size))"
    
    $cleanup_needed = ($sim_files.count + $log_files.count + $out_files.count) -gt 10
    if ($cleanup_needed) {
        $report += "- ⚠️ **Cleanup recommended** (many temporary files)"
    }
} else {
    $report += "- ℹ️ **Work directory will be created on first use**"
}

$report += ""

# Project Health Assessment
Write-Host "   📈 Assessing project health..." -ForegroundColor Gray
$report += "## Project Health Assessment"
$report += ""

$health_checks = @()

# Check Icarus Verilog
$iverilog_path = "C:\iverilog\bin\iverilog.exe"
$iverilog_ok = Test-Path $iverilog_path
$health_checks += @{ name = "Icarus Verilog Installation"; status = $iverilog_ok; critical = $true }

# Check core modules
$core_modules_ok = $valid_modules -eq 6
$health_checks += @{ name = "Core Modules Complete"; status = $core_modules_ok; critical = $true }

# Check unified testbenches
$unified_testbenches = Get-DirectoryStats -Directory "$PROJECT_ROOT\testbenches\core" -FilePattern "tb_*_unified.sv"
$testbenches_ok = $unified_testbenches.count -ge 6
$health_checks += @{ name = "Unified Testbenches"; status = $testbenches_ok; critical = $false }

# Check unified scripts
$unified_scripts_ok = (Test-Path "$PROJECT_ROOT\scripts\core\test_core_unified.ps1")
$health_checks += @{ name = "Unified Scripts"; status = $unified_scripts_ok; critical = $false }

$report += "| Component | Status | Critical |"
$report += "|-----------|--------|----------|"

foreach ($check in $health_checks) {
    $status = if ($check.status) { "✅ OK" } else { "❌ Issue" }
    $critical = if ($check.critical) { "Yes" } else { "No" }
    $report += "| $($check.name) | $status | $critical |"
}

$critical_issues = ($health_checks | Where-Object { $_.critical -and !$_.status }).Count
$total_issues = ($health_checks | Where-Object { !$_.status }).Count

$report += ""
if ($critical_issues -eq 0) {
    $report += "🎉 **Project Health: GOOD** - All critical components are working"
} else {
    $report += "⚠️ **Project Health: ISSUES** - $critical_issues critical issues detected"
}

$report += "- **Critical Issues:** $critical_issues"
$report += "- **Total Issues:** $total_issues"
$report += ""

# Next Steps
$report += "## Next Steps"
$report += ""

if ($critical_issues -eq 0) {
    $report += "✅ **Ready for development:**"
    $report += "1. Run ``scripts/core/quick_validate.ps1`` to verify modules"
    $report += "2. Use ``scripts/core/test_core_unified.ps1`` for comprehensive testing"
    $report += "3. Continue with integration testing or new feature development"
} else {
    $report += "🔧 **Issues to resolve:**"
    if (!$iverilog_ok) {
        $report += "1. Install Icarus Verilog at ``C:\iverilog\``"
    }
    if (!$core_modules_ok) {
        $report += "1. Complete core modules implementation in ``modules/core/``"
    }
    $report += "1. Run ``scripts/core/cleanup_project.ps1`` to clean workspace"
}

$report += ""
$report += "---"
$report += "*Report generated by LSE-PE status script*"

# Display Report
Write-Host "`n📋 Project Status Report:" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

$report | ForEach-Object { Write-Host $_ }

# Export if requested
if ($Export) {
    Write-Host "`n💾 Exporting report to file..." -ForegroundColor Yellow
    $report | Out-File -FilePath $REPORT_FILE -Encoding UTF8
    Write-Host "   📄 Report saved: $REPORT_FILE" -ForegroundColor Green
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "🎯 Status analysis complete!" -ForegroundColor Green