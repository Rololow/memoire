#!/usr/bin/env python3
"""
=============================================================================
Script de Test Unifié LSE - Tous les Modules
Description: Compile et exécute tous les testbenches LSE avec ModelSim/QuestaSim
Author: LSE-PE Project
Date: October 2025
=============================================================================
"""

import subprocess
import sys
import json
import re
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import argparse

# Configuration
PROJECT_ROOT = Path(__file__).parent.parent
MODULES_DIR = PROJECT_ROOT / "modules"
TESTBENCH_DIR = PROJECT_ROOT / "testbenches"
OUTPUT_DIR = PROJECT_ROOT / "simulation_output"
WORK_DIR = PROJECT_ROOT / "work"
REPORTS_DIR = PROJECT_ROOT.parent / "présentations" / "présentation 1"

# Chemin direct vers ModelSim (Intel FPGA Starter Edition 20.1)
MODELSIM_BIN = r"C:\intelFPGA\20.1\modelsim_ase\win32aloem"

VLIB_CMD = os.path.join(MODELSIM_BIN, "vlib.exe")
VLOG_CMD = os.path.join(MODELSIM_BIN, "vlog.exe")
VSIM_CMD = os.path.join(MODELSIM_BIN, "vsim.exe")

# Définition des configurations de test
TEST_CONFIGS = {
    "lse_add": {
        "name": "LSE Add (Algorithm 1 Implementation)",
        "testbench": "tb_lse_add_unified",
        "sources": [
            MODULES_DIR / "core" / "lse_add.sv",
            TESTBENCH_DIR / "core" / "tb_lse_add_unified.sv"
        ],
        "description": "Addition LSE avec implémentation Algorithm 1 (LSE-PE NeurIPS 2024)"
    },
    "lse_mult": {
        "name": "LSE Mult (Core)",
        "testbench": "tb_lse_mult_unified",
        "sources": [
            MODULES_DIR / "core" / "lse_mult.sv",
            TESTBENCH_DIR / "core" / "tb_lse_mult_unified.sv"
        ],
        "description": "Multiplication log-space"
    },
    "lse_acc": {
        "name": "LSE Accumulator (Core)",
        "testbench": "tb_lse_acc_unified",
        "sources": [
            MODULES_DIR / "core" / "lse_acc.sv",
            TESTBENCH_DIR / "core" / "tb_lse_acc_unified.sv"
        ],
        "description": "Accumulation LSE 16-bit"
    },
    "register": {
        "name": "Register (Core)",
        "testbench": "tb_register_unified",
        "sources": [
            MODULES_DIR / "core" / "register.sv",
            TESTBENCH_DIR / "core" / "tb_register_unified.sv"
        ],
        "description": "Registre pipeline générique"
    },
    "lse_shared_system": {
        "name": "LSE Shared System",
        "testbench": "tb_lse_shared_system",
        "sources": [
            # Modules de base (ordre important pour les dépendances)
            MODULES_DIR / "core" / "register.sv",
            MODULES_DIR / "core" / "lse_add.sv",
            MODULES_DIR / "core" / "lse_mult.sv",  # Utilisé par lse_pe_with_mux
            MODULES_DIR / "core" / "lse_acc.sv",   # Utilisé par lse_pe_with_mux
            MODULES_DIR / "lut" / "lse_clut_shared.sv",
            MODULES_DIR / "core" / "lse_pe_with_mux.sv",
            MODULES_DIR / "core" / "lse_log_mac.sv",
            MODULES_DIR / "lse_shared_system.sv",
            # Testbench en dernier
            TESTBENCH_DIR / "tb_lse_shared_system.sv"
        ],
        "description": "Système complet avec 4 MACs et CLUT partagée"
    }
}


class Colors:
    """Codes ANSI pour les couleurs dans le terminal"""
    RESET = '\033[0m'
    BOLD = '\033[1m'
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    GRAY = '\033[90m'


def print_header(text: str, color: str = Colors.CYAN):
    """Affiche un en-tête formaté"""
    separator = "=" * 78
    print(f"\n{color}{separator}")
    print(f"{text.center(78)}")
    print(f"{separator}{Colors.RESET}\n")


