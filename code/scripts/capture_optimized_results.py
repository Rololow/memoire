#!/usr/bin/env python3
"""
Script pour capturer et analyser les résultats optimisés
du script test_simd_optimized.ps1
"""

import subprocess
import json
import re
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).parent.parent
WORK_DIR = PROJECT_ROOT / "work" 
REPORTS_DIR = PROJECT_ROOT.parent / "présentations" / "présentation 1"

def run_optimized_tests_and_capture():
    """Execute le script PowerShell et capture les résultats"""
    print("🚀 Exécution des tests SIMD optimisés...")
    
    try:
        # Exécuter le script PowerShell
        result = subprocess.run([
            "powershell.exe", 
            "-ExecutionPolicy", "Bypass",
            "-File", str(PROJECT_ROOT / "scripts" / "test_simd_optimized.ps1")
        ], capture_output=True, text=True, cwd=PROJECT_ROOT)
        
        if result.returncode != 0:
            print(f"❌ Erreur PowerShell: {result.stderr}")
            return None
            
        output = result.stdout
        print("✅ Tests exécutés avec succès!")
        
        return parse_powershell_output(output)
        
    except Exception as e:
        print(f"❌ Erreur d'exécution: {e}")
        return None

def parse_powershell_output(output):
    """Parse la sortie du script PowerShell pour extraire les métriques"""
    
    # Chercher les informations de résumé
    modules_match = re.search(r'Optimized Modules:\s*(\d+)', output)
    perfect_match = re.search(r'Perfect Modules:\s*(\d+)', output)
    failed_match = re.search(r'Failed Modules:\s*(\d+)', output)
    
    tests_match = re.search(r'Optimized Tests:\s*(\d+) total', output)
    passed_match = re.search(r'Tests Passed:\s*(\d+)', output)
    failed_tests_match = re.search(r'Tests Failed:\s*(\d+)', output)
    rate_match = re.search(r'Optimized Rate:\s*([\d.]+)%', output)
    
    # Extraire les résultats détaillés par module
    module_results = {}
    detail_lines = output.split('\n')
    
    for line in detail_lines:
        if '🎯 PERFECT' in line or '⚠️ PARTIAL' in line or '❌ FAILED' in line:
            # Exemple: "  SIMD 2×12b: 🎯 PERFECT (22/22)"
            match = re.search(r'(\w+\s*[×x]?\d*\w*):.*?\((\d+)/(\d+)\)', line)
            if match:
                module_name = match.group(1).strip()
                passed = int(match.group(2))
                total = int(match.group(3))
                status = "perfect" if "🎯 PERFECT" in line else ("partial" if "⚠️ PARTIAL" in line else "failed")
                
                module_results[module_name] = {
                    "total_tests": total,
                    "passed_tests": passed,
                    "failed_tests": total - passed,
                    "success_rate": (passed / total * 100) if total > 0 else 0,
                    "status": status
                }
    
    # Construire le rapport
    optimized_report = {
        "timestamp": datetime.now().isoformat(),
        "source": "test_simd_optimized.ps1",
        "type": "optimized_python_verified",
        "modules_tested": list(module_results.keys()),
        "summary": {
            "total_modules": int(modules_match.group(1)) if modules_match else 0,
            "perfect_modules": int(perfect_match.group(1)) if perfect_match else 0,
            "failed_modules": int(failed_match.group(1)) if failed_match else 0,
            "total_tests": int(tests_match.group(1)) if tests_match else 0,
            "total_passed": int(passed_match.group(1)) if passed_match else 0,
            "total_failed": int(failed_tests_match.group(1)) if failed_tests_match else 0,
            "overall_success_rate": float(rate_match.group(1)) if rate_match else 0.0
        },
        "detailed_results": module_results,
        "raw_output": output
    }
    
    return optimized_report

def compare_reports():
    """Compare les anciens et nouveaux résultats"""
    
    # Charger l'ancien rapport
    old_report_path = REPORTS_DIR / "verilog_simulation_report.json"
    if old_report_path.exists():
        with open(old_report_path, 'r') as f:
            old_report = json.load(f)
    else:
        old_report = None
    
    # Générer nouveau rapport
    new_report = run_optimized_tests_and_capture()
    
    if not new_report:
        print("❌ Impossible de générer le nouveau rapport")
        return
    
    # Sauvegarder le nouveau rapport  
    new_report_path = REPORTS_DIR / "optimized_simulation_report.json"
    with open(new_report_path, 'w') as f:
        json.dump(new_report, f, indent=2)
    
    print(f"\n📊 COMPARAISON DES RÉSULTATS")
    print("=" * 50)
    
    if old_report:
        print("📜 ANCIENS TESTS (Basiques):")
        print(f"   Tests totaux: {old_report['summary']['total_tests']}")
        print(f"   Tests réussis: {old_report['summary']['total_passed']}")  
        print(f"   Taux de succès: {old_report['summary']['overall_success_rate']:.1f}%")
        print(f"   Erreur moyenne: {old_report['summary']['mean_error']:.0f} LSBs")
    
    print(f"\n🚀 NOUVEAUX TESTS (Optimisés Python-verified):")
    print(f"   Modules totaux: {new_report['summary']['total_modules']}")
    print(f"   Modules parfaits: {new_report['summary']['perfect_modules']}")
    print(f"   Tests totaux: {new_report['summary']['total_tests']}")
    print(f"   Tests réussis: {new_report['summary']['total_passed']}")
    print(f"   Taux de succès: {new_report['summary']['overall_success_rate']:.1f}%")
    
    print(f"\n📈 AMÉLIORATION:")
    if old_report:
        improvement = new_report['summary']['overall_success_rate'] - old_report['summary']['overall_success_rate']
        print(f"   Gain de performance: +{improvement:.1f} points de pourcentage")
        print(f"   Factor d'amélioration: {new_report['summary']['overall_success_rate'] / old_report['summary']['overall_success_rate']:.1f}x")
    
    print(f"\n✅ Nouveau rapport sauvé: {new_report_path}")
    
    return new_report

if __name__ == "__main__":
    compare_reports()