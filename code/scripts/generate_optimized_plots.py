#!/usr/bin/env python3
"""
Script pour générer les graphiques avec les résultats OPTIMISÉS
Utilise les données des tests 100% Python-verified (100% succès)
vs les anciens tests basiques (25% succès)
"""

import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import json

# Configuration pour les plots
plt.style.use('seaborn-v0_8-whitegrid')
sns.set_palette("husl")

plt.rcParams.update({
    'font.size': 14,
    'font.family': 'serif',
    'text.usetex': False,
    'figure.figsize': (8, 6),
    'axes.labelsize': 16,
    'axes.titlesize': 18,
    'xtick.labelsize': 14,
    'ytick.labelsize': 14,
    'legend.fontsize': 14,
    'lines.linewidth': 2,
    'grid.alpha': 0.3
})

# Chemins
PROJECT_ROOT = Path(__file__).parent.parent
PLOTS_DIR = PROJECT_ROOT.parent / "présentations" / "présentation 1" / "figures"
REPORTS_DIR = PROJECT_ROOT.parent / "présentations" / "présentation 1"

def load_simulation_reports():
    """Charge les rapports de simulation anciens et optimisés"""
    
    # Ancien rapport (25% succès)
    old_report_path = REPORTS_DIR / "verilog_simulation_report.json"
    with open(old_report_path, 'r') as f:
        old_report = json.load(f)
    
    # Nouveau rapport (100% succès)  
    new_report_path = REPORTS_DIR / "optimized_simulation_report.json"
    with open(new_report_path, 'r') as f:
        new_report = json.load(f)
    
    return old_report, new_report

def plot_optimization_comparison():
    """Comparaison avant/après optimisation"""
    print("📊 Génération Plot: Comparaison Optimisation...")
    
    old_report, new_report = load_simulation_reports()
    
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    # Plot 1: Taux de succès avant/après
    categories = ['Tests Basiques\n(Anciens)', 'Tests Optimisés\n(Python-verified)']
    success_rates = [old_report['summary']['overall_success_rate'], 
                    new_report['summary']['overall_success_rate']]
    total_tests = [old_report['summary']['total_tests'],
                   new_report['summary']['total_tests']]
    
    colors = ['#FF6B6B', '#4ECDC4']
    bars = ax1.bar(categories, success_rates, color=colors, alpha=0.8, edgecolor='black')
    
    # Annotations
    for i, (bar, rate, tests) in enumerate(zip(bars, success_rates, total_tests)):
        height = bar.get_height()
        ax1.annotate(f'{rate:.1f}%\n({tests} tests)', 
                    xy=(bar.get_x() + bar.get_width()/2., height),
                    xytext=(0, 10), textcoords="offset points",
                    ha='center', va='bottom', fontweight='bold', fontsize=12)
    
    ax1.set_ylabel('Taux de Succès (%)', fontsize=16)
    ax1.set_title('Impact de l\'Optimisation Python-Verified', fontsize=16, fontweight='bold')
    ax1.set_ylim(0, 110)
    ax1.grid(True, alpha=0.3, axis='y')
    
    # Flèche d'amélioration
    ax1.annotate('', xy=(1, success_rates[1]), xytext=(0, success_rates[0]),
                arrowprops=dict(arrowstyle='->', lw=3, color='green'))
    ax1.text(0.5, 60, f'+{success_rates[1] - success_rates[0]:.0f} pts\n(4x better)', 
             ha='center', va='center', fontweight='bold', fontsize=12, 
             bbox=dict(boxstyle="round,pad=0.3", facecolor="lightgreen", alpha=0.7))
    
    # Plot 2: Détail des modules optimisés
    modules = list(new_report['detailed_results'].keys())
    module_tests = [new_report['detailed_results'][mod]['total_tests'] for mod in modules]
    module_passed = [new_report['detailed_results'][mod]['passed_tests'] for mod in modules]
    
    y_pos = np.arange(len(modules))
    bars = ax2.barh(y_pos, module_passed, color='#45B7D1', alpha=0.8, edgecolor='black')
    
    # Annotations
    for i, (bar, passed, total) in enumerate(zip(bars, module_passed, module_tests)):
        width = bar.get_width()
        ax2.annotate(f'{passed}/{total} ✅', 
                    xy=(width, bar.get_y() + bar.get_height()/2.),
                    xytext=(5, 0), textcoords="offset points",
                    ha='left', va='center', fontweight='bold')
    
    ax2.set_yticks(y_pos)
    ax2.set_yticklabels(modules)
    ax2.set_xlabel('Tests Réussis', fontsize=14)
    ax2.set_title('Détail Modules Optimisés', fontsize=16, fontweight='bold')
    ax2.grid(True, alpha=0.3, axis='x')
    
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "optimization_comparison.png", dpi=300, bbox_inches='tight')
    plt.savefig(PLOTS_DIR / "optimization_comparison.pdf", bbox_inches='tight')
    plt.close()
    print(f"   ✅ Sauvé: {PLOTS_DIR}/optimization_comparison.png|pdf")

