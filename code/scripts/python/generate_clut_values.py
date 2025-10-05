#!/usr/bin/env python3
"""
CLUT Value Generator for LSE-PE Architecture
============================================

Generates correction values for the Compact Look-Up Table (CLUT) used in 
LSE approximation error correction.

Reference: Yao et al., "LSE-PE: Hardware Efficient for Tractable Probabilistic Reasoning"

Author: LSE-PE Project  
Date: October 2025
"""

import numpy as np
import matplotlib.pyplot as plt
import json
from typing import List, Tuple
import argparse

def lse_exact(x: float) -> float:
    """
    Exact LSE correction function: f(x) = log₂(1 + 2^x)
    
    Args:
        x: Input value in range [0, 1)
        
    Returns:
        Exact LSE correction value
    """
    return np.log2(1.0 + np.power(2.0, x))

def lse_approximation(x: float) -> float:
    """
    Double approximation used in LSE-PE hardware.
    
    For Mitchell approximation: 2^x ≈ x + 1
    Then: log₂(1 + 2^x) ≈ log₂(1 + x + 1) = log₂(2 + x) ≈ 1 + x/2
    
    Simplified first-order: f(x) ≈ x
    
    Args:
        x: Input value in range [0, 1)
        
    Returns:
        Hardware approximation result
    """
    return x  # First-order approximation

def compute_correction_error(x: float) -> float:
    """
    Compute the error that needs to be corrected by CLUT.
    
    Args:
        x: Input value in range [0, 1)
        
    Returns:
        Error = exact_value - approximation
    """
    exact = lse_exact(x)
    approx = lse_approximation(x)
    return exact - approx

def generate_clut_values(entries: int = 16, bit_width: int = 10) -> List[int]:
    """
    Generate CLUT correction values for hardware implementation.
    
    Args:
        entries: Number of LUT entries (default: 16)
        bit_width: Bit width per entry (default: 10)
        
    Returns:
        List of quantized correction values
    """
    # Generate uniform sampling points in [0, 1)
    sample_points = np.linspace(0, 1 - 1/entries, entries)
    
    # Compute correction errors
    corrections = [compute_correction_error(x) for x in sample_points]
    
    # Find max correction for scaling
    max_correction = max(corrections)
    
    # Quantize to bit_width bits
    max_int_value = (2**bit_width) - 1
    quantized_values = []
    
    for corr in corrections:
        # Scale to [0, max_int_value]
        scaled = (corr / max_correction) * max_int_value
        quantized = int(round(scaled))
        quantized_values.append(min(quantized, max_int_value))
    
    return quantized_values, sample_points, corrections, max_correction

def generate_systemverilog_rom(values: List[int], bit_width: int = 10) -> str:
    """
    Generate SystemVerilog ROM initialization code.
    
    Args:
        values: List of quantized values
        bit_width: Bit width per entry
        
    Returns:
        SystemVerilog code string
    """
    sv_code = f"// CLUT ROM Data - {len(values)} entries x {bit_width} bits\n"
    sv_code += f"logic [{bit_width-1}:0] lut_rom [{len(values)}] = '{{\n"
    
    for i, val in enumerate(values):
        hex_val = f"{bit_width}'h{val:0{(bit_width+3)//4}X}"
        comment = f"  // Entry {i:2d}: f({i/len(values):.4f}) correction"
        
        if i == len(values) - 1:
            sv_code += f"    {hex_val}   {comment}\n"
        else:
            sv_code += f"    {hex_val},  {comment}\n"
    
    sv_code += "};\n"
    return sv_code