def print_section(text: str, color: str = Colors.YELLOW):
    """Affiche une section formatée"""
    separator = "-" * 78
    print(f"\n{color}{separator}")
    print(f" {text}")
    print(f"{separator}{Colors.RESET}")


def print_status(status: str, message: str):
    """Affiche un message de statut avec icône"""
    # Utiliser des caractères ASCII pour compatibilité Windows PowerShell
    icons = {
        "info": "[i]",
        "success": "[OK]",
        "warning": "[!]",
        "error": "[X]",
        "running": "[~]"
    }
    colors = {
        "info": Colors.BLUE,
        "success": Colors.GREEN,
        "warning": Colors.YELLOW,
        "error": Colors.RED,
        "running": Colors.CYAN
    }
    
    icon = icons.get(status, "[-]")
    color = colors.get(status, Colors.WHITE)
    print(f"{color}{icon} {message}{Colors.RESET}")


def check_modelsim() -> Tuple[bool, Optional[str], Optional[str], Optional[str]]:
    """Vérifie si ModelSim est disponible au chemin configuré ou dans PATH
    
    Returns:
        Tuple[bool, vlib_cmd, vlog_cmd, vsim_cmd]
    """
    # Vérifier au chemin configuré
    if Path(VLIB_CMD).exists() and Path(VLOG_CMD).exists() and Path(VSIM_CMD).exists():
        return True, VLIB_CMD, VLOG_CMD, VSIM_CMD
    
    # Sinon, vérifier dans le PATH système
    try:
        subprocess.run(["vsim", "-version"], capture_output=True, check=False)
        # Si vsim est dans le PATH, utiliser les commandes directement
        return True, "vlib", "vlog", "vsim"
    except FileNotFoundError:
        return False, None, None, None


def setup_environment(clean: bool = False):
    """Configure l'environnement de simulation"""
    print_status("running", "Configuration de l'environnement...")
    
    # Créer les répertoires nécessaires
    OUTPUT_DIR.mkdir(exist_ok=True)
    WORK_DIR.mkdir(exist_ok=True)
    
    # Nettoyer si demandé
    if clean:
        print_status("info", "Nettoyage des fichiers de simulation...")
        if WORK_DIR.exists():
            import shutil
            shutil.rmtree(WORK_DIR)
            WORK_DIR.mkdir()
        
        for wlf_file in OUTPUT_DIR.glob("*.wlf"):
            wlf_file.unlink()
    
    print_status("success", "Environnement configuré")


def update_clut_values():
    """Met à jour les valeurs CLUT si le script existe"""
    clut_script = PROJECT_ROOT / "scripts" / "python" / "generate_clut_values.py"
    
    if not clut_script.exists():
        print_status("warning", "Script CLUT non trouvé, continue sans mise à jour")
        return True
    
    print_status("running", "Mise à jour des valeurs CLUT...")
    
    try:
        result = subprocess.run(
            [sys.executable, str(clut_script)],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',
            timeout=30
        )
        
        if result.returncode == 0:
            print_status("success", "Valeurs CLUT mises à jour")
            return True
        else:
            print_status("warning", f"Mise à jour CLUT échouée: {result.stderr}")
            return True  # Continue quand même
            
    except Exception as e:
        print_status("warning", f"Erreur mise à jour CLUT: {e}")
        return True  # Continue quand même


