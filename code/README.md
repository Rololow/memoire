# LSE-PE: Log-Sum-Exp Processing Element

## Description du Projet

Ce projet implémente une architecture matérielle innovante pour l'accélération des calculs de **Log-Sum-Exp (LSE)** destinée au raisonnement probabiliste. L'architecture **LSE-PE** propose une solution efficace pour surmonter les limitations des systèmes de calcul traditionnels lors du traitement de modèles probabilistes nécessitant une large plage dynamique.

### Contexte et Motivation

Les modèles probabilistes (PMs) offrent des avantages significatifs par rapport aux réseaux de neurones profonds classiques :
- **Transparence et interprétabilité** : Les décisions sont explicables
- **Estimation d'incertitude** : Quantification de la confiance des prédictions
- **Détection d'outliers** : Identification de données hors distribution

Cependant, ces modèles nécessitent de calculer des probabilités extrêmement petites (ex: 2^(-12000)) qui causent des problèmes d'**underflow** dans les systèmes en virgule flottante traditionnels.

### Solution Proposée : LSE-PE

L'architecture **LSE-PE** utilise le domaine logarithmique pour étendre la plage dynamique tout en maintenant une précision élevée et un coût matériel faible.

#### Principe Fondamental

La fonction Log-Sum-Exp permet d'éviter l'underflow :
```
LSE(x, y) = max(x,y) + log(1 + 2^(min(x,y) - max(x,y)))
```

#### Innovation : Double Approximation

1. **Approximation Exponentielle** : `2^z ≈ z + 1` (Approximation de Mitchell)
2. **Approximation Logarithmique** : `log₂(1 + z) ≈ z`
3. **Correction d'erreur** : CLUT compacte (16×10 bits)

**Résultat** : Opérations complexes réduites à des additions et des décalages de bits !

### Architecture du Système

Le projet contient plusieurs modules SystemVerilog organisés de manière modulaire :

## Structure du Projet

```
code/
├── modules/           # Modules SystemVerilog principaux
├── testbenches/       # Bancs d'essais pour validation
├── scripts/           # Scripts PowerShell d'automatisation
├── gtkwave_configs/   # Configurations GTKWave pour visualisation
├── simulation_output/ # Résultats de simulation
├── work/             # Répertoire de travail ModelSim/Questasim
└── docs/             # Documentation détaillée
```

## Modules Principaux

### 1. Modules LSE Core

#### `lse_add.sv` & `lse_add_simple.sv`
- **Fonction** : Addition Log-Sum-Exp de base
- **Features** : 
  - Format 24 bits (14 entiers + 10 fractionnaires)
  - Gestion des valeurs spéciales (NEG_INF)
  - Comparaison et sélection du maximum

#### `lse_mult.sv`
- **Fonction** : Multiplication en domaine logarithmique
- **Implémentation** : Addition simple des logarithmes
- **Optimisations** : 
  - Détection des cas spéciaux (zéro, infini)
  - Mode 6 bits pour cas particuliers

#### `lse_acc.sv` & `lse_acc_fixed.sv`
- **Fonction** : Accumulateur LSE pour séquences de valeurs
- **Features** :
  - Accumulation 16 bits avec protection overflow
  - Approximation intelligente pour grandes différences
  - Seuil adaptatif (s_diff >= 0x0FFF)

### 2. Modules Utilitaires

#### `register.sv` & `register_simple.sv`
- **Fonction** : Registres paramétrés avec reset
- **Paramètres** : Largeur configurable
- **Applications** : Stockage temporaire dans le pipeline

#### `einsum_add.sv` & `einsum_mult.sv`
- **Fonction** : Opérations Einstein notation
- **Usage** : Support pour calculs tensoriels avancés

### 3. Modules Vectoriels

#### `vec_alu.sv`
- **Fonction** : ALU vectorielle pour opérations SIMD
- **Support** : Operations parallèles sur vecteurs

### 4. Packages SystemVerilog

#### `common_pkg.sv`
- Définitions communes et constantes du projet

#### `utils_pkg.sv`
- Fonctions utilitaires et helpers

#### `instr_decd_pkg.sv`
- Package de décodage d'instructions

## Bancs d'Essais (Testbenches)

### Tests Unitaires
- `tb_lse_add_simple.sv` : 8 tests de base LSE
- `tb_lse_mult.sv` : 26 tests multiplication logarithmique  
- `tb_lse_acc.sv` : 27 tests accumulateur LSE
- `tb_register.sv` : 48 tests registres paramétrés

### Tests d'Intégration
- `tb_lse_comprehensive.sv` : Tests complets du système LSE
- `tb_einsum_add.sv` : Validation opérations einsum

### Résultats de Tests
**État actuel** : **100% de succès** sur l'ensemble des tests
- **Total** : 109 tests individuels réussis
- **Couverture** : Tous les modules critiques validés
- **Performance** : Aucun underflow détecté

## Scripts d'Automatisation

### `scripts/init_project.ps1`
Initialisation de l'environnement de développement :
- Configuration ModelSim/Questasim
- Compilation des packages et modules
- Création des répertoires de travail

