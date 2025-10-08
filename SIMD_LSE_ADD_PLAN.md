# Extension SIMD pour `lse_add`

## Objectif
- Étendre l'opération `lse_add` pour supporter plusieurs largeurs SIMD (1×24, 2×12, 4×6 bits) comme `lse_mult_simd`.
- Préserver l'algorithme LSE-PE (sélection max, approximation `f~`, correction LUT) tout en isolant les lanes.
- Limiter l'impact sur la latence pipeline existante et réutiliser au maximum les blocs utilitaires (`full_adder`, `mux`).

## État actuel de `lse_add`
- Implémentation scalaire 24 bits avec prise en charge d'un seul mode (`i_pe_mode = 2'b00`).
- Les étapes clés sont :
  1. Détection des cas `NEG_INF`.
  2. Sélection du plus grand (`x`) et du plus petit (`y`).
  3. Calcul de `sub = y - x` puis décomposition en partie entière/fractionnaire.
  4. Approximation `f_tilde` via décalage contrôlé.
  5. Indexation CLUT (table locale 16×10 bits) et correction.
  6. Accumulation des termes étendus + saturation.
- Le hardware suppose un carry global sur toute la largeur pour les additions finales.

## Points de référence dans `lse_mult_simd`
- Gestion des modes via `i_simd_mode` avec un `generate` qui insère des multiplexeurs de reset pour briser le carry.
- Propagation du carry gérée lane par lane :
  - Mode 2×12 : reset à l'indice 12.
  - Mode 4×6  : reset toutes les 6 positions (sauf bit 0).
- Utilisation d'un `carry_chain` commun mais reconditionné par lane.
- Ignorance volontaire des carries de sortie de lane (wrap-around), ce qui reste acceptable pour `lse_mult` car l'opération est une addition entière.

## Contraintes spécifiques à `lse_add`
- Les opérations ne se limitent pas à une addition simple : elles incluent comparaison, décalages et lookup.
- Les lanes doivent demeurer indépendantes :
  - Comparaison `x`/`y` et extraction `sub` doivent se faire par lane.
  - Le LUT `i_clut_values` est partagé (16 entrées) : besoin d'une table par lane, ou d'un accès séquentiel si la latence le permet.
- Les chemins de données signés/fractionnaires exigent une normalisation lane-wise (casting signé, limites `NEG_INF` spécifiques).
- Saturation et gestion des valeurs spéciales doivent respecter la granularité lane.

## Pistes d'architecture
### 1. Partitionnement upfront
- Regrouper les signaux d'entrée en sous-vecteurs en fonction de `i_simd_mode` (`lane_width = 24 >> i_simd_mode` hypothétique).
- Créer des versions lane de `operand_a`, `operand_b` à l'aide de slices contrôlés par un `for` generate.

### 2. Comparaison / sélection par lane
- Instancier un bloc combinatoire reproduisant la logique `if ($signed(a) >= $signed(b))` sur chaque lane.
- Conserver une copie lane-wise de `NEG_INF` (dépend de `lane_width`).

### 3. `f_tilde` et décalages
- Adapter `INT_BITS` / `FRAC_BITS` selon `lane_width`:
  - 24 bits : identique à aujourd'hui.
  - 12 bits : choix à clarifier (garder `FRAC_BITS=10` ? trop grand --> envisager 5-6 bits fractionnaires).
  - 6  bits : nécessite un nouveau paramétrage LUT ou une version compressée.
- Option : introduire une table CLUT par lane (`i_clut_values` devient array [lane][entry]).

### 4. LUT et corrections
- `lse_mult_simd` ne touche pas à la LUT; pour `lse_add`, deux approches :
  1. **Multi-bank LUT** : dupliquer la CLUT pour chaque lane (coût × lanes mais simple).
  2. **Partage séquentiel** : pipeline additionné (+1 cycle) pour multiplexage lane → CLUT → démultiplexage.
- À court terme, privilégier la duplication (simplicité, latence identique), quitte à parametrer `CLUT_SIZE` par lane.

### 5. Addition finale et saturation
- Répliquer l'accumulation saturante par lane.
- Les additions `x_ext + f_tilde_ext + clut_extension` peuvent réutiliser un carry-chain lane-wise semblable à `lse_mult_simd`.
- Saturations individuelles : appliquer les masques sur la largeur lane.

## Modifications RTL envisagées
1. Ajouter une entrée `i_simd_mode` à `lse_add` (alignée sur `lse_mult_simd`).
2. Refactoriser le combinatoire actuel en une boucle `generate` sur les lanes :
   - Calcule un résultat partiel `lane_result`.
   - Recompose `o_result` en réassemblant les lanes (`lane_result` concaténés).
3. Créer une structure de données pour `i_clut_values` adaptée :
   - soit `input logic signed [...] i_clut_values [LANES][CLUT_ENTRIES];`
   - soit conserver l'entrée actuelle mais prévoir un wrapper amont (moins intrusif pour l'instant).
4. Introduire un module utilitaire `lse_add_lane` (optionnel) pour isoler la logique lane et faciliter la vérification.
5. Étendre la machine d'état (si besoin) pour séquencer les accès CLUT en mode partagé.

## Validation & tests
- Mettre à jour `tb_lse_add_unified.sv` pour injecter différents `i_simd_mode` et vérifier :
  - Lanes indépendantes (test addition scalaires packés en 12/6 bits).
  - Cas `NEG_INF` et saturations par lane.
  - Comparaison vs référence Python générée (adapter `generate_lse_add_vectors.py`).
- Ajouter des vecteurs spécifiques :
  - Cas limites par lane (max, min, mélange signe).
  - Cross-check : activer un seul lane non nul et vérifier absence de contamination.
- Inspecter la latence : confirmer que `o_valid_out` reste en phase.

## Questions ouvertes / prochaines étapes
- Quel budget LUT pour les lanes réduites ? Faut-il recalibrer `FRAC_BITS` ?
- Acceptons-nous d'augmenter la surface (duplication CLUT) pour une première version ?
- Souhaite-t-on un module `lse_add_simd` séparé (comme `lse_mult_simd`), ou rétrofiter la version existante avec un paramètre `SIMD_ENABLE` ?
- Niveau pipeline : peut-on rester purement combinatoire lane-wise ou doit-on rajouter des registres intermédiaires pour l'horloge cible ?

---
Ce document sert de point de départ; valider rapidement la stratégie CLUT par lane avant de lancer l'implémentation RTL.
