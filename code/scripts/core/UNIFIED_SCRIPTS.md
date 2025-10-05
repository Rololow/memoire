# Scripts Core Unifiés - LSE-PE Project

## Vue d'ensemble
Les scripts core ont été **standardisés et unifiés** pour automatiser efficacement tous les aspects de développement, test et maintenance du projet LSE-PE.

## Scripts Unifiés Créés

### 1. **run_lse.ps1** - Script Principal (Master Runner)
- **Localisation**: `scripts/run_lse.ps1` (racine des scripts)
- **Fonction**: Point d'entrée unifié pour toutes les opérations du projet
- **Interface**: `.\run_lse.ps1 <command> [target] [options]`
- **Commandes supportées**:
  - `test` : Tests complets des modules core
  - `validate` : Validation rapide des modules
  - `clean` : Nettoyage de l'espace de travail
  - `status` : Rapport de statut du projet
  - `help` : Aide détaillée
- **Features**:
  - ✅ Validation des paramètres d'entrée
  - ✅ Gestion d'erreur robuste avec try/catch
  - ✅ Aide contextuelle avec exemples
  - ✅ Workflows communs prédéfinis

### 2. **test_core_unified.ps1** - Suite de Test Complète
- **Localisation**: `scripts/core/test_core_unified.ps1`
- **Fonction**: Tests automatisés complets pour tous les modules core
- **Interface**: Support pour tests individuels ou globaux
- **Features**:
  - ✅ **Test des 6 modules core** : lse_add, lse_mult, lse_acc, register, einsum_add, einsum_mult
  - ✅ **Compilation automatique** : Icarus Verilog avec gestion d'erreurs
  - ✅ **Simulation automatique** : Exécution VVP avec timeout
  - ✅ **Parsing des résultats** : Extraction automatique des métriques pass/fail
  - ✅ **Rapports détaillés** : Résumé avec pourcentages de réussite
  - ✅ **Mode verbose** : Détails de compilation et simulation
  - ✅ **Stop-on-error** : Option d'arrêt au premier échec

### 3. **quick_validate.ps1** - Validation Rapide
- **Localisation**: `scripts/core/quick_validate.ps1`
- **Fonction**: Validation rapide de l'état de santé des modules core
- **Interface**: Exécution silencieuse avec rapport minimal
- **Features**:
  - ✅ **Tests rapides** : 3 modules critiques (lse_add, lse_mult, register)
  - ✅ **Exécution silencieuse** : Compilation et simulation sans output
  - ✅ **Résultats immédiats** : Status ✅/❌/⚠️ en quelques secondes
  - ✅ **Mode quiet** : Minimal output pour intégration CI/CD
  - ✅ **Exit codes** : 0 = success, 1 = issues détectées

### 4. **cleanup_project.ps1** - Nettoyage Intelligent
- **Localisation**: `scripts/core/cleanup_project.ps1`
- **Fonction**: Nettoyage intelligent de l'espace de travail
- **Interface**: Modes de nettoyage sélectifs avec options
- **Features**:
  - ✅ **Nettoyage sélectif** : Standard, complet, simulation uniquement
  - ✅ **Patterns intelligents** : *.vcd, *.out, *.log, *.tmp, etc.
  - ✅ **Calcul de taille** : Rapport de l'espace libéré
  - ✅ **Vérification de structure** : Recréation des répertoires critiques
  - ✅ **Mode verbose** : Détails des fichiers supprimés
  - ✅ **Protection** : Préservation des fichiers source critiques

### 5. **project_status.ps1** - Rapport de Statut Complet
- **Localisation**: `scripts/core/project_status.ps1`
- **Fonction**: Génération de rapports de statut détaillés du projet
- **Interface**: Rapports console ou exportation Markdown
- **Features**:
  - ✅ **Analyse structurelle** : Modules, testbenches, scripts
  - ✅ **Vérification d'intégrité** : Validation syntax SystemVerilog
  - ✅ **Métriques détaillées** : Nombre de fichiers, tailles, lignes de code
  - ✅ **Health checks** : Icarus Verilog, modules core, testbenches
  - ✅ **Export Markdown** : Rapport exportable pour documentation
  - ✅ **Recommandations** : Next steps basés sur l'analyse