def compile_sources(sources: List[Path], vlib_cmd: str, vlog_cmd: str, verbose: bool = False) -> bool:
    """Compile les fichiers sources SystemVerilog"""
    
    # Créer la librairie work si nécessaire
    if not (WORK_DIR / "_info").exists():
        print_status("running", "Création de la librairie work...")
        result = subprocess.run(
            [vlib_cmd, "work"],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace'
        )
        if result.returncode != 0:
            print_status("error", f"Échec création work: {result.stderr}")
            return False
    
    # Compiler chaque fichier
    print_status("running", "Compilation des sources SystemVerilog...")
    
    for source in sources:
        if not source.exists():
            print_status("error", f"Fichier non trouvé: {source}")
            return False
        
        if verbose:
            print(f"  {Colors.GRAY}Compilation: {source.name}{Colors.RESET}")
        
        cmd = [
            vlog_cmd,
            "-sv",
            "+define+DEBUG_SYSTEM",
            # "+define+ASSERTIONS_ON",  # Désactivé pour ModelSim Starter Edition (pas de covergroup)
            str(source)
        ]
        
        result = subprocess.run(
            cmd,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace'
        )
        
        if result.returncode != 0:
            print_status("error", f"Échec compilation: {source.name}")
            # Toujours afficher l'erreur de compilation (même sans verbose)
            print(f"{Colors.RED}=== Sortie complète de vlog ==={Colors.RESET}")
            if result.stdout:
                print(f"{Colors.YELLOW}STDOUT:{Colors.RESET}")
                print(result.stdout)
            if result.stderr:
                print(f"{Colors.RED}STDERR:{Colors.RESET}")
                print(result.stderr)
            print(f"{Colors.RED}Code de retour: {result.returncode}{Colors.RESET}")
            return False
        
        if verbose:
            print(f"  {Colors.GREEN}[OK] {source.name}{Colors.RESET}")
    
    print_status("success", f"Compilation réussie ({len(sources)} fichiers)")
    return True


def run_simulation(testbench: str, vsim_cmd: str, verbose: bool = False) -> Tuple[bool, str]:
    """Exécute une simulation avec vsim"""
    print_status("running", f"Exécution de la simulation: {testbench}")
    
    cmd = [
        vsim_cmd,
        "-c",  # Mode console
        "-t", "1ps",
        "-voptargs=+acc",
        "+notimingchecks",
        testbench,
        "-do", "run -all; quit -f"
    ]
    
    try:
        result = subprocess.run(
            cmd,
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            encoding='utf-8',
            errors='replace',  # Remplacer les caractères invalides au lieu de crasher
            timeout=300  # 5 minutes max
        )
        
        output = result.stdout + result.stderr
        
        if verbose:
            print(f"\n{Colors.GRAY}{'='*78}")
            print("Sortie simulation:")
            print(f"{'='*78}{Colors.RESET}")
            print(output)
        
        return (result.returncode == 0 or "# Errors: 0" in output), output
        
    except subprocess.TimeoutExpired:
        print_status("error", "Simulation timeout (>5 minutes)")
        return False, "Timeout"
    except Exception as e:
        print_status("error", f"Erreur simulation: {e}")
        return False, str(e)


def parse_test_results(output: str) -> Dict:
    """Parse la sortie de simulation pour extraire les résultats"""
    result = {
        "status": "UNKNOWN",
        "total_tests": 0,
        "passed_tests": 0,
        "failed_tests": 0,
        "success_rate": 0.0,
        "details": []
    }
    
    # Chercher le nombre total de tests
    total_match = re.search(r'Total Tests:\s*(\d+)', output)
    if total_match:
        result["total_tests"] = int(total_match.group(1))
    
    # Chercher les tests réussis
    passed_match = re.search(r'Passed:\s*(\d+)', output)
    if passed_match:
        result["passed_tests"] = int(passed_match.group(1))
    
    # Chercher les tests échoués
    failed_match = re.search(r'Failed:\s*(\d+)', output)
    if failed_match:
        result["failed_tests"] = int(failed_match.group(1))
    
    # Calculer le taux de succès
    if result["total_tests"] > 0:
        result["success_rate"] = (result["passed_tests"] / result["total_tests"]) * 100
        
        if result["passed_tests"] == result["total_tests"]:
            result["status"] = "PASS"
        elif result["passed_tests"] > 0:
            result["status"] = "PARTIAL"
        else:
            result["status"] = "FAIL"
    
    # Chercher les messages spécifiques
    if "ALL TESTS PASSED" in output:
        result["status"] = "PASS"
    elif "SOME TESTS FAILED" in output and result["status"] == "UNKNOWN":
        result["status"] = "PARTIAL"
    
    # Extraire les détails des tests individuels
    for line in output.split('\n'):
        if 'PASS' in line or 'FAIL' in line:
            # Nettoyer et extraire l'info pertinente
            cleaned = re.sub(r'#\s*\d+', '', line).strip()
            if cleaned and len(cleaned) < 200:  # Éviter les lignes trop longues
                result["details"].append(cleaned)
    
    return result


