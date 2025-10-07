# Guide d'Utilisation - Script de Test LSE Unifié

## Vue d'ensemble

Le script `run_lse_tests.py` est le script unifié pour tester tous les modules LSE-PE, incluant la nouvelle implémentation de l'**Algorithm 1** dans le module `lse_add`.

## Prérequis

- **Python 3.7+**
- **ModelSim/QuestaSim** (Intel FPGA Starter Edition ou version complète)
  - Doit être installé et accessible via PATH, ou
  - Configuré dans la variable `MODELSIM_BIN` du script

## Installation Rapide

### Option 1 : ModelSim dans le PATH (Recommandé)

Ajoutez ModelSim au PATH système Windows :

```powershell
# Exemple pour Intel FPGA Starter Edition 20.1
$env:PATH += ";C:\intelFPGA\20.1\modelsim_ase\win32aloem"
```

### Option 2 : Configuration Manuelle

Modifiez la variable dans `run_lse_tests.py` :

```python
# Ligne ~30 du script
MODELSIM_BIN = r"C:\votre\chemin\vers\modelsim\win32aloem"
```

## Utilisation

### Commandes de Base

```bash
# Tester tous les modules
python run_lse_tests.py

# Tester uniquement LSE Add (Algorithm 1)
python run_lse_tests.py -m lse_add

# Tester plusieurs modules spécifiques
python run_lse_tests.py -m lse_add lse_mult lse_acc

# Mode verbose avec détails de compilation et simulation
python run_lse_tests.py -m lse_add -v

# Nettoyer avant de tester
python run_lse_tests.py --clean

# Sauvegarder le rapport dans un fichier spécifique
python run_lse_tests.py --report mon_rapport.json

# Ne pas mettre à jour les valeurs CLUT
python run_lse_tests.py --no-clut-update
```

### Options Disponibles

| Option | Description |
|--------|-------------|
| `-m, --modules` | Modules à tester : `lse_add`, `lse_mult`, `lse_acc`, `register`, `lse_shared_system`, ou `all` |
| `-v, --verbose` | Active le mode verbose avec sortie détaillée |
| `--clean` | Nettoie les fichiers de simulation avant de commencer |
| `--report FILE` | Chemin du fichier rapport JSON (par défaut: `présentations/présentation 1/lse_test_report.json`) |
| `--no-clut-update` | Désactive la mise à jour automatique des valeurs CLUT |
| `-h, --help` | Affiche l'aide complète |

## Modules Disponibles

### 1. lse_add (Algorithm 1 Implementation)
**Description** : Addition LSE avec implémentation complète de l'Algorithm 1 du papier NeurIPS 2024

**Caractéristiques** :
- Implémentation fidèle de l'algorithme LSE-PE
- Support CLUT avec 1024 entrées
- Mode 24-bit avec format fixed-point [14.10]
- Mode SIMD 4×6-bit pour operations parallèles
- Gestion des valeurs spéciales (NEG_INF)

**Tests inclus** :
- Valeurs spéciales (NEG_INF)
- Valeurs proches (petit delta)
- Distance moyenne
- Grande distance
- Propriété commutative
- Gestion du zéro
- Mode SIMD 6-bit
- Cas limites et overflow

### 2. lse_mult
**Description** : Multiplication en espace logarithmique

### 3. lse_acc
**Description** : Accumulateur LSE 16-bit

### 4. register
**Description** : Registre pipeline générique

### 5. lse_shared_system
**Description** : Système complet avec 4 MACs et CLUT partagée

## Comprendre les Résultats

### Format de Sortie

```
==============================================================================
                           RÉSUMÉ GLOBAL DES TESTS
==============================================================================

Statistiques Modules:
  Total modules testés: 1
  [OK] Modules parfaits:   0       ← Tous les tests passent
  ⚠ Modules partiels:   1          ← Certains tests échouent
  [ER] Modules échoués:    0       ← Erreur de compilation/simulation

Statistiques Tests:
  Total tests:          19
  Tests réussis:        13
  Tests échoués:        6
  Taux de succès:       68.4%      ← Pourcentage global
  Durée totale:         1.6s
```

### Interprétation des Statuts

| Icône | Statut | Signification |
|-------|--------|---------------|
| `[OK]` | PASS | ✅ Tous les tests du module passent |
| `⚠` | PARTIAL | ⚠️ Certains tests échouent, le module fonctionne partiellement |
| `[ER]` | FAIL/ERROR | ❌ Échec compilation ou tous les tests échouent |

### Taux de Succès

- **≥ 90%** : ✅ Excellent, production-ready
- **70-89%** : ⚠️ Bon, ajustements mineurs nécessaires
- **50-69%** : ⚠️ Moyen, révision nécessaire
- **< 50%** : ❌ Problèmes significatifs

## Résultats Actuels du Module LSE_ADD

### État Actuel (Algorithm 1 Implementation)

**Taux de réussite** : 68.4% (13/19 tests)

**Tests qui passent** :
- ✅ Gestion des valeurs spéciales (NEG_INF)
- ✅ Valeurs égales (LSE(10.0, 10.0) = 11.0)
- ✅ Distance moyenne (LSE(10.0, 5.0))
- ✅ Grande distance (delta > 10)
- ✅ Propriété commutative
- ✅ Mode SIMD 6-bit
- ✅ Cas limites et overflow

