# =============================================================================
# LSE-PE Quick Test Runner (Simple)
# Description: Simplified entry point for LSE-PE project operations
# Version: Conflict-free runner for LSE-PE project
# =============================================================================

param(
    [string]$Action = "help"
)

$PROJECT_ROOT = "C:\Users\waric\Documents\mémoire\code"
$SCRIPTS_DIR = "$PROJECT_ROOT\scripts\core"

switch ($Action.ToLower()) {
    "validate" {
        Write-Host "🚀 Running quick validation..." -ForegroundColor Green
        Set-Location $SCRIPTS_DIR
        & ".\quick_validate.ps1"
    }
    "test" {
        Write-Host "🚀 Running full tests..." -ForegroundColor Green
        Set-Location $SCRIPTS_DIR
        & ".\test_core_unified.ps1"
    }
    "clean" {
        Write-Host "🚀 Cleaning project..." -ForegroundColor Green
        Set-Location $SCRIPTS_DIR
        & ".\cleanup_project.ps1"
    }
    "status" {
        Write-Host "🚀 Generating status report..." -ForegroundColor Green
        Set-Location $SCRIPTS_DIR
        & ".\project_status.ps1"
    }
    default {
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "              LSE-PE Quick Runner" -ForegroundColor Cyan
        Write-Host "================================================================" -ForegroundColor Cyan
        Write-Host "`nUsage:" -ForegroundColor Yellow
        Write-Host "  .\quick_run.ps1 validate    # Quick validation" -ForegroundColor White
        Write-Host "  .\quick_run.ps1 test        # Full tests" -ForegroundColor White
        Write-Host "  .\quick_run.ps1 clean       # Clean workspace" -ForegroundColor White
        Write-Host "  .\quick_run.ps1 status      # Project status" -ForegroundColor White
        Write-Host "================================================================" -ForegroundColor Cyan
    }
}