# =============================================================================
# Script de Test Complet - Toutes les Testbenches LSE
# Description: Exécute toutes les testbenches et compile les résultats
# =============================================================================

Write-Host "🔬 LSE Test Suite - Exécution Complète" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Répertoire de travail
$workDir = "c:\Users\waric\Documents\memoire\code\work"
Set-Location $workDir

# Liste des testbenches à exécuter
$testbenches = @(
    @{
        Name = "LSE Add (Core)"
        Module = "lse_add"
        Testbench = "tb_lse_add_unified"
        Sources = @(
            "../modules/core/lse_add.sv",
            "../testbenches/core/tb_lse_add_unified.sv"
        )
    },
    @{
        Name = "LSE Mult (Core)"
        Module = "lse_mult" 
        Testbench = "tb_lse_mult_unified"
        Sources = @(
            "../modules/core/lse_mult.sv",
            "../testbenches/core/tb_lse_mult_unified.sv"
        )
    },
    @{
        Name = "LSE Accumulator (Core)"
        Module = "lse_acc"
        Testbench = "tb_lse_acc_unified"
        Sources = @(
            "../modules/core/lse_acc.sv",
            "../testbenches/core/tb_lse_acc_unified.sv"
        )
    },
    @{
        Name = "Register (Core)"
        Module = "register"
        Testbench = "tb_register_unified"
        Sources = @(
            "../modules/core/register.sv",
            "../testbenches/core/tb_register_unified.sv"
        )
    },
    @{
        Name = "LSE Shared System"
        Module = "lse_shared_system"
        Testbench = "tb_lse_shared_system"
        Sources = @(
            "../modules/core/lse_add.sv",
            "../modules/core/lse_mult.sv",
            "../modules/core/lse_acc.sv",
            "../modules/core/lse_pe_with_mux.sv",
            "../modules/lut/lse_clut_shared.sv",
            "../modules/core/lse_log_mac.sv",
            "../modules/lse_shared_system.sv",
            "../testbenches/tb_lse_shared_system.sv"
        )
    }
)

# Résultats compilés
$results = @()

# Fonction pour extraire les résultats des tests
function Extract-TestResults {
    param($output, $testName)
    
    $result = @{
        TestName = $testName
        Status = "UNKNOWN"
        PassedTests = 0
        TotalTests = 0
        SuccessRate = 0.0
        Details = @()
        Output = $output
    }
    
    # Chercher les résultats dans la sortie
    if ($output -match "Total Tests:\s+(\d+)") {
        $result.TotalTests = [int]$matches[1]
    }
    
    if ($output -match "Passed:\s+(\d+)") {
        $result.PassedTests = [int]$matches[1]
    }
    
    if ($result.TotalTests -gt 0) {
        $result.SuccessRate = ($result.PassedTests / $result.TotalTests) * 100
        
        if ($result.PassedTests -eq $result.TotalTests) {
            $result.Status = "PASS"
        } elseif ($result.PassedTests -gt 0) {
            $result.Status = "PARTIAL"
        } else {
            $result.Status = "FAIL"
        }
    }
    
    # Extraire les détails des tests individuels
    $lines = $output -split "`n"
    foreach ($line in $lines) {
        if ($line -match "(✅|❌|PASS|FAIL).*?([^:]+)") {
            $result.Details += $line.Trim()
        }
    }
    
    return $result
}

# Exécuter chaque testbench
foreach ($test in $testbenches) {
    Write-Host "`n🧪 Test: $($test.Name)" -ForegroundColor Yellow
    Write-Host "-" * 50 -ForegroundColor Yellow
    
    try {
        # Construire la commande de compilation
        $sources = $test.Sources -join "; vlog -sv "
        $compileCmd = "vlib work; vlog -sv $sources"
        
        # Commande complète
        $fullCmd = "vsim -c -do `"$compileCmd; vsim -c $($test.Testbench); run -all; quit -f`""
        
        Write-Host "Compilation et exécution..." -ForegroundColor Gray
        
        # Exécuter la testbench
        $output = & cmd /c $fullCmd 2>&1
        $outputStr = $output -join "`n"
        
        # Extraire les résultats
        $testResult = Extract-TestResults -output $outputStr -testName $test.Name
        $results += $testResult
        
        # Afficher le résultat
        $statusColor = switch ($testResult.Status) {
            "PASS" { "Green" }
            "PARTIAL" { "Yellow" }
            "FAIL" { "Red" }
            default { "Gray" }
        }
        
        Write-Host "Statut: $($testResult.Status)" -ForegroundColor $statusColor
        Write-Host "Tests: $($testResult.PassedTests)/$($testResult.TotalTests) ($($testResult.SuccessRate.ToString("F1"))%)" -ForegroundColor $statusColor
        
        if ($testResult.Details.Count -gt 0) {
            Write-Host "Détails:" -ForegroundColor Gray
            foreach ($detail in $testResult.Details | Select-Object -First 5) {
                Write-Host "  $detail" -ForegroundColor Gray
            }
            if ($testResult.Details.Count -gt 5) {
                Write-Host "  ... et $($testResult.Details.Count - 5) autres" -ForegroundColor Gray
            }
        }
        
    } catch {
        Write-Host "❌ Erreur lors de l'exécution: $_" -ForegroundColor Red
        $results += @{
            TestName = $test.Name
            Status = "ERROR"
            PassedTests = 0
            TotalTests = 0
            SuccessRate = 0.0
            Details = @("Erreur d'exécution: $_")
        }
    }
}