def run_test_module(module_id: str, config: Dict, vlib_cmd: str, vlog_cmd: str, vsim_cmd: str, verbose: bool = False) -> Dict:
    """Exécute les tests pour un module spécifique"""
    print_section(f"Test: {config['name']}", Colors.YELLOW)
    print(f"{Colors.GRAY}{config['description']}{Colors.RESET}\n")
    
    start_time = datetime.now()
    
    # Compilation
    if not compile_sources(config["sources"], vlib_cmd, vlog_cmd, verbose):
        return {
            "module_id": module_id,
            "name": config["name"],
            "status": "ERROR",
            "error": "Compilation failed",
            "duration": 0
        }
    
    # Simulation
    success, output = run_simulation(config["testbench"], vsim_cmd, verbose)
    
    if not success:
        return {
            "module_id": module_id,
            "name": config["name"],
            "status": "ERROR",
            "error": "Simulation failed",
            "duration": (datetime.now() - start_time).total_seconds()
        }
    
    # Parser les résultats
    results = parse_test_results(output)
    duration = (datetime.now() - start_time).total_seconds()
    
    # Afficher les résultats
    status_colors = {
        "PASS": Colors.GREEN,
        "PARTIAL": Colors.YELLOW,
        "FAIL": Colors.RED,
        "UNKNOWN": Colors.GRAY
    }
    
    status_icons = {
        "PASS": "[+]",
        "PARTIAL": "[!]",
        "FAIL": "[X]",
        "UNKNOWN": "❓"
    }
    
    color = status_colors.get(results["status"], Colors.GRAY)
    icon = status_icons.get(results["status"], "[-]")
    
    print(f"\n{color}{icon} Statut: {results['status']}{Colors.RESET}")
    print(f"  Tests: {results['passed_tests']}/{results['total_tests']} "
          f"({results['success_rate']:.1f}%)")
    print(f"  Durée: {duration:.2f}s")
    
    # Afficher quelques détails si demandé
    if verbose and results["details"]:
        print(f"\n  Détails (premiers 5):")
        for detail in results["details"][:5]:
            print(f"    {Colors.GRAY}{detail}{Colors.RESET}")
        if len(results["details"]) > 5:
            print(f"    {Colors.GRAY}... et {len(results['details']) - 5} autres{Colors.RESET}")
    
    return {
        "module_id": module_id,
        "name": config["name"],
        "description": config["description"],
        "status": results["status"],
        "total_tests": results["total_tests"],
        "passed_tests": results["passed_tests"],
        "failed_tests": results["failed_tests"],
        "success_rate": results["success_rate"],
        "duration": duration,
        "details": results["details"][:10]  # Garder seulement les 10 premiers
    }