## Standards des Scripts

### Interface Unifiée
```powershell
# Standard parameter patterns
param(
    [string]$Target = "all",      # Module or operation target
    [switch]$Verbose = $false,    # Detailed output
    [switch]$Force = $false,      # Force operations
    [switch]$Export = $false      # Export results
)
```

### Gestion d'Erreur Robuste
```powershell
# Standard error handling
try {
    # Script operations
    $result = Invoke-Operation
    Write-Host "✅ SUCCESS" -ForegroundColor Green
}
catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

### Conventions de Sortie
- **Couleurs standardisées** : Green (✅), Red (❌), Yellow (⚠️), Cyan (ℹ️)
- **Formats de message** : `[timestamp] STATUS - Message`
- **Rapports structurés** : Headers, sections, summary
- **Exit codes** : 0 = success, 1 = error, 2 = warning

## Workflows d'Utilisation

### 1. **Workflow de Développement Quotidien**
```powershell
# Quick health check
.\run_lse.ps1 validate

# Full test suite after changes
.\run_lse.ps1 test

# Clean workspace when needed
.\run_lse.ps1 clean
```

### 2. **Workflow de Debug et Diagnostic**
```powershell
# Detailed project status
.\run_lse.ps1 status detailed -Export

# Verbose testing of specific module
.\run_lse.ps1 test lse_add -Verbose

# Complete cleanup and retest
.\run_lse.ps1 clean all
.\run_lse.ps1 test -Verbose
```

### 3. **Workflow d'Intégration Continue**
```powershell
# Silent validation for CI/CD
.\run_lse.ps1 validate summary

# Automated testing with exit codes
.\run_lse.ps1 test
if ($LASTEXITCODE -eq 0) { 
    Write-Host "Build SUCCESS" 
} else { 
    Write-Host "Build FAILED" 
    exit 1 
}
```

## Automatisation et Intégration

### Features d'Automatisation
- ✅ **Exit codes standardisés** pour intégration CI/CD
- ✅ **Output parsable** pour scripts upstream
- ✅ **Timeouts configurables** pour prévenir les blocages
- ✅ **Logging automatique** avec timestamps
- ✅ **Error recovery** avec nettoyage automatique

### Intégration avec Icarus Verilog
- ✅ **Detection automatique** de l'installation Icarus Verilog
- ✅ **Arguments standardisés** : `-g2012` pour SystemVerilog
- ✅ **Gestion des erreurs** de compilation et simulation
- ✅ **Redirections propres** : stdout/stderr séparés
- ✅ **Nettoyage automatique** des fichiers temporaires

## Migration des Anciens Scripts

### Remplacements Directs
- `test_simd_*.ps1` → `.\run_lse.ps1 test`
- `run_all_testbenches.ps1` → `.\run_lse.ps1 test`
- `validate_all_tests.ps1` → `.\run_lse.ps1 validate`
- Scripts de nettoyage manuels → `.\run_lse.ps1 clean`

### Scripts Obsolètes à Supprimer
- `scripts/test_simd_24b.ps1` (remplacé)
- `scripts/test_simd_comb.ps1` (remplacé)
- `scripts/test_simd_simple.ps1` (remplacé)
- `scripts/run_all_testbenches.ps1` (remplacé)
- `scripts/run_fixed_testbenches.ps1` (remplacé)
- `scripts/validate_all_tests.ps1` (remplacé)

## Prochaines Étapes
1. ✅ **Modules Core**: Terminé (6/6 modules)
2. ✅ **Testbenches Core**: Terminé (6/6 testbenches)
3. ✅ **Scripts Core**: Terminé (5/5 scripts)
4. 🔄 **Cleanup Final**: Supprimer les anciens fichiers dupliqués
5. 🔄 **Documentation**: Mettre à jour README avec nouveaux workflows

---
**Date**: Décembre 2024  
**Status**: Core scripts unifiés et automatisés ✅