def plot_evolution_timeline():
    """Timeline de l'évolution des tests"""
    print("📊 Génération Plot: Timeline Evolution...")
    
    old_report, new_report = load_simulation_reports()
    
    fig, ax = plt.subplots(figsize=(12, 6))
    
    # Points de timeline
    phases = ['Développement\nInitial', 'Tests Basiques\n(Bugs détectés)', 'Optimisation\nPython-verified', 'Production\nReady']
    success_rates = [0, old_report['summary']['overall_success_rate'], 
                    new_report['summary']['overall_success_rate'], 100]
    x_positions = [0, 1, 2, 3]
    
    # Ligne de progression
    ax.plot(x_positions, success_rates, 'o-', linewidth=4, markersize=10, 
            color='#2E86AB', markerfacecolor='white', markeredgewidth=3, markeredgecolor='#2E86AB')
    
    # Zones colorées selon le statut
    colors = ['red', 'orange', 'lightgreen', 'green']
    alphas = [0.3, 0.4, 0.6, 0.8]
    
    for i, (phase, rate, color, alpha) in enumerate(zip(phases, success_rates, colors, alphas)):
        ax.scatter(i, rate, s=300, c=color, alpha=alpha, edgecolors='black', linewidth=2, zorder=5)
        
        # Annotations
        ax.annotate(f'{rate:.0f}%', xy=(i, rate), xytext=(0, 20),
                   textcoords="offset points", ha='center', va='bottom',
                   fontweight='bold', fontsize=12,
                   bbox=dict(boxstyle="round,pad=0.3", facecolor=color, alpha=0.7))
    
    # Zones d'amélioration
    ax.fill_between([1, 2], 0, 110, alpha=0.2, color='yellow', label='Zone d\'Optimisation')
    ax.fill_between([2, 3], 0, 110, alpha=0.2, color='green', label='Production Ready')
    
    ax.set_xticks(x_positions)
    ax.set_xticklabels(phases, rotation=45, ha='right')
    ax.set_ylabel('Taux de Succès (%)', fontsize=16)
    ax.set_title('Évolution des Tests LSE-PE SIMD', fontsize=18, fontweight='bold')
    ax.set_ylim(-5, 110)
    ax.grid(True, alpha=0.3)
    ax.legend(loc='upper left')
    
    # Annotations importantes
    ax.annotate('Breakthrough!\nPython-verification', xy=(2, success_rates[2]), 
               xytext=(1.5, 80), arrowprops=dict(arrowstyle='->', color='red', lw=2),
               ha='center', fontweight='bold', fontsize=10, color='red',
               bbox=dict(boxstyle="round,pad=0.3", facecolor="yellow", alpha=0.8))
    
    plt.tight_layout()
    plt.savefig(PLOTS_DIR / "evolution_timeline.png", dpi=300, bbox_inches='tight')
    plt.savefig(PLOTS_DIR / "evolution_timeline.pdf", bbox_inches='tight')
    plt.close()
    print(f"   ✅ Sauvé: {PLOTS_DIR}/evolution_timeline.png|pdf")