# Résumé global
Write-Host "`n" + "=" * 60 -ForegroundColor Cyan
Write-Host "📊 RÉSUMÉ GLOBAL DES TESTS" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

$totalPassed = ($results | Measure-Object PassedTests -Sum).Sum
$totalTests = ($results | Measure-Object TotalTests -Sum).Sum
$globalSuccessRate = if ($totalTests -gt 0) { ($totalPassed / $totalTests) * 100 } else { 0 }

Write-Host "`nStatistiques Globales:" -ForegroundColor White
Write-Host "  Tests Total: $totalTests" -ForegroundColor White
Write-Host "  Tests Réussis: $totalPassed" -ForegroundColor Green
Write-Host "  Tests Échoués: $($totalTests - $totalPassed)" -ForegroundColor Red
Write-Host "  Taux de Réussite Global: $($globalSuccessRate.ToString("F1"))%" -ForegroundColor $(if ($globalSuccessRate -ge 80) { "Green" } elseif ($globalSuccessRate -ge 60) { "Yellow" } else { "Red" })

Write-Host "`nRésultats par Module:" -ForegroundColor White
foreach ($result in $results) {
    $statusIcon = switch ($result.Status) {
        "PASS" { "✅" }
        "PARTIAL" { "⚠️ " }
        "FAIL" { "❌" }
        "ERROR" { "💥" }
        default { "❓" }
    }
    
    Write-Host "  $statusIcon $($result.TestName): $($result.PassedTests)/$($result.TotalTests) ($($result.SuccessRate.ToString("F1"))%)" -ForegroundColor $(
        switch ($result.Status) {
            "PASS" { "Green" }
            "PARTIAL" { "Yellow" }
            "FAIL" { "Red" }
            "ERROR" { "Magenta" }
            default { "Gray" }
        }
    )
}

# Analyse des problèmes
Write-Host "`n🔍 Analyse des Problèmes:" -ForegroundColor White
$failedTests = $results | Where-Object { $_.Status -eq "FAIL" -or $_.Status -eq "PARTIAL" }

if ($failedTests.Count -eq 0) {
    Write-Host "  🎉 Aucun problème détecté ! Tous les tests passent." -ForegroundColor Green
} else {
    Write-Host "  Modules nécessitant attention:" -ForegroundColor Yellow
    foreach ($failed in $failedTests) {
        Write-Host "    • $($failed.TestName): $($failed.SuccessRate.ToString("F1"))% de réussite" -ForegroundColor Yellow
    }
}

# Recommandations
Write-Host "`n💡 Recommandations:" -ForegroundColor White
if ($globalSuccessRate -ge 90) {
    Write-Host "  🎯 Excellent ! Le système LSE est très stable." -ForegroundColor Green
    Write-Host "  📈 Considérer l'optimisation des performances." -ForegroundColor Green
} elseif ($globalSuccessRate -ge 70) {
    Write-Host "  👍 Bon niveau de fonctionnalité." -ForegroundColor Yellow
    Write-Host "  🔧 Corriger les modules partiellement fonctionnels." -ForegroundColor Yellow
} else {
    Write-Host "  ⚠️  Problèmes significatifs détectés." -ForegroundColor Red
    Write-Host "  🛠️  Révision approfondie nécessaire des algorithmes LSE." -ForegroundColor Red
}

Write-Host "`n📁 Logs détaillés disponibles dans les fichiers de sortie" -ForegroundColor Gray
Write-Host "✨ Test Suite Terminé" -ForegroundColor Cyan