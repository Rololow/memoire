#!/usr/bin/env python3
"""
LSE Test Value Generator
Génère les valeurs de test exactes pour les testbenches SystemVerilog
basées sur l'implémentation réelle de la logique LSE adaptive.
"""

def lse_add_adaptive(operand_a, operand_b, width):
    """
    Implémentation Python de la logique LSE adaptive
    Réplique exacte de la logique SystemVerilog dans lse_add_adaptive.sv
    """
    # Constantes adaptatives basées sur la largeur
    NEG_INF_VAL = 1 << (width - 1)  # MSB=1, others=0
    SMALL_CORRECTION = width // 8    # Adaptive correction based on width
    DIFF_THRESHOLD = -(2 ** (width - 4))  # Adaptive threshold
    MAX_VAL = (1 << width) - 1       # Maximum value for the width
    
    # Vérifier les valeurs spéciales (negative infinity)
    if operand_a == NEG_INF_VAL or operand_b == NEG_INF_VAL:
        if operand_a == NEG_INF_VAL and operand_b == NEG_INF_VAL:
            return NEG_INF_VAL  # -inf + (-inf) = -inf
        elif operand_a == NEG_INF_VAL:
            return operand_b    # -inf + x = x
        else:
            return operand_a    # x + (-inf) = x
    
    # Standard LSE addition: log(exp(a) + exp(b))
    # Simple approximation: max(a,b) + log(1 + exp(-|a-b|))
    if operand_a >= operand_b:
        larger = operand_a
        smaller = operand_b
    else:
        larger = operand_b
        smaller = operand_a
    
    # Différence signée (always ≤ 0)
    diff = smaller - larger
    
    # LSE approximation with width-adaptive correction
    if diff > DIFF_THRESHOLD:
        # Significant contribution from smaller value
        threshold = MAX_VAL - SMALL_CORRECTION
        if larger <= threshold:
            result = larger + SMALL_CORRECTION  # Add correction, avoid overflow
        else:
            result = MAX_VAL  # Saturate to maximum value
    else:
        # Very small contribution, ignore smaller value
        result = larger
    
    # Assurer que le résultat reste dans les limites de la largeur
    return result & MAX_VAL


def generate_simd_2x12b_tests():
    """Génère les tests pour le module SIMD 2×12b"""
    print("=== SIMD 2×12b Test Values ===")
    
    test_cases = [
        # Test 1: Basic dual-channel operation
        {"x_ch0": 0x100, "x_ch1": 0x200, "y_ch0": 0x050, "y_ch1": 0x100, "name": "Basic dual-channel LSE"},
        
        # Test 2: Zero inputs
        {"x_ch0": 0x000, "x_ch1": 0x000, "y_ch0": 0x000, "y_ch1": 0x000, "name": "Zero inputs both channels"},
        
        # Test 3: Maximum values
        {"x_ch0": 0xFFF, "x_ch1": 0xFFF, "y_ch0": 0x001, "y_ch1": 0x001, "name": "Maximum value saturation"},
        
        # Test 4: Asymmetric channels
        {"x_ch0": 0x800, "x_ch1": 0x100, "y_ch0": 0x200, "y_ch1": 0x800, "name": "Asymmetric channel values"},
        
        # Tests séquentiels
        {"x_ch0": 0x100, "x_ch1": 0x200, "y_ch0": 0x050, "y_ch1": 0x100, "name": "Sequential test 0"},
        {"x_ch0": 0x110, "x_ch1": 0x220, "y_ch0": 0x058, "y_ch1": 0x110, "name": "Sequential test 1"},
        {"x_ch0": 0x120, "x_ch1": 0x240, "y_ch0": 0x060, "y_ch1": 0x120, "name": "Sequential test 2"},
        {"x_ch0": 0x130, "x_ch1": 0x260, "y_ch0": 0x068, "y_ch1": 0x130, "name": "Sequential test 3"},
    ]
    
    sv_code = []
    
    for i, test in enumerate(test_cases):
        # Calculer les résultats attendus
        exp_ch0 = lse_add_adaptive(test["x_ch0"], test["y_ch0"], 12)
        exp_ch1 = lse_add_adaptive(test["x_ch1"], test["y_ch1"], 12)
        
        print(f"Test {i+1}: {test['name']}")
        print(f"  x_ch0=0x{test['x_ch0']:03X}, y_ch0=0x{test['y_ch0']:03X} → exp_ch0=0x{exp_ch0:03X}")
        print(f"  x_ch1=0x{test['x_ch1']:03X}, y_ch1=0x{test['y_ch1']:03X} → exp_ch1=0x{exp_ch1:03X}")
        
        # Générer le code SystemVerilog
        sv_code.append(f"""        // Test {i+1}: {test['name']}
        apply_test_vector(
            12'h{test['x_ch0']:03X}, 12'h{test['x_ch1']:03X},  // x_ch0, x_ch1
            12'h{test['y_ch0']:03X}, 12'h{test['y_ch1']:03X},  // y_ch0, y_ch1  
            2'b00,             // pe_mode
            12'h{exp_ch0:03X}, 12'h{exp_ch1:03X},  // expected (verified)
            "{test['name']}"
        );""")
    
    print("\n=== SystemVerilog Code for 2×12b Testbench ===")
    for code in sv_code:
        print(code)
    
    return sv_code


