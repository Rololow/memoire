# LSE Add Module - Simulation et Visualisation

Ce projet contient un module d'addition LSE (Log-Sum-Exp) avec support de visualisation des chronogrammes via GTKWave.

## 🏗️ Structure du Projet

```
lse_project/
├── modules/
│   ├── lse_add.sv              # Module LSE original (SystemVerilog complet)
│   └── lse_add_simple.sv       # Module LSE simplifié (compatible Icarus Verilog)
├── testbenches/
│   ├── tb_lse_add.sv           # Testbench originale (SystemVerilog)
│   └── tb_lse_add_simple.sv    # Testbench simplifiée (compatible Icarus Verilog)
├── work/                       # Fichiers de compilation QuestaSim/ModelSim
├── *.gtkw                      # Fichiers de configuration GTKWave
├── *.ps1                       # Scripts PowerShell d'automatisation
└── README.md                   # Ce fichier
```

## 🔧 Outils Installés

- **Icarus Verilog 12.0** : Simulateur open source (`C:\iverilog\`)
- **GTKWave 3.3.100** : Visualiseur de chronogrammes (inclus avec Icarus)
- **QuestaSim 2024.3** : Simulateur professionnel (problème de licence)

## 🚀 Utilisation Rapide

### Méthode 1 : Script Automatique (Recommandé)

```powershell
# Compilation + Simulation + Visualisation en une commande
.\simulate_and_view.ps1 simple     # Vue organisée (recommandé)
.\simulate_and_view.ps1 advanced   # Vue avec signaux internes
.\simulate_and_view.ps1 default    # Vue par défaut
```

### Méthode 2 : Étapes Manuelles

```powershell
# 1. Compilation
C:\iverilog\bin\iverilog.exe -g2012 -o tb_simple.vvp -s tb_lse_add_simple modules/lse_add_simple.sv testbenches/tb_lse_add_simple.sv

# 2. Simulation
C:\iverilog\bin\vvp.exe tb_simple.vvp

# 3. Visualisation
.\launch_gtkwave.ps1 simple
```

## 📊 Configurations GTKWave

### Configuration Simple (`lse_add_simple.gtkw`)
- ✅ Vue organisée avec séparateurs
- ✅ Signaux principaux en hexadécimal  
- ✅ Analyse des segments 6-bit
- ✅ Idéale pour débuggage général

### Configuration Avancée (`lse_add_advanced.gtkw`)
- 🔬 Signaux internes du DUT
- 🔬 Comparaison testbench vs DUT
- 🔬 Segments colorés
- 🔬 Parfaite pour analyse approfondie

## 📈 Signaux Importants

| Signal | Description | Format |
|--------|-------------|---------|
| `clk` | Horloge système | Digital |
| `rst_n` | Reset actif bas | Digital |
| `pe_mode[1:0]` | Mode : 0=24-bit, 1=6-bit | Binary |
| `operand_a[23:0]` | Premier opérande | Hexadécimal |
| `operand_b[23:0]` | Second opérande | Hexadécimal |
| `sum_result[23:0]` | Résultat LSE | Hexadécimal |

## 🧪 Tests Inclus

La testbench exécute 8 tests automatiques :

1. **Tests 24-bit** : Opérations LSE en précision complète
   - Addition basique : `0x100000 + 0x200000 = 0x210000`
   - Valeurs grandes : `0x500000 + 0x300000 = 0x530000`
   - Zéro + Normal : `0x000000 + 0x123456 = 0x123456`
   - Valeurs aléatoires

2. **Tests 6-bit** : Opérations LSE empaquetées (4x 6-bit)
   - Segments séquentiels
   - Additions parallèles

3. **Tests spéciaux** : Gestion de l'infini négatif
   - `NEG_INF + Normal = Normal`
   - `Normal + NEG_INF = Normal`

## 💡 Conseils GTKWave

### Navigation
- **Zoom horizontal** : `Ctrl + Molette`
- **Zoom vertical** : `Shift + Molette` 
- **Ajustement optimal** : `Menu Time > Zoom > Zoom Best Fit`
- **Navigation temporelle** : Barres de défilement

### Personnalisation
- **Format d'affichage** : Clic droit sur signal > Data Format
- **Couleurs** : Clic droit > Color Format
- **Groupement** : Sélectionner plusieurs signaux + clic droit
- **Export image** : `File > Print To File`

### Formats Utiles
- **Binaire** : Pour les signaux de contrôle
- **Hexadécimal** : Pour les données (par défaut)
- **Décimal signé** : Pour les valeurs numériques
- **ASCII** : Pour les chaînes (si applicable)

## 🔍 Analyse des Résultats

### Mode 24-bit
- Observer les transitions complètes sur 24 bits
- Vérifier la gestion des valeurs spéciales (0x800000 = -∞)
- Analyser la précision des calculs LSE

### Mode 6-bit 
- Examiner les 4 segments [23:18], [17:12], [11:6], [5:0]
- Vérifier les opérations parallèles
- Comparer avec les attentes théoriques

### Validation
- Tous les tests doivent passer (8/8)
- Aucune valeur 'X' ou 'Z' dans les résultats
- Transitions propres sur les fronts d'horloge

## 🛠️ Dépannage

### Problème de Compilation
```powershell
# Vérifier Icarus Verilog
C:\iverilog\bin\iverilog.exe -V

# Nettoyer et recompiler
Remove-Item tb_simple.vvp -ErrorAction SilentlyContinue
.\simulate_and_view.ps1 simple
```

### Problème GTKWave
```powershell
# Lancement manuel
C:\iverilog\gtkwave\bin\gtkwave.exe lse_add_waveform.vcd

# Régénérer la configuration
Remove-Item *.gtkw
.\simulate_and_view.ps1 simple
```

### Fichier VCD Manquant
- Vérifier que `$dumpfile()` et `$dumpvars()` sont dans la testbench
- S'assurer que la simulation se termine normalement
- Contrôler les permissions d'écriture

## 📚 Ressources

- **Icarus Verilog** : http://iverilog.icarus.com/
- **GTKWave** : http://gtkwave.sourceforge.net/
- **SystemVerilog** : IEEE 1800-2017 Standard
- **LSE Mathematics** : Log-Sum-Exp function theory

## 🏆 Fonctionnalités

- ✅ Simulation automatisée
- ✅ Visualisation pré-configurée  
- ✅ Scripts d'automatisation
- ✅ Support multi-mode (24-bit/6-bit)
- ✅ Gestion des cas spéciaux
- ✅ Documentation complète
- ✅ Compatible Windows PowerShell

---
*Généré automatiquement - LSE Project © 2025*