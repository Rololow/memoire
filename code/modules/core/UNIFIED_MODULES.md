# Modules Core Unifiés - LSE-PE Project

## Vue d'ensemble
Les modules core ont été **standardisés et unifiés** pour éliminer la duplication et établir une interface cohérente à travers tout le projet LSE-PE.

## Modules Unifiés Créés

### 1. **lse_add.sv** - LSE Addition Core
- **Fonction**: Addition Log-Sum-Exp avec correction LUT
- **Interface standardisée**: `operand_a`, `operand_b`, `result`, `pe_mode`
- **Paramètres**: `WIDTH=24`, `LUT_SIZE=1024`, `LUT_PRECISION=10`
- **Modes supportés**: 24-bit, 6-bit (4x packed)
- **Compatible**: Icarus Verilog / Standard Verilog

### 2. **lse_mult.sv** - LSE Multiplication Core
- **Fonction**: Multiplication en espace logarithmique (addition en log-space)
- **Interface standardisée**: `operand_a`, `operand_b`, `result`, `pe_mode`
- **Paramètres**: `WIDTH=24`
- **Modes supportés**: 24-bit, 6-bit (4x packed)
- **Logique**: `log(a*b) = log(a) + log(b)`

### 3. **lse_acc.sv** - LSE Accumulator Core
- **Fonction**: Accumulation LSE 16-bit optimisée
- **Interface standardisée**: `accumulator_in`, `addend_in`, `accumulator_out`
- **Paramètres**: `INT_BITS=12`, `FRAC_BITS=3`, `WIDTH=16`
- **Optimisation**: Arithmétique fixed-point pour accumulation rapide

### 4. **register.sv** - Generic Register Core
- **Fonction**: Registre paramétrable avec reset synchrone
- **Interface standardisée**: `clk`, `rst`, `data_in`, `data_out`
- **Paramètres**: `WIDTH=32` (configurable)
- **Reset**: Synchrone, actif haut

### 5. **einsum_add.sv** - Einsum Addition Wrapper
- **Fonction**: Wrapper registré pour lse_add avec bypass
- **Interface standardisée**: `operand_a`, `operand_b`, `sum_out`, `enable`, `bypass`
- **Paramètres**: `WORD_WIDTH=32`, `LUT_SIZE=1024`, `LUT_PRECISION=10`
- **Features**: Enable/disable, bypass mode

### 6. **einsum_mult.sv** - Einsum Multiplication Wrapper
- **Fonction**: Wrapper registré pour lse_mult avec bypass
- **Interface standardisée**: `operand_a`, `operand_b`, `product_out`, `enable`, `bypass`
- **Paramètres**: `WORD_WIDTH=32`
- **Features**: Enable/disable, bypass mode

## Standards d'Interface

### Noms de Ports Standardisés
- **Entrées**: `operand_a`, `operand_b`, `data_in`, `clk`, `rst`, `enable`
- **Sorties**: `result`, `data_out`, `sum_out`, `product_out`
- **Modes**: `pe_mode` (24-bit=0, 6-bit=1)

### Noms de Paramètres Standardisés
- **Largeur**: `WIDTH`, `WORD_WIDTH`
- **Bits**: `INT_BITS`, `FRAC_BITS`
- **LUT**: `LUT_SIZE`, `LUT_PRECISION`

### Conventions de Nommage
- **Processus**: `module_name_proc` (ex: `lse_add_proc`)
- **Signaux internes**: `snake_case` sans préfixes
- **Constantes**: `UPPER_CASE` avec `localparam`

## Compatibilité
- ✅ **Icarus Verilog**: Syntax standard Verilog uniquement
- ✅ **Standard Verilog**: Pas de SystemVerilog avancé
- ✅ **Synthesizable**: Code synthesizable pour FPGA
- ✅ **No Dependencies**: Aucune dépendance externe

## Migration des Anciens Modules

### Remplacements Directs
- `lse_add_simple.sv` → `lse_add.sv` (unifié)
- `lse_acc.sv` (ancien) → `lse_acc.sv` (unifié)
- `lse_mult.sv` (ancien) → `lse_mult.sv` (unifié)
- `register.sv` (ancien) → `register.sv` (unifié)

### Modules Obsolètes à Supprimer
- `modules/lse_add_simple.sv` (dupliqué)
- `modules/lse_add.sv` (ancien, avec dépendances)
- `modules/lse_acc.sv` (ancien)
- `modules/lse_mult.sv` (ancien)
- `modules/einsum_*.sv` (anciens)

## Prochaines Étapes
1. ✅ **Modules Core**: Terminé (6/6 modules)
2. 🔄 **Testbenches**: Consolider dans `testbenches/core/`
3. 🔄 **Scripts**: Consolider dans `scripts/core/`
4. 🔄 **Cleanup**: Supprimer anciens fichiers dupliqués

---
**Date**: Décembre 2024  
**Status**: Core modules unifiés et standardisés ✅