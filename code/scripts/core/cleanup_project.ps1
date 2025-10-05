# =============================================================================
# Cleanup Script for LSE-PE Project
# Description: Clean temporary files and prepare workspace
# Version: Unified cleanup for LSE-PE project
# =============================================================================

param(
    [switch]$All = $false,        # Clean everything including logs
    [switch]$SimOnly = $false,    # Clean only simulation files
    [switch]$Verbose = $false     # Show detailed output
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "              LSE-PE Project Cleanup Utility" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# =============================================================================
# Configuration
# =============================================================================
$PROJECT_ROOT = "C:\Users\waric\Documents\mémoire\code"
$WORK_DIR = "$PROJECT_ROOT\work"
$OUTPUT_DIR = "$PROJECT_ROOT\simulation_output"

# File patterns to clean
$SIM_FILES = @("*.vcd", "*.out", "*.log", "*.wlf", "*.vstf")
$TEMP_FILES = @("*.tmp", "*.bak", "*~", ".DS_Store", "Thumbs.db")
$BUILD_FILES = @("work.*", "_info", "_lib*", "_vmake")

# =============================================================================
# Cleanup Functions
# =============================================================================
function Remove-FilesByPattern {
    param(
        [string]$Directory,
        [string[]]$Patterns,
        [string]$Description
    )
    
    if (!(Test-Path $Directory)) {
        if ($Verbose) { Write-Host "   Directory not found: $Directory" -ForegroundColor Gray }
        return 0
    }
    
    $removed_count = 0
    $total_size = 0
    
    foreach ($pattern in $Patterns) {
        $files = Get-ChildItem -Path $Directory -Filter $pattern -ErrorAction SilentlyContinue
        
        foreach ($file in $files) {
            try {
                $file_size = $file.Length
                Remove-Item $file.FullName -Force
                $removed_count++
                $total_size += $file_size
                
                if ($Verbose) {
                    $size_mb = [math]::Round($file_size / 1MB, 2)
                    Write-Host "     Removed: $($file.Name) ($size_mb MB)" -ForegroundColor Gray
                }
            }
            catch {
                Write-Host "     Failed to remove: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    if ($removed_count -gt 0) {
        $size_mb = [math]::Round($total_size / 1MB, 2)
        Write-Host "   ✅ $Description : $removed_count files removed ($size_mb MB)" -ForegroundColor Green
    } else {
        if ($Verbose) { Write-Host "   ℹ️  $Description : No files to remove" -ForegroundColor Gray }
    }
    
    return $removed_count
}

function Clean-Directory {
    param([string]$Directory, [string]$Description)
    
    if (!(Test-Path $Directory)) {
        if ($Verbose) { Write-Host "   Directory not found: $Directory" -ForegroundColor Gray }
        return 0
    }
    
    try {
        $files = Get-ChildItem -Path $Directory -Recurse -File -ErrorAction SilentlyContinue
        $file_count = $files.Count
        $total_size = ($files | Measure-Object -Property Length -Sum).Sum
        
        Remove-Item "$Directory\*" -Recurse -Force -ErrorAction SilentlyContinue
        
        if ($file_count -gt 0) {
            $size_mb = [math]::Round($total_size / 1MB, 2)
            Write-Host "   ✅ $Description : $file_count files removed ($size_mb MB)" -ForegroundColor Green
        } else {
            if ($Verbose) { Write-Host "   ℹ️  $Description : Directory already clean" -ForegroundColor Gray }
        }
        
        return $file_count
    }
    catch {
        Write-Host "   ❌ Failed to clean $Description : $($_.Exception.Message)" -ForegroundColor Red
        return 0
    }
}

# =============================================================================
# Main Cleanup Logic
# =============================================================================
Write-Host "`n🧹 Starting cleanup process..." -ForegroundColor Yellow
Write-Host "   Mode: $(if ($All) { 'Complete cleanup' } elseif ($SimOnly) { 'Simulation files only' } else { 'Standard cleanup' })" -ForegroundColor Gray
Write-Host "   Verbose: $Verbose" -ForegroundColor Gray

$total_removed = 0
$start_time = Get-Date

# Clean work directory
Write-Host "`n📂 Cleaning work directory..." -ForegroundColor Cyan
$total_removed += Remove-FilesByPattern -Directory $WORK_DIR -Patterns $SIM_FILES -Description "Simulation files"

if (!$SimOnly) {
    $total_removed += Remove-FilesByPattern -Directory $WORK_DIR -Patterns $BUILD_FILES -Description "Build files"
    $total_removed += Remove-FilesByPattern -Directory $WORK_DIR -Patterns $TEMP_FILES -Description "Temporary files"
}

# Clean simulation output directory
if (Test-Path $OUTPUT_DIR) {
    Write-Host "`n📂 Cleaning simulation output directory..." -ForegroundColor Cyan
    if ($All) {
        $total_removed += Clean-Directory -Directory $OUTPUT_DIR -Description "All simulation outputs"
    } else {
        $total_removed += Remove-FilesByPattern -Directory $OUTPUT_DIR -Patterns @("*.log", "*.tmp") -Description "Log and temp files"
    }
}

# Clean project root temporary files
if (!$SimOnly) {
    Write-Host "`n📂 Cleaning project root..." -ForegroundColor Cyan
    $total_removed += Remove-FilesByPattern -Directory $PROJECT_ROOT -Patterns $TEMP_FILES -Description "Root temporary files"
}

# Clean testbench directories
if ($All) {
    $testbench_dirs = @(
        "$PROJECT_ROOT\testbenches\core",
        "$PROJECT_ROOT\testbenches\integration",
        "$PROJECT_ROOT\testbenches\simd"
    )
    
    Write-Host "`n📂 Cleaning testbench directories..." -ForegroundColor Cyan
    foreach ($dir in $testbench_dirs) {
        if (Test-Path $dir) {
            $total_removed += Remove-FilesByPattern -Directory $dir -Patterns @("*.log", "*.vcd", "*.out") -Description "Testbench files in $(Split-Path $dir -Leaf)"
        }
    }
}

# Clean script directories
if ($All) {
    $script_dirs = @(
        "$PROJECT_ROOT\scripts\core",
        "$PROJECT_ROOT\scripts\integration"
    )
    
    Write-Host "`n📂 Cleaning script directories..." -ForegroundColor Cyan
    foreach ($dir in $script_dirs) {
        if (Test-Path $dir) {
            $total_removed += Remove-FilesByPattern -Directory $dir -Patterns @("*.log", "*.tmp") -Description "Script logs in $(Split-Path $dir -Leaf)"
        }
    }
}

# Summary
$duration = (Get-Date) - $start_time
Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "                       Cleanup Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Total files removed: $total_removed" -ForegroundColor White
Write-Host "Cleanup duration:    $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor White

if ($total_removed -gt 0) {
    Write-Host "`n✨ Cleanup completed successfully! Project workspace is clean." -ForegroundColor Green
} else {
    Write-Host "`n💡 Workspace was already clean. Nothing to remove." -ForegroundColor Blue
}

# Verify critical directories exist
Write-Host "`n🔍 Verifying directory structure..." -ForegroundColor Cyan
$critical_dirs = @($WORK_DIR, $OUTPUT_DIR, "$PROJECT_ROOT\modules\core", "$PROJECT_ROOT\testbenches\core", "$PROJECT_ROOT\scripts\core")

foreach ($dir in $critical_dirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "   ✅ Created missing directory: $(Split-Path $dir -Leaf)" -ForegroundColor Green
    } else {
        if ($Verbose) { Write-Host "   ✅ Verified directory: $(Split-Path $dir -Leaf)" -ForegroundColor Green }
    }
}

Write-Host "`n🎯 LSE-PE project is ready for development!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan