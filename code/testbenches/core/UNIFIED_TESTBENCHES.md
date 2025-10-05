# Testbenches Core Unifiés - LSE-PE Project

## Vue d'ensemble
Les testbenches core ont été **standardisés et unifiés** pour tester efficacement tous les modules core avec une interface cohérente et des procédures de test complètes.

## Testbenches Unifiés Créés

### 1. **tb_lse_add_unified.sv** - Test LSE Addition
- **Module testé**: `lse_add` (core unified)
- **Interface standardisée**: `operand_a`, `operand_b`, `result`, `pe_mode`, `lut_table`
- **Couverture de test**: 
  - ✅ Mode 24-bit : Addition LSE de base, valeurs spéciales (NEG_INF)
  - ✅ Mode 6-bit : Opérations packed 4x, cas d'edge
  - ✅ Initialisation LUT : 1024 entrées avec valeurs de correction
- **Tests**: 15+ vecteurs de test avec validation automatique

### 2. **tb_lse_mult_unified.sv** - Test LSE Multiplication
- **Module testé**: `lse_mult` (core unified)
- **Interface standardisée**: `operand_a`, `operand_b`, `result`, `pe_mode`
- **Couverture de test**:
  - ✅ Mode 24-bit : Multiplication log-space (log(a*b) = log(a) + log(b))
  - ✅ Mode 6-bit : 4x packed operations avec gestion des signes
  - ✅ Valeurs spéciales : NEG_INF propagation, overflow protection
- **Tests**: 15+ vecteurs incluant cas d'edge et overflow

### 3. **tb_lse_acc_unified.sv** - Test LSE Accumulator
- **Module testé**: `lse_acc` (core unified)
- **Interface standardisée**: `accumulator_in`, `addend_in`, `accumulator_out`
- **Couverture de test**:
  - ✅ Accumulation de base : Addition LSE 16-bit avec arithmétique fixed-point
  - ✅ Gestion des signes : Même signe (addition), signes différents (soustraction)
  - ✅ Séquences d'accumulation : Tests séquentiels pour validation comportementale
- **Tests**: 20+ vecteurs avec tolérance d'approximation LSE

### 4. **tb_register_unified.sv** - Test Register Generic
- **Module testé**: `register` (core unified)
- **Interface standardisée**: `clk`, `rst`, `data_in`, `data_out`
- **Couverture de test**:
  - ✅ Fonctionnalité reset : Reset synchrone actif haut
  - ✅ Opération normale : Stockage et persistance des données
  - ✅ Cas d'edge : Valeurs min/max, changements rapides
- **Tests**: 15+ vecteurs incluant persistence et edge cases

### 5. **tb_einsum_add_unified.sv** - Test Einsum Add Wrapper
- **Module testé**: `einsum_add` (core unified)
- **Interface standardisée**: `clk`, `rst`, `enable`, `bypass`, `operand_a`, `operand_b`, `sum_out`
- **Couverture de test**:
  - ✅ Contrôle enable/disable : Gestion du signal d'activation
  - ✅ Mode bypass : Pass-through de operand_a
  - ✅ Fonctionnalité LSE : Wrapper autour de lse_add avec registres
- **Tests**: 20+ vecteurs incluant séquences et contrôles

### 6. **tb_einsum_mult_unified.sv** - Test Einsum Mult Wrapper
- **Module testé**: `einsum_mult` (core unified)
- **Interface standardisée**: `clk`, `rst`, `enable`, `bypass`, `operand_a`, `operand_b`, `product_out`
- **Couverture de test**:
  - ✅ Contrôle enable/disable : Gestion du signal d'activation
  - ✅ Mode bypass : Pass-through de operand_a
  - ✅ Fonctionnalité LSE : Wrapper autour de lse_mult avec registres
- **Tests**: 20+ vecteurs incluant séquences et overflow

## Standards de Test

### Structure de Test Unifiée
```systemverilog
task apply_test_vector;
  input [WIDTH-1:0] test_inputs...;
  input [WIDTH-1:0] expected;
  input [200*8-1:0] test_name;
  // Validation automatique avec compteurs pass/fail
endtask
```

### Métriques de Test
- **Compteurs automatiques**: `test_count`, `pass_count`, `fail_count`
- **Validation avec tolérance**: Pour approximations LSE
- **Reporting détaillé**: ✅ PASS / ❌ FAIL avec détails
- **Résumé final**: Pourcentages et statut global

### Conventions de Nommage
- **Testbenches**: `tb_[module]_unified.sv`
- **Instances DUT**: `dut` (standardisé)
- **Signaux**: Noms identiques aux ports du module
- **Tasks**: `apply_test_vector`, `initialize_lut`

## Couverture de Test Complète

### Types de Tests Inclus
1. **Reset Functionality** : Vérification du reset synchrone
2. **Basic Operations** : Fonctions de base des modules
3. **Special Values** : NEG_INF, zéros, valeurs max
4. **Mode Testing** : 24-bit vs 6-bit packed modes
5. **Edge Cases** : Overflow, underflow, saturations
6. **Sequential Operations** : Comportement sur plusieurs cycles
7. **Control Signals** : Enable, disable, bypass modes

### Validation Automatisée
- ✅ **Pass/Fail automatique** avec seuils de tolérance
- ✅ **Messages détaillés** pour debugging
- ✅ **Résumé statistique** en fin de test
- ✅ **Compatible Icarus Verilog** (syntax standard)

## Migration des Anciens Testbenches

### Remplacements Directs
- `tb_lse_add_simple.sv` → `tb_lse_add_unified.sv`
- `tb_lse_add.sv` → `tb_lse_add_unified.sv`
- `tb_lse_mult.sv` → `tb_lse_mult_unified.sv`
- `tb_lse_acc.sv` → `tb_lse_acc_unified.sv`
- `tb_register.sv` → `tb_register_unified.sv`
- `tb_einsum_*.sv` → `tb_einsum_*_unified.sv`

### Testbenches Obsolètes à Supprimer
- `testbenches/tb_lse_add_simple.sv` (dupliqué)
- `testbenches/tb_lse_add.sv` (ancien)
- `testbenches/tb_lse_mult.sv` (ancien)
- `testbenches/tb_lse_acc.sv` (ancien)
- `testbenches/tb_register.sv` (ancien)
- `testbenches/tb_einsum_*.sv` (anciens)

## Prochaines Étapes
1. ✅ **Modules Core**: Terminé (6/6 modules)
2. ✅ **Testbenches Core**: Terminé (6/6 testbenches)
3. 🔄 **Scripts Core**: Consolider les scripts de test
4. 🔄 **Cleanup Final**: Supprimer les anciens fichiers dupliqués

---
**Date**: Décembre 2024  
**Status**: Core testbenches unifiés et standardisés ✅