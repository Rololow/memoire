# Guide d'Utilisation - Script de Test LSE Unifié

## Vue d'ensemble

Le script `run_lse_tests.py` orchestre la compilation et la simulation de l’ensemble des testbenches LSE-PE, y compris la validation de l’implémentation de l’**Algorithm 1** (`lse_add`).

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

### Préparation (vecteurs de référence LSE Add)

Avant de lancer la simulation, générer les vecteurs exacts utilisés par `tb_lse_add_unified` :

```powershell
cd C:\Users\waric\Documents\memoire\code
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe scripts/python/generate_lse_add_vectors.py
```

Le fichier `testbenches/core/reference/lse_add_reference_vectors.svh` sera régénéré automatiquement. Adapter les options (`--tolerance-lsb`, `--random`, `--seed`) si besoin.

### Commandes de Base

```powershell
# Tester tous les modules
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe run_lse_tests.py

# Tester uniquement LSE Add (Algorithm 1)
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe run_lse_tests.py -m lse_add

# Tester plusieurs modules spécifiques
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe run_lse_tests.py -m lse_add lse_mult lse_acc

# Mode verbose avec détails de compilation et simulation
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe run_lse_tests.py -m lse_add -v

# Nettoyer avant de tester
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe run_lse_tests.py --clean

# Sauvegarder le rapport dans un fichier spécifique
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe run_lse_tests.py --report ..\simulation_output\mon_rapport.json

# Ne pas mettre à jour les valeurs CLUT
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe run_lse_tests.py --no-clut-update
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

## Comprendre les Résultats

### Format de Sortie

`run_lse_tests.py` affiche un résumé par module (PASS / PARTIAL / FAIL) ainsi que le total des tests passés/échoués. Un rapport JSON détaillé est également écrit (voir `--report`). Les chiffres exacts dépendront de l’état courant des sources et des vecteurs générés.

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

## Résultats et diagnostic

Le script ne fournit pas de « vérité absolue » hardcodée : il interprète la sortie des testbenches. Pensez à :

- vérifier le rapport JSON (`simulation_output/lse_test_report.json` par défaut) après chaque exécution ;
- relancer `generate_lse_add_vectors.py` lorsqu’une modification touche `lse_add` ou son testbench ;
- comparer les vecteurs générés avec vos attentes (fichiers JSON/SVH).

Les informations chiffrées d’un rapport précédent (ex. succès partiel du 7 octobre 2025) ne reflètent pas nécessairement l’état courant.

## Rapport JSON

Le script génère automatiquement un rapport JSON détaillé :

```json
{
  "timestamp": "2025-10-07T20:55:36.902376",
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
      "details": ["#  PASS - Commutative: LSE(6.0, 4.0) = LSE(4.0, 6.0)"]
    }
  ]
}
```

Utilisez ce format comme base et comparez les chiffres lors des prochaines exécutions.

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

## Support

Pour toute question ou problème :
1. Vérifier ce README
2. Consulter la documentation dans `docs/`
3. Examiner les fichiers de log dans `work/`
4. Utiliser le mode verbose `-v`

---

*Document créé le 7 octobre 2025*  
*Version : 2.0 - Script Python Unifié*