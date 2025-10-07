# LSE Add Modu├── 📁 scripts/                    # Scripts d'automatisation
│   ├── core/           ### ModelSim ne s'ouvre pas
```powershell
# Vérifier ModelSim
vsim -version
vlog -version

# Lancement manuel si nécessaire
.\launch_modelsim.ps1 register simple
```  # Scripts pour modules principaux
│   └── test_*.ps1                 # Scripts de test automatisés
├── 📁 modelsim_configs/           # Configurations ModelSim pour chronogrammes
│   ├── wave_register_simple.do    # Configuration simple (recommandée)
│   ├── wave_*_advanced.do         # Configurations avancées (debug)
│   └── wave_*_full.do             # Configurations complètes
├── 📁 simulation_output/          # Fichiers générés par la simulation
│   ├── *.vcd                      # Chronogrammes VCD (compatibilité)
│   └── *.wlf                      # Fichiers ModelSim natifs
├── 📁 work/                       # Bibliothèque ModelSim

Un projet professionnel de simulation SystemVerilog/Verilog avec module d'addition LSE (Log-Sum-Exp).

## 🏗️ Structure du Projet

```
lse_project/
├── 📁 modules/                    # Modules SystemVerilog/Verilog
│   ├── lse_add.sv                 # Module LSE original (SystemVerilog complet)
│   └── lse_add_simple.sv          # Module LSE simplifié (compatible Icarus Verilog)
├── 📁 testbenches/                # Bancs de tests
│   ├── tb_lse_add.sv              # Testbench originale (SystemVerilog)
│   └── tb_lse_add_simple.sv       # Testbench simplifiée (compatible Icarus Verilog)
├── 📁 scripts/                    # Scripts d'automatisation
│   ├── simulate_and_view.ps1      # Script complet: Compilation + Simulation + Visualisation
│   └── launch_gtkwave.ps1         # Lancement rapide de GTKWave
├── 📁 gtkwave_configs/            # Configurations GTKWave pré-définies
│   ├── lse_add_simple.gtkw        # Configuration simple (recommandée)
│   ├── lse_add_advanced.gtkw      # Configuration avancée (debug)
│   └── lse_add_waveform.gtkw      # Configuration générée automatiquement
├── 📁 simulation_output/          # Fichiers générés par la simulation
│   ├── lse_add_waveform.vcd       # Chronogrammes (généré)
│   └── tb_simple.vvp              # Exécutable compilé (généré)
├── 📁 docs/                       # Documentation
│   └── README_detailed.md         # Documentation détaillée
├── 📁 work/                       # Fichiers de compilation QuestaSim/ModelSim
└── README.md                      # Ce fichier
```

## 🚀 Utilisation Rapide

### Méthode Recommandée : Script Tout-en-Un

```powershell
# Depuis la racine du projet
scripts\simulate_and_view.ps1 simple     # Vue organisée (recommandé)
scripts\simulate_and_view.ps1 advanced   # Vue avec signaux internes  
scripts\simulate_and_view.ps1 default    # Vue par défaut
```

### Méthode Alternative : Étapes Séparées

```powershell
# 1. Compilation et simulation
cd lse_project
C:\iverilog\bin\iverilog.exe -g2012 -o simulation_output\tb_simple.vvp -s tb_lse_add_simple modules\lse_add_simple.sv testbenches\tb_lse_add_simple.sv
C:\iverilog\bin\vvp.exe simulation_output\tb_simple.vvp

# 2. Visualisation
.\launch_modelsim.ps1 register simple
```

## 🔧 Outils Requis

- **ModelSim/QuestaSim** : Simulateur professionnel avec interface graphique
- **PowerShell 5.0+** : Pour les scripts d'automatisation

## 📊 Configurations de Visualisation

| Configuration | Description | Usage |
|---------------|-------------|-------|
| **Simple** | Vue organisée, signaux principaux | Usage quotidien, démonstrations |
| **Advanced** | Signaux internes, comparaisons | Debug approfondi, développement |
| **Default** | Vue vierge | Personnalisation libre |

## 🧪 Tests Automatiques

Le projet inclut 8 tests automatiques :
- ✅ **Mode 24-bit** : Opérations LSE haute précision
- ✅ **Mode 6-bit** : Opérations empaquetées (4×6-bit)
- ✅ **Cas spéciaux** : Gestion de l'infini négatif

## 📈 Signaux Principaux

| Signal | Description | Format |
|--------|-------------|---------|
| `clk` | Horloge système | Digital |
| `pe_mode[1:0]` | Mode : 0=24-bit, 1=6-bit | Binary |
| `operand_a/b[23:0]` | Opérandes d'entrée | Hexadécimal |
| `sum_result[23:0]` | Résultat LSE | Hexadécimal |

## 🔍 Dépannage Rapide

### Problème de Compilation
```powershell
# Nettoyer et relancer
Remove-Item simulation_output\* -ErrorAction SilentlyContinue
scripts\simulate_and_view.ps1 simple
```

### GTKWave ne s'ouvre pas
```powershell
# Vérifier Icarus Verilog
C:\iverilog\bin\iverilog.exe -V
C:\iverilog\gtkwave\bin\gtkwave.exe --version

# Lancement manuel
C:\iverilog\gtkwave\bin\gtkwave.exe simulation_output\lse_add_waveform.vcd
```

## 📚 Documentation

- **Documentation complète** : [`docs/README_detailed.md`](docs/README_detailed.md)
- **Code source** : Modules dans [`modules/`](modules/)
- **Tests** : Testbenches dans [`testbenches/`](testbenches/)

## 🏆 Fonctionnalités

- ✅ Structure de projet professionnelle
- ✅ Scripts d'automatisation PowerShell
- ✅ Configurations ModelSim pré-définies
- ✅ Simulation automatisée (ModelSim)
- ✅ Visualisation intégrée (ModelSim GUI)
- ✅ Support multi-mode (24-bit/6-bit)
- ✅ Gestion des cas spéciaux
- ✅ Documentation complète

---

**LSE Project © 2025** - Projet éducatif de simulation SystemVerilog

🔗 **Liens rapides :**
- [📖 Documentation détaillée](docs/README_detailed.md)
- [🔧 Scripts](scripts/)
- [⚙️ Configurations ModelSim](code/modelsim_configs/)
- [📊 Résultats de simulation](simulation_output/)