def plot_lse_functions(sample_points: np.ndarray, corrections: List[float], 
                      quantized_values: List[int], max_correction: float, 
                      bit_width: int = 10, save_path: str = None):
    """
    Plot LSE functions and correction values for analysis.
    
    Args:
        sample_points: X-axis sample points
        corrections: Exact correction values  
        quantized_values: Quantized correction values
        max_correction: Maximum correction for scaling
        bit_width: Bit width for quantization
        save_path: Optional path to save plot
    """
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(12, 10))
    
    # Fine-grained x for smooth curves
    x_fine = np.linspace(0, 1, 1000)
    
    # Plot 1: Exact vs Approximation functions
    ax1.plot(x_fine, [lse_exact(x) for x in x_fine], 'b-', label='Exact: log₂(1 + 2^x)', linewidth=2)
    ax1.plot(x_fine, [lse_approximation(x) for x in x_fine], 'r--', label='Approximation: x', linewidth=2)
    ax1.scatter(sample_points, [lse_exact(x) for x in sample_points], c='blue', s=30, zorder=5)
    ax1.set_xlabel('x')
    ax1.set_ylabel('f(x)')
    ax1.set_title('LSE Function: Exact vs Approximation')
    ax1.legend()
    ax1.grid(True, alpha=0.3)
    
    # Plot 2: Correction Error
    ax2.plot(x_fine, [compute_correction_error(x) for x in x_fine], 'g-', label='Continuous error', linewidth=2)
    ax2.scatter(sample_points, corrections, c='red', s=50, label='CLUT samples', zorder=5)
    ax2.set_xlabel('x')
    ax2.set_ylabel('Correction Error')
    ax2.set_title('Correction Error: Exact - Approximation')
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    
    # Plot 3: Quantized CLUT Values
    max_int_value = (2**bit_width) - 1
    dequantized = [val * max_correction / max_int_value for val in quantized_values]
    
    ax3.bar(range(len(quantized_values)), quantized_values, alpha=0.7, color='orange')
    ax3.set_xlabel('LUT Entry')
    ax3.set_ylabel(f'Quantized Value ({bit_width}-bit)')
    ax3.set_title(f'CLUT Quantized Values (Max: {max_int_value})')
    ax3.grid(True, alpha=0.3)
    
    # Plot 4: Reconstruction Error
    reconstruction_error = [abs(corr - deq) for corr, deq in zip(corrections, dequantized)]
    ax4.semilogy(sample_points, reconstruction_error, 'mo-', label='Quantization error')
    ax4.set_xlabel('x')
    ax4.set_ylabel('Reconstruction Error (log scale)')
    ax4.set_title('CLUT Quantization Error')
    ax4.legend()
    ax4.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    if save_path:
        plt.savefig(save_path, dpi=300, bbox_inches='tight')
        print(f"Plot saved to: {save_path}")
    
    plt.show()

def main():
    """Main function with command-line interface."""
    parser = argparse.ArgumentParser(description='Generate CLUT values for LSE-PE')
    parser.add_argument('--entries', type=int, default=16, help='Number of LUT entries')
    parser.add_argument('--bits', type=int, default=10, help='Bit width per entry')
    parser.add_argument('--output', type=str, help='Output file for SystemVerilog code')
    parser.add_argument('--plot', action='store_true', help='Show analysis plots')
    parser.add_argument('--save-plot', type=str, help='Save plot to file')
    
    args = parser.parse_args()
    
    print(f"Generating CLUT with {args.entries} entries, {args.bits} bits each...")
    
    # Generate CLUT values
    quantized_values, sample_points, corrections, max_correction = generate_clut_values(
        args.entries, args.bits
    )
    
    # Print statistics
    print(f"\nCLUT Statistics:")
    print(f"  Sample range: [0, {1-1/args.entries:.4f})")
    print(f"  Max correction: {max_correction:.6f}")
    print(f"  Quantization scale: {max_correction/((2**args.bits)-1):.8f}")
    print(f"  Values: {quantized_values}")
    
    # Generate SystemVerilog code
    sv_code = generate_systemverilog_rom(quantized_values, args.bits)
    
    if args.output:
        with open(args.output, 'w') as f:
            f.write(sv_code)
        print(f"\nSystemVerilog ROM code saved to: {args.output}")
    else:
        print(f"\nSystemVerilog ROM Code:")
        print(sv_code)
    
    # Generate JSON report
    report = {
        'parameters': {
            'entries': args.entries,
            'bit_width': args.bits,
            'max_correction': max_correction
        },
        'sample_points': sample_points.tolist(),
        'exact_corrections': corrections,
        'quantized_values': quantized_values,
        'systemverilog_code': sv_code
    }
    
    json_file = args.output.replace('.sv', '.json') if args.output else 'clut_report.json'
    with open(json_file, 'w') as f:
        json.dump(report, f, indent=2)
    print(f"Detailed report saved to: {json_file}")
    
    # Show plots if requested
    if args.plot or args.save_plot:
        plot_lse_functions(
            np.array(sample_points), corrections, quantized_values, 
            max_correction, args.bits, args.save_plot
        )

if __name__ == '__main__':
    main()