def generate_simd_4x6b_tests():
    """Génère les tests pour le module SIMD 4×6b"""
    print("\n=== SIMD 4×6b Test Values ===")
    
    test_cases = [
        # Test 1: Basic quad-channel operation 
        {"x_ch0": 0x05, "x_ch1": 0x0A, "x_ch2": 0x15, "x_ch3": 0x20,
         "y_ch0": 0x03, "y_ch1": 0x08, "y_ch2": 0x12, "y_ch3": 0x18, 
         "name": "Basic quad-channel LSE"},
        
        # Test 2: All zero inputs
        {"x_ch0": 0x00, "x_ch1": 0x00, "x_ch2": 0x00, "x_ch3": 0x00,
         "y_ch0": 0x00, "y_ch1": 0x00, "y_ch2": 0x00, "y_ch3": 0x00,
         "name": "Zero inputs all channels"},
        
        # Test 3: Maximum 6-bit values (63)
        {"x_ch0": 0x3F, "x_ch1": 0x3F, "x_ch2": 0x3F, "x_ch3": 0x3F,
         "y_ch0": 0x01, "y_ch1": 0x01, "y_ch2": 0x01, "y_ch3": 0x01,
         "name": "Maximum 6-bit saturation"},
        
        # Test 4: Channel independence test
        {"x_ch0": 0x10, "x_ch1": 0x20, "x_ch2": 0x30, "x_ch3": 0x08,
         "y_ch0": 0x08, "y_ch1": 0x10, "y_ch2": 0x18, "y_ch3": 0x30,
         "name": "Channel independence test"},
        
        # Test 5: Equal channels
        {"x_ch0": 0x02, "x_ch1": 0x04, "x_ch2": 0x08, "x_ch3": 0x10,
         "y_ch0": 0x02, "y_ch1": 0x04, "y_ch2": 0x08, "y_ch3": 0x10,
         "name": "Equal channels test"},
    ]
    
    sv_code = []
    
    for i, test in enumerate(test_cases):
        # Calculer les résultats attendus
        exp_ch0 = lse_add_adaptive(test["x_ch0"], test["y_ch0"], 6)
        exp_ch1 = lse_add_adaptive(test["x_ch1"], test["y_ch1"], 6)
        exp_ch2 = lse_add_adaptive(test["x_ch2"], test["y_ch2"], 6)
        exp_ch3 = lse_add_adaptive(test["x_ch3"], test["y_ch3"], 6)
        
        print(f"Test {i+1}: {test['name']}")
        print(f"  Ch0: x=0x{test['x_ch0']:02X}, y=0x{test['y_ch0']:02X} → exp=0x{exp_ch0:02X}")
        print(f"  Ch1: x=0x{test['x_ch1']:02X}, y=0x{test['y_ch1']:02X} → exp=0x{exp_ch1:02X}")
        print(f"  Ch2: x=0x{test['x_ch2']:02X}, y=0x{test['y_ch2']:02X} → exp=0x{exp_ch2:02X}")
        print(f"  Ch3: x=0x{test['x_ch3']:02X}, y=0x{test['y_ch3']:02X} → exp=0x{exp_ch3:02X}")
        
        # Générer le code SystemVerilog
        sv_code.append(f"""        // Test {i+1}: {test['name']}
        apply_test_vector(
            6'h{test['x_ch0']:02X}, 6'h{test['x_ch1']:02X}, 6'h{test['x_ch2']:02X}, 6'h{test['x_ch3']:02X},  // x channels
            6'h{test['y_ch0']:02X}, 6'h{test['y_ch1']:02X}, 6'h{test['y_ch2']:02X}, 6'h{test['y_ch3']:02X},  // y channels
            2'b00,                        // pe_mode
            6'h{exp_ch0:02X}, 6'h{exp_ch1:02X}, 6'h{exp_ch2:02X}, 6'h{exp_ch3:02X},  // expected (verified)
            "{test['name']}"
        );""")
    
    print("\n=== SystemVerilog Code for 4×6b Testbench ===")
    for code in sv_code:
        print(code)
    
    return sv_code