### `scripts/simulate_and_view.ps1`
Pipeline de simulation complète :
- Compilation incrémentale des sources modifiées
- Exécution des testbenches
- Lancement automatique de GTKWave
- Génération de rapports de test

### `scripts/validate_all_tests.ps1`
Validation globale du projet :
- Exécution séquentielle de tous les testbenches
- Comptage automatique des tests réussis/échoués
- Génération d'un rapport de synthèse
- Vérification de la couverture fonctionnelle

### `scripts/launch_gtkwave.ps1`
Utilitaire de visualisation :
- Chargement des configurations GTKWave prédéfinies
- Ouverture des fichiers VCD de simulation
- Application des filtres de signaux personnalisés

## Performances et Résultats

### Comparaison avec l'État de l'Art

| Système | Bits | Surface (μm²) | Puissance (mW) | Range |
|---------|------|---------------|----------------|-------|
| FP32 | 32 | 115,911 | 91.68 | 2^(-126) à 2^127 |
| Posit32 | 32 | 395,161 | 488.98 | 2^(-120) à 2^120 |
| **LSE-PE** | **24** | **53,049** | **29.69** | **2^(-16384) à 2^0** |

### Gains de LSE-PE
- **Surface** : 54% de réduction par rapport à FP32
- **Puissance** : 68% de réduction par rapport à FP32  
- **Range dynamique** : 130× supérieur à FP32
- **Précision** : Erreur < 0.2% sur tous les benchmarks

### Validation sur Benchmarks Réels

| Dataset | Features | Avg log₂ LL | FP32 Error | LSE-PE Error |
|---------|----------|-------------|------------|--------------|
| nltcs | 16 | -9.85 | 4.5e-3 | **1.1e-3** |
| plants | 69 | -51.39 | 5.6e-7 | **1.5e-3** |
| adult | 123 | -124.68 | 2.3e-7 | **7.0e-4** |
| dna | 180 | -186.63 | **inf** | **1.1e-3** |
| mnist | 784 | -261.45 | **inf** | **8.9e-5** |
| ad | 1556 | -1512.51 | **inf** | **9.9e-4** |

## Applications Pratiques

### 1. Détection d'Outliers pour DNNs
- **Coût** : 0.4% à 20% du modèle DNN principal
- **Avantage** : Seul système sans underflow sur grands modèles
- **Usage** : Classification MNIST avec détection SEMEION/SVHN

### 2. Circuits Probabilistes (PCs)
- **Structure** : Graphes acycliques dirigés (DAG)
- **Opérations** : Nœuds somme (⊕) et produit (⊗)
- **Inférence** : Exacte en temps polynomial

### 3. Raisonnement Neuro-Symbolique
- **BNNs** : Bayesian Neural Networks
- **HMMs** : Hidden Markov Models  
- **TPMs** : Tractable Probabilistic Models

## Prérequis Système

### Outils de Simulation
- **ModelSim/Questasim** : Simulation SystemVerilog
- **Icarus Verilog** : Alternative open-source supportée
- **GTKWave** : Visualisation de formes d'onde

### Environnement de Développement
- **PowerShell** : Scripts d'automatisation
- **SystemVerilog** : IEEE 1800-2017
- **Git** : Contrôle de version (optionnel)

## Installation et Utilisation

### 1. Initialisation
```powershell
cd scripts
.\init_project.ps1
```

### 2. Simulation Complète
```powershell
.\simulate_and_view.ps1
```

### 3. Validation des Tests
```powershell
.\validate_all_tests.ps1
```

### 4. Visualisation des Résultats
```powershell
.\launch_gtkwave.ps1
```

## Configuration GTKWave

Le projet inclut des configurations GTKWave prédéfinies :

- `lse_add_simple.gtkw` : Signaux de base pour LSE addition
- `lse_add_advanced.gtkw` : Vue détaillée avec chronogrammes
- `lse_add_waveform.gtkw` : Configuration complète de debug

## Développement et Extension

### Ajout de Nouveaux Modules

1. **Créer le module** dans `modules/`
2. **Développer le testbench** dans `testbenches/`
3. **Ajouter aux scripts** de compilation
4. **Valider avec** `validate_all_tests.ps1`

### Optimisations Futures

- **Pipeline plus profond** : Réduction de la période d'horloge
- **SIMD étendu** : Support de vecteurs plus larges
- **CLUT adaptatif** : Correction d'erreur dynamique
- **Support multi-précision** : 16, 32, 64 bits

## Publications et Références

Ce travail est basé sur :
- **Yao et al.**, "LSE-PE: Hardware Efficient for Tractable Probabilistic Reasoning", IEEE Transactions on Circuits and Systems I, 2025
- **Architecture originale** développée pour raisonnement probabiliste hardware-friendly
- **Validation** sur benchmarks standards de la communauté

## Licence et Contributions

Ce projet est développé dans le cadre d'un mémoire de recherche. Les contributions sont les bienvenues via pull requests.

### Contact
Pour questions techniques ou collaborations, référez-vous à la documentation détaillée dans `docs/README_detailed.md`.

---

**Statut** : ✅ Production Ready  
**Tests** : ✅ 109/109 Passing (100%)  
**Documentation** : ✅ Complète  