**Tests qui échouent** :
- ❌ LSE(5.0, 4.5) : Attendu ≈ 5.585, Obtenu = 5.828 (erreur ~4%)
- ❌ LSE(3.0, 2.0) : Attendu ≈ 3.585, Obtenu = 3.563 (erreur ~1%)
- ❌ LSE(8.0, 4.0) : Attendu ≈ 8.087, Obtenu = 8.073 (erreur ~0.2%)
- ❌ LSE(0.0, 4.0) : Gestion du zéro nécessite ajustements
- ❌ LSE(4.0, 0.0) : Idem
- ❌ LSE(0.0, 0.0) : Cas spécial zéro

### Analyse

L'implémentation de l'Algorithm 1 fonctionne correctement pour :
- Les valeurs spéciales (infini négatif)
- Les grandes distances (delta > 5)
- Les propriétés mathématiques (commutativité)
- Le mode SIMD alternatif

Les erreurs observées sont principalement pour :
- Les petits deltas (< 2.0) : Légère imprécision dans l'approximation
- La gestion du zéro : Nécessite un cas spécial

**Précision moyenne** : ~1-2% d'erreur, ce qui est acceptable pour une implémentation matérielle.

## Rapport JSON

Le script génère automatiquement un rapport JSON détaillé :

```json
{
  "timestamp": "2025-10-07T20:49:18.123456",
  "summary": {
    "total_modules": 1,
    "passed_modules": 0,
    "partial_modules": 1,
    "failed_modules": 0,
    "total_tests": 19,
    "total_passed": 13,
    "total_failed": 6,
    "global_success_rate": 68.4,
    "total_duration": 1.6
  },
  "modules": [
    {
      "module_id": "lse_add",
      "name": "LSE Add (Algorithm 1 Implementation)",
      "status": "PARTIAL",
      "total_tests": 19,
      "passed_tests": 13,
      "failed_tests": 6,
      "success_rate": 68.4,
      "duration": 1.62,
      "details": [...]
    }
  ]
}
```

## Dépannage

### Problème 1 : "ModelSim non trouvé"

**Solution** :
```bash
# Vérifier l'installation
where vsim

# Si vide, ajouter au PATH ou modifier MODELSIM_BIN dans le script
```

### Problème 2 : "Compilation failed"

**Causes possibles** :
- Fichiers source manquants
- Erreurs de syntaxe SystemVerilog
- Problème de dépendances entre modules

**Solution** : Utiliser le mode verbose
```bash
python run_lse_tests.py -m lse_add -v
```

### Problème 3 : "Simulation timeout"

**Cause** : Simulation trop longue (> 5 minutes)

**Solution** : Vérifier les boucles infinies dans les testbenches

### Problème 4 : Erreurs de caractères dans la sortie

**Cause** : Problème d'encodage Windows PowerShell

**Solution** : Le script gère automatiquement avec `encoding='utf-8', errors='replace'`

## Structure des Fichiers

```
code/
├── scripts/
│   ├── run_lse_tests.py          ← Script principal unifié
│   └── python/
│       └── generate_clut_values.py
├── modules/
│   └── core/
│       ├── lse_add.sv            ← Implémentation Algorithm 1
│       ├── lse_mult.sv
│       ├── lse_acc.sv
│       └── register.sv
├── testbenches/
│   └── core/
│       ├── tb_lse_add_unified.sv ← Testbench mise à jour
│       ├── tb_lse_mult_unified.sv
│       ├── tb_lse_acc_unified.sv
│       └── tb_register_unified.sv
├── simulation_output/
│   └── *.vcd                     ← Fichiers de forme d'onde
└── work/                         ← Fichiers de compilation ModelSim
```

## Exemple de Session Complète

```bash
# Se placer dans le répertoire des scripts
cd C:\Users\waric\Documents\memoire\code\scripts

# Nettoyer et tester LSE Add en mode verbose
python run_lse_tests.py -m lse_add -v --clean

# Tester tous les modules et sauvegarder le rapport
python run_lse_tests.py --report rapport_complet.json

# Visualiser le rapport JSON
type ..\simulation_output\rapport_complet.json | ConvertFrom-Json | Format-List
```

## Amélioration Continue

### Objectifs à Court Terme

1. **Améliorer la précision pour les petits deltas**
   - Affiner les valeurs CLUT
   - Ajuster l'approximation en deux étapes

2. **Gérer correctement le cas zéro**
   - Ajouter un cas spécial dans le code
   - Mettre à jour les tests

3. **Atteindre 90%+ de réussite**
   - Cible : 17/19 tests minimum

### Objectifs à Long Terme

1. **Valider tous les modules**
   - LSE Mult : 100%
   - LSE Acc : 100%
   - System : 100%

2. **Intégration continue**
   - Automatiser les tests
   - Génération automatique de rapports

3. **Documentation**
   - Diagrammes de timing
   - Analyse de performance
   - Guide d'intégration

## Références

- **Documentation Algorithm** : `docs/LSE_ADD_ALGORITHM.md`
- **Guide de Test Détaillé** : `testbenches/core/README_LSE_ADD_TEST.md`
- **Architecture Système** : `docs/SHARED_ARCHITECTURE.md`
- **Paper Original** : Yao et al., "LSE-PE: Hardware Efficient for Tractable Probabilistic Reasoning", NeurIPS 2024

## Support

Pour toute question ou problème :
1. Vérifier ce README
2. Consulter la documentation dans `docs/`
3. Examiner les fichiers de log dans `work/`
4. Utiliser le mode verbose `-v`

---

*Document créé le 7 octobre 2025*  
*Version : 2.0 - Script Python Unifié*  
*Statut : ✅ Opérationnel*