def generate_simd_unified_tests():
    """Génère les tests pour le module SIMD unifié"""
    print("\n=== SIMD Unified Test Values ===")
    
    test_cases = [
        # Mode 00: 24-bit
        {"mode": 0x00, "x_in": 0x100050, "y_in": 0x100050, "name": "24-bit mode"},
        
        # Mode 01: 2×12b  
        {"mode": 0x01, "x_in": 0x200100, "y_in": 0x100050, "name": "2×12b mode"},
        
        # Mode 10: 4×6b
        {"mode": 0x02, "x_in": 0x041044, "y_in": 0x041044, "name": "4×6b mode"},
    ]
    
    sv_code = []
    
    for i, test in enumerate(test_cases):
        if test["mode"] == 0x00:  # 24-bit mode
            exp_result = lse_add_adaptive(test["x_in"], test["y_in"], 24)
        elif test["mode"] == 0x01:  # 2×12b mode
            x_ch0 = test["x_in"] & 0xFFF
            x_ch1 = (test["x_in"] >> 12) & 0xFFF
            y_ch0 = test["y_in"] & 0xFFF
            y_ch1 = (test["y_in"] >> 12) & 0xFFF
            exp_ch0 = lse_add_adaptive(x_ch0, y_ch0, 12)
            exp_ch1 = lse_add_adaptive(x_ch1, y_ch1, 12)
            exp_result = (exp_ch1 << 12) | exp_ch0
        elif test["mode"] == 0x02:  # 4×6b mode
            x_ch0 = test["x_in"] & 0x3F
            x_ch1 = (test["x_in"] >> 6) & 0x3F
            x_ch2 = (test["x_in"] >> 12) & 0x3F
            x_ch3 = (test["x_in"] >> 18) & 0x3F
            y_ch0 = test["y_in"] & 0x3F
            y_ch1 = (test["y_in"] >> 6) & 0x3F
            y_ch2 = (test["y_in"] >> 12) & 0x3F
            y_ch3 = (test["y_in"] >> 18) & 0x3F
            exp_ch0 = lse_add_adaptive(x_ch0, y_ch0, 6)
            exp_ch1 = lse_add_adaptive(x_ch1, y_ch1, 6)
            exp_ch2 = lse_add_adaptive(x_ch2, y_ch2, 6)
            exp_ch3 = lse_add_adaptive(x_ch3, y_ch3, 6)
            exp_result = (exp_ch3 << 18) | (exp_ch2 << 12) | (exp_ch1 << 6) | exp_ch0
        
        print(f"Test {i+1}: {test['name']} (Mode={test['mode']:02b})")
        print(f"  Input: x=0x{test['x_in']:06X}, y=0x{test['y_in']:06X}")
        print(f"  Expected: 0x{exp_result:06X}")
        
        # Générer le code SystemVerilog
        sv_code.append(f"""        // Test {i+1}: {test['name']}
        test_mode(2'b{test['mode']:02b}, 24'h{test['x_in']:06X}, 24'h{test['y_in']:06X}, 24'h{exp_result:06X}, "{test['name']}");""")
    
    print("\n=== SystemVerilog Code for Unified Testbench ===")
    for code in sv_code:
        print(code)
    
    return sv_code


def main():
    print("LSE Test Value Generator")
    print("=" * 50)
    
    # Test rapide de la fonction LSE
    print("=== Test de validation de la fonction LSE ===")
    test_width_6 = [
        (0x10, 0x10, 6),
        (0x08, 0x08, 6),  
        (0x04, 0x04, 6),
        (0x02, 0x02, 6),
        (0x00, 0x00, 6),
    ]
    
    for a, b, w in test_width_6:
        result = lse_add_adaptive(a, b, w)
        print(f"LSE({w}-bit): 0x{a:02X} + 0x{b:02X} = 0x{result:02X}")
    
    print()
    
    # Générer tous les tests
    code_2x12b = generate_simd_2x12b_tests()
    code_4x6b = generate_simd_4x6b_tests() 
    code_unified = generate_simd_unified_tests()
    
    # Sauvegarder dans des fichiers
    with open("simd_2x12b_tests.sv", "w") as f:
        f.write("// Auto-generated SIMD 2×12b test cases\n")
        f.write("// Generated by lse_test_generator.py\n\n")
        for code in code_2x12b:
            f.write(code + "\n\n")
    
    with open("simd_4x6b_tests.sv", "w") as f:
        f.write("// Auto-generated SIMD 4×6b test cases\n")
        f.write("// Generated by lse_test_generator.py\n\n")
        for code in code_4x6b:
            f.write(code + "\n\n")
    
    with open("simd_unified_tests.sv", "w") as f:
        f.write("// Auto-generated SIMD Unified test cases\n")
        f.write("// Generated by lse_test_generator.py\n\n")
        for code in code_unified:
            f.write(code + "\n\n")
    
    print(f"\n=== Fichiers générés ===")
    print("- simd_2x12b_tests.sv")
    print("- simd_4x6b_tests.sv") 
    print("- simd_unified_tests.sv")
    print("\nUtilisez ces fichiers pour mettre à jour vos testbenches SystemVerilog.")


if __name__ == "__main__":
    main()