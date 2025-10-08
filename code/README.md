# LSE-PE – Log-Sum-Exp Processing Element

Implémentation matérielle de la fonction Log-Sum-Exp destinée au raisonnement probabiliste. Le dépôt regroupe les modules SystemVerilog, les testbenches unifiés, ainsi qu’un environnement Python/PowerShell pour automatiser la génération des vecteurs de référence et l’exécution des simulations ModelSim/QuestaSim.

## Vue d’ensemble

-- **Format de données** : 24 bits (14 entiers / 10 fractionnaires). Note: les variantes SIMD 4×6 bits ont été retirées du code actif et archivées.
- **Modules cœur** : addition LSE (Algorithm 1), multiplication log-space, accumulateur LSE, MAC log-space et CLUT partagée.
- **Système partagé** : quatre MACs parallèles consommant une seule CLUT (arbitrage round-robin).
- **Testbenches** : bancs auto‑vérifiants pour chaque bloc + un banc système complet.
- **Scripts** : `run_lse_tests.py` pour compiler/simuler, `generate_lse_add_vectors.py` pour fabriquer des données de référence haute précision.

## Générer les vecteurs de référence LSE Add

Les tests de `tb_lse_add_unified` s’appuient sur un fichier `SVH` auto-généré. Après chaque modification algorithmique, exécuter :

```powershell
cd C:\Users\waric\Documents\memoire\code
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe scripts/python/generate_lse_add_vectors.py
```

Le script produit :

- `simulation_output/lse_add_reference_vectors.json` (trace détaillée),
- `testbenches/core/reference/lse_add_reference_vectors.svh` (incluable côté SystemVerilog).

Des options permettent d’ajuster la tolérance (`--tolerance-lsb`), la graine (`--seed`) ou le nombre de cas aléatoires (`--random`).

## Exécuter la suite de tests unifiée

Pré-requis :

- ModelSim / QuestaSim (Starter ou édition complète) installé ;
- commandes `vlib`, `vlog`, `vsim` accessibles ou chemin renseigné dans `run_lse_tests.py` (`MODELSIM_BIN`).

Étapes typiques :

```powershell
cd C:\Users\waric\Documents\memoire\code\scripts
C:/Users/waric/AppData/Local/Programs/Python/Python312/python.exe run_lse_tests.py --modules lse_add lse_mult lse_acc register lse_shared_system --report ..\simulation_output\lse_test_report.json
```

- `--modules` accepte `all` ou un sous-ensemble.
- `--clean` purgera les artefacts ModelSim avant compilation.
- `-v/--verbose` affiche les journaux complets de `vlog` et `vsim`.
- `--no-clut-update` désactive l’exécution automatique du générateur CLUT historique.

Le script synthétise un rapport JSON (succès, échecs, détails) et récapitule en console le nombre de tests exécutés/passed/failed. Aucune garantie n’est fournie tant que la simulation n’a pas été relancée après vos modifications.

## Structure du dépôt

```
code/
├── modules/
│   ├── core/               # lse_add.sv, lse_mult.sv, lse_acc.sv, lse_log_mac.sv, register.sv, etc.
│   ├── lut/                # lse_clut_shared.sv (CLUT mutualisée)
│   └── lse_shared_system.sv
├── testbenches/
│   ├── core/               # Bancs unitaires unifiés + références auto-générées
│   └── tb_lse_shared_system.sv
├── scripts/
│   ├── run_lse_tests.py    # Pilote ModelSim/QuestaSim
│   └── python/             # Générateurs Python (références LSE, CLUT)
├── docs/                   # Documentation détaillée et rapports d’avancement
├── simulation_output/      # Rapports JSON, VCD, vecteurs de référence
└── gtkwave_configs/        # Configurations de visualisation (optionnel)
```

## Modules SystemVerilog

-- `core/lse_add.sv` – mise en œuvre matérielle de l’Algorithm 1 (delta, CLUT).
-- `core/lse_mult.sv` – addition en espace log (mode scalaire 24-bit). SIMD support retiré.
- `core/lse_acc.sv` – accumulateur LSE (16 bits) avec correctifs graduels.
- `core/lse_log_mac.sv` & `core/lse_pe_with_mux.sv` – unité MAC complète prête à l’intégration.
- `lut/lse_clut_shared.sv` – ROM de correction (64×10 bits) avec arbitrage 4 voies.
- `lse_shared_system.sv` – agrégation de quatre MACs et pipeline commun.

Chaque banc d’essai unifié (`testbenches/core/*.sv`) expose un compteur Pass/Fail, applique les vecteurs de référence et génère un sommaire final.

## Documentation utile

- `docs/PROGRESS_REPORT.md` – synthèse des jalons, état des tests et actions à venir.
- `docs/UNIFIED_TEST.md` – guide d’utilisation détaillé de `run_lse_tests.py`.
- `docs/README_detailed.md` – analyse approfondie de l’architecture et des choix de conception.

## Contribution

Le projet est développé dans le cadre du mémoire de Robin Warichet. Les contributions (issues, PRs) sont bienvenues pour améliorer la précision, enrichir les tests ou porter l’architecture sur FPGA. Pour toute question technique, consultez la documentation dans `docs/` ou ouvrez une discussion dédiée.

---

**Dernière mise à jour :** 7 octobre 2025 – introduction des vecteurs de référence auto-générés pour `lse_add` et refonte de la documentation de test.