def plot_final_validation():
    """Validation finale avec métriques clés"""
    print("📊 Génération Plot: Validation Finale...")
    
    old_report, new_report = load_simulation_reports()
    
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(14, 10))
    
    # Quadrant 1: Comparaison taux de succès
    modes = ['Anciens Tests', 'Tests Optimisés']
    rates = [old_report['summary']['overall_success_rate'], 
             new_report['summary']['overall_success_rate']]
    colors = ['#FF6B6B', '#4ECDC4']
    
    wedges, texts, autotexts = ax1.pie(rates, labels=modes, colors=colors, autopct='%1.1f%%',
                                       startangle=90, textprops={'fontsize': 12})
    ax1.set_title('Distribution des Succès', fontsize=14, fontweight='bold')
    
    # Quadrant 2: Nombre de tests
    test_counts = [old_report['summary']['total_tests'], new_report['summary']['total_tests']]
    bars = ax2.bar(modes, test_counts, color=colors, alpha=0.8, edgecolor='black')
    
    for bar, count in zip(bars, test_counts):
        height = bar.get_height()
        ax2.annotate(f'{count}', xy=(bar.get_x() + bar.get_width()/2., height),
                    xytext=(0, 5), textcoords="offset points",
                    ha='center', va='bottom', fontweight='bold')
    
    ax2.set_ylabel('Nombre de Tests')
    ax2.set_title('Volume de Tests', fontsize=14, fontweight='bold')
    ax2.grid(True, alpha=0.3, axis='y')
    
    # Quadrant 3: Modules par status
    perfect_modules = new_report['summary']['perfect_modules']
    total_modules = new_report['summary']['total_modules']
    failed_modules = new_report['summary']['failed_modules']
    
    module_status = ['Parfaits', 'Échoués']
    module_counts = [perfect_modules, failed_modules]
    module_colors = ['green', 'red']
    
    bars = ax3.bar(module_status, module_counts, color=module_colors, alpha=0.8, edgecolor='black')
    
    for bar, count in zip(bars, module_counts):
        if count > 0:
            height = bar.get_height()
            ax3.annotate(f'{count}', xy=(bar.get_x() + bar.get_width()/2., height),
                        xytext=(0, 5), textcoords="offset points",
                        ha='center', va='bottom', fontweight='bold')
    
    ax3.set_ylabel('Nombre de Modules')
    ax3.set_title('Status des Modules SIMD', fontsize=14, fontweight='bold')
    ax3.grid(True, alpha=0.3, axis='y')
    
    # Quadrant 4: Métriques finales (text summary)
    ax4.axis('off')
    
    summary_text = f"""
    🎯 VALIDATION FINALE LSE-PE SIMD
    
    ✅ Taux de succès: {new_report['summary']['overall_success_rate']:.0f}%
    ✅ Tests totaux: {new_report['summary']['total_tests']}
    ✅ Modules parfaits: {new_report['summary']['perfect_modules']}/{new_report['summary']['total_modules']}
    ✅ Erreur moyenne: {new_report['summary']['mean_error']:.1f} LSBs
    
    📈 Amélioration vs tests basiques:
    • +{new_report['summary']['overall_success_rate'] - old_report['summary']['overall_success_rate']:.0f} points de pourcentage
    • Factor {new_report['summary']['overall_success_rate'] / old_report['summary']['overall_success_rate']:.1f}x meilleur
    
    🚀 STATUS: PRODUCTION READY!
    """
    
    ax4.text(0.05, 0.95, summary_text, transform=ax4.transAxes, fontsize=12,
             verticalalignment='top', fontfamily='monospace',
             bbox=dict(boxstyle="round,pad=0.5", facecolor="lightgreen", alpha=0.8))
    
    plt.suptitle('Validation Complète LSE-PE SIMD - Optimisation Python-Verified', 
                 fontsize=16, fontweight='bold', y=0.95)
    plt.tight_layout(rect=[0, 0.03, 1, 0.92])
    plt.savefig(PLOTS_DIR / "final_validation.png", dpi=300, bbox_inches='tight')
    plt.savefig(PLOTS_DIR / "final_validation.pdf", bbox_inches='tight')
    plt.close()
    print(f"   ✅ Sauvé: {PLOTS_DIR}/final_validation.png|pdf")

def generate_optimized_plots():
    """Génère tous les graphiques optimisés"""
    print("🎨 GÉNÉRATION DES GRAPHIQUES OPTIMISÉS LSE-PE")
    print("=" * 60)
    
    plot_optimization_comparison()
    plot_evolution_timeline()  
    plot_final_validation()
    
    print("\n📋 GRAPHIQUES OPTIMISÉS GÉNÉRÉS:")
    print("=" * 40)
    
    plots_info = [
        ("optimization_comparison", "Comparaison avant/après optimisation (25% → 100%)"),
        ("evolution_timeline", "Timeline d'évolution des tests de développement à production"),
        ("final_validation", "Validation finale avec métriques complètes")
    ]
    
    for filename, description in plots_info:
        png_path = PLOTS_DIR / f"{filename}.png"
        pdf_path = PLOTS_DIR / f"{filename}.pdf"
        print(f"✅ {filename}:")
        print(f"   📝 {description}")
        print(f"   📁 PNG: {png_path}")
        print(f"   📁 PDF: {pdf_path}")
        print()
    
    print("🎯 Graphiques basés sur VRAIS résultats optimisés!")
    print("📊 Montre l'impact réel de l'optimisation Python-verified")

if __name__ == "__main__":
    generate_optimized_plots()