def generate_summary_report(all_results: List[Dict], output_file: Optional[Path] = None):
    """Génère un rapport résumé des tests"""
    
    # Calculer les statistiques globales
    total_modules = len(all_results)
    passed_modules = sum(1 for r in all_results if r["status"] == "PASS")
    partial_modules = sum(1 for r in all_results if r["status"] == "PARTIAL")
    failed_modules = sum(1 for r in all_results if r["status"] in ["FAIL", "ERROR"])
    
    total_tests = sum(r.get("total_tests", 0) for r in all_results)
    total_passed = sum(r.get("passed_tests", 0) for r in all_results)
    total_failed = sum(r.get("failed_tests", 0) for r in all_results)
    
    global_success_rate = (total_passed / total_tests * 100) if total_tests > 0 else 0
    total_duration = sum(r.get("duration", 0) for r in all_results)
    
    # Afficher le résumé
    print_header("RÉSUMÉ GLOBAL DES TESTS", Colors.CYAN)
    
    print(f"{Colors.BOLD}Statistiques Modules:{Colors.RESET}")
    print(f"  Total modules testés: {total_modules}")
    print(f"  {Colors.GREEN}[OK] Modules parfaits:   {passed_modules}{Colors.RESET}")
    print(f"  {Colors.YELLOW}⚠ Modules partiels:   {partial_modules}{Colors.RESET}")
    print(f"  {Colors.RED}[ER] Modules échoués:    {failed_modules}{Colors.RESET}")
    
    print(f"\n{Colors.BOLD}Statistiques Tests:{Colors.RESET}")
    print(f"  Total tests:          {total_tests}")
    print(f"  {Colors.GREEN}Tests réussis:        {total_passed}{Colors.RESET}")
    print(f"  {Colors.RED}Tests échoués:        {total_failed}{Colors.RESET}")
    
    # Couleur du taux de succès global
    if global_success_rate >= 90:
        rate_color = Colors.GREEN
    elif global_success_rate >= 70:
        rate_color = Colors.YELLOW
    else:
        rate_color = Colors.RED
    
    print(f"  {rate_color}Taux de succès:       {global_success_rate:.1f}%{Colors.RESET}")
    print(f"  Durée totale:         {total_duration:.1f}s")
    
    # Résultats par module
    print(f"\n{Colors.BOLD}Résultats par Module:{Colors.RESET}")
    for result in all_results:
        status_icons = {
            "PASS": f"{Colors.GREEN}[OK]{Colors.RESET}",
            "PARTIAL": f"{Colors.YELLOW}⚠{Colors.RESET}",
            "FAIL": f"{Colors.RED}[ER]{Colors.RESET}",
            "ERROR": f"{Colors.RED}[ER]{Colors.RESET}",
            "UNKNOWN": f"{Colors.GRAY}?{Colors.RESET}"
        }
        
        icon = status_icons.get(result["status"], "[-]")
        tests_info = f"{result.get('passed_tests', 0)}/{result.get('total_tests', 0)}"
        rate = result.get('success_rate', 0)
        
        print(f"  {icon} {result['name']:30} {tests_info:>10} ({rate:>5.1f}%)")
    
    # Analyse et recommandations
    print(f"\n{Colors.BOLD}Analyse:{Colors.RESET}")
    
    if failed_modules == 0 and partial_modules == 0:
        print(f"  {Colors.GREEN}[OK] Excellent ! Tous les modules fonctionnent parfaitement.{Colors.RESET}")
        print(f"  {Colors.GREEN}[OK] Le système LSE est production-ready.{Colors.RESET}")
    elif global_success_rate >= 90:
        print(f"  {Colors.GREEN}[OK] Très bon niveau de fonctionnalité ({global_success_rate:.0f}%).{Colors.RESET}")
        if partial_modules > 0:
            print(f"  {Colors.YELLOW}⚠ {partial_modules} module(s) nécessitent des ajustements mineurs.{Colors.RESET}")
    elif global_success_rate >= 70:
        print(f"  {Colors.YELLOW}⚠ Bon niveau mais améliorations nécessaires ({global_success_rate:.0f}%).{Colors.RESET}")
        print(f"  {Colors.YELLOW}⚠ Focus sur les modules partiellement fonctionnels.{Colors.RESET}")
    else:
        print(f"  {Colors.RED}[ER] Problèmes significatifs détectés ({global_success_rate:.0f}%).{Colors.RESET}")
        print(f"  {Colors.RED}[ER] Révision approfondie nécessaire.{Colors.RESET}")
    
    # Modules nécessitant attention
    problem_modules = [r for r in all_results if r["status"] in ["PARTIAL", "FAIL", "ERROR"]]
    if problem_modules:
        print(f"\n{Colors.BOLD}Modules nécessitant attention:{Colors.RESET}")
        for result in problem_modules:
            rate = result.get('success_rate', 0)
            print(f"  {Colors.YELLOW}[-] {result['name']}: {rate:.1f}% de réussite{Colors.RESET}")
    
    # Sauvegarder le rapport JSON si demandé
    if output_file:
        report = {
            "timestamp": datetime.now().isoformat(),
            "summary": {
                "total_modules": total_modules,
                "passed_modules": passed_modules,
                "partial_modules": partial_modules,
                "failed_modules": failed_modules,
                "total_tests": total_tests,
                "total_passed": total_passed,
                "total_failed": total_failed,
                "global_success_rate": global_success_rate,
                "total_duration": total_duration
            },
            "modules": all_results
        }
        
        output_file.parent.mkdir(parents=True, exist_ok=True)
        with open(output_file, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\n{Colors.BLUE}ℹ️  Rapport JSON sauvé: {output_file}{Colors.RESET}")


def main():
    """Fonction principale"""
    parser = argparse.ArgumentParser(
        description="Script unifié de test pour les modules LSE-PE",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:
  python run_lse_tests.py                    # Teste tous les modules
  python run_lse_tests.py -m lse_add         # Teste seulement LSE Add
  python run_lse_tests.py -m lse_add lse_mult  # Teste Add et Mult
  python run_lse_tests.py -v                 # Mode verbose
  python run_lse_tests.py --clean            # Nettoie avant de tester
  python run_lse_tests.py --report report.json  # Sauvegarde rapport JSON
        """
    )
    
    parser.add_argument(
        '-m', '--modules',
        nargs='+',
        choices=list(TEST_CONFIGS.keys()) + ['all'],
        default=['all'],
        help='Modules à tester (par défaut: tous)'
    )
    
    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Mode verbose avec sortie détaillée'
    )
    
    parser.add_argument(
        '--clean',
        action='store_true',
        help='Nettoie les fichiers de simulation avant de commencer'
    )
    
    parser.add_argument(
        '--report',
        type=Path,
        help='Chemin du fichier rapport JSON (optionnel)'
    )
    
    parser.add_argument(
        '--no-clut-update',
        action='store_true',
        help='Ne pas mettre à jour les valeurs CLUT'
    )
    
    args = parser.parse_args()
    
    # Vérifier que ModelSim est disponible
    modelsim_found, vlib_cmd, vlog_cmd, vsim_cmd = check_modelsim()
    if not modelsim_found:
        print_status("error", f"ModelSim non trouvé à l'emplacement configuré: {MODELSIM_BIN}")
        print(f"\n{Colors.BLUE}Solution:{Colors.RESET}")
        print(f"  1. Ajoutez ModelSim au PATH système, ou")
        print(f"  2. Modifiez la variable MODELSIM_BIN dans le script:")
        print(f"     MODELSIM_BIN = r\"C:\\chemin\\vers\\votre\\modelsim\\win32aloem\"\n")
        return 1
    
    if vlib_cmd == "vlib":
        print_status("success", "ModelSim détecté dans PATH système")
    else:
        print_status("success", f"ModelSim détecté: {MODELSIM_BIN}")
    
    # Header
    print_header("LSE-PE TEST SUITE - Validation Complète", Colors.CYAN)
    print(f"{Colors.GRAY}Projet: {PROJECT_ROOT.name}{Colors.RESET}")
    print(f"{Colors.GRAY}Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}{Colors.RESET}")
    
    # Setup
    setup_environment(clean=args.clean)
    
    # Mise à jour CLUT
    if not args.no_clut_update:
        update_clut_values()
    
    # Déterminer les modules à tester
    if 'all' in args.modules:
        modules_to_test = list(TEST_CONFIGS.keys())
    else:
        modules_to_test = args.modules
    
    print_status("info", f"Modules à tester: {len(modules_to_test)}")
    for module_id in modules_to_test:
        print(f"  [-] {TEST_CONFIGS[module_id]['name']}")
    
    # Exécuter les tests
    all_results = []
    
    for module_id in modules_to_test:
        config = TEST_CONFIGS[module_id]
        result = run_test_module(module_id, config, vlib_cmd, vlog_cmd, vsim_cmd, verbose=args.verbose)
        all_results.append(result)
    
    # Générer le rapport
    report_file = args.report if args.report else (REPORTS_DIR / "lse_test_report.json")
    generate_summary_report(all_results, report_file)
    
    # Code de sortie basé sur les résultats
    failed_count = sum(1 for r in all_results if r["status"] in ["FAIL", "ERROR"])
    
    print()  # Ligne vide finale
    
    return 0 if failed_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
