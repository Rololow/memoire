#!/usr/bin/env python3
"""Utility to generate high-precision reference vectors for the lse_add module.

The script computes exact Log-Sum-Exp values in base-2 for a list of fixed-point
inputs and emits:
  1. A JSON file with detailed information about each vector.
  2. A SystemVerilog include file (`*.svh`) that can be consumed by the
     unified testbench to validate the DUT against the reference values.

Usage examples::

    python generate_lse_add_vectors.py                          # defaults
    python generate_lse_add_vectors.py --random 32 --seed 42
    python generate_lse_add_vectors.py --tolerance-lsb 96 \
        --output-svh ../../testbenches/core/reference/lse_add_reference_vectors.svh

"""

from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable, List, Tuple

# Fixed-point configuration (matches lse_add.sv)
WIDTH = 24
FRAC_BITS = 10
SCALE = 1 << FRAC_BITS
MASK = (1 << WIDTH) - 1
NEG_INF_CODE = 1 << (WIDTH - 1)


def real_to_fixed(value: float) -> int:
    """Convert a base-2 logarithmic real value to unsigned fixed-point."""
    fixed = int(round(value * SCALE))
    if fixed < 0:
        fixed = 0
    if fixed > MASK:
        fixed = MASK
    return fixed


def fixed_to_real(value: int) -> float:
    return float(value) / SCALE


def compute_exact_lse(a_real: float, b_real: float) -> float:
    """Compute exact LSE in base-2: log2(exp2(a) + exp2(b))."""
    max_val = max(a_real, b_real)
    min_val = min(a_real, b_real)
    if math.isinf(max_val):
        return max_val
    delta = min_val - max_val
    # Use math.log1p for numerical stability: log2(1 + 2**delta)
    exact = max_val + math.log1p(2.0 ** delta) / math.log(2.0)
    return exact


@dataclass
class ReferenceVector:
    label: str
    operand_a: int
    operand_b: int
    expected: int
    min_expected: int
    max_expected: int
    exact_value: float
    error_tolerance: float

    def to_json_dict(self) -> dict:
        data = asdict(self)
        data.update(
            {
                "operand_a_hex": f"0x{self.operand_a:06X}",
                "operand_b_hex": f"0x{self.operand_b:06X}",
                "expected_hex": f"0x{self.expected:06X}",
                "min_expected_hex": f"0x{self.min_expected:06X}",
                "max_expected_hex": f"0x{self.max_expected:06X}",
            }
        )
        return data


BASE_CASES: Tuple[Tuple[str, float, float], ...] = (
    ("equal_5", 5.0, 5.0),
    ("close_delta_0p5", 5.0, 4.5),
    ("close_delta_1", 3.0, 2.0),
    ("medium_delta_4", 8.0, 4.0),
    ("medium_delta_5", 10.0, 5.0),
    ("large_delta_18", 20.0, 2.0),
    ("zero_zero", 0.0, 0.0),
    ("zero_vs_4", 0.0, 4.0),
    ("four_vs_zero", 4.0, 0.0),
    ("fractional_0p25", 0.25, -0.75),
    ("fractional_1p5", 1.5, 0.0),
    ("fractional_2p75", 2.75, 1.125),
)


def build_reference_vectors(
    base_cases: Iterable[Tuple[str, float, float]],
    random_count: int,
    rng: random.Random,
    tolerance_lsb: int,
    value_range: Tuple[float, float],
) -> List[ReferenceVector]:
    vectors: List[ReferenceVector] = []

    def append_case(label: str, a_real: float, b_real: float) -> None:
        a_fixed = real_to_fixed(a_real)
        b_fixed = real_to_fixed(b_real)
        exact = compute_exact_lse(a_real, b_real)
        expected_fixed = real_to_fixed(exact)
        min_expected = max(expected_fixed - tolerance_lsb, 0)
        max_expected = min(expected_fixed + tolerance_lsb, MASK)
        tolerance_real = tolerance_lsb / SCALE
        vectors.append(
            ReferenceVector(
                label=label,
                operand_a=a_fixed,
                operand_b=b_fixed,
                expected=expected_fixed,
                min_expected=min_expected,
                max_expected=max_expected,
                exact_value=exact,
                error_tolerance=tolerance_real,
            )
        )

    for label, a_real, b_real in base_cases:
        append_case(label, a_real, b_real)

    low, high = value_range
    for idx in range(random_count):
        a_real = rng.uniform(low, high)
        b_real = rng.uniform(low, high)
        append_case(f"random_{idx:03d}", a_real, b_real)

    vectors.sort(key=lambda vec: vec.label)
    return vectors


def write_json(vectors: List[ReferenceVector], path: Path) -> None:
    payload = {
        "width": WIDTH,
        "frac_bits": FRAC_BITS,
        "tolerance_lsb": vectors[0].max_expected - vectors[0].expected if vectors else 0,
        "vectors": [vec.to_json_dict() for vec in vectors],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fout:
        json.dump(payload, fout, indent=2)


def write_svh(vectors: List[ReferenceVector], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fout:
        fout.write("`ifndef LSE_ADD_REFERENCE_VECTORS_SVH\n")
        fout.write("`define LSE_ADD_REFERENCE_VECTORS_SVH\n\n")
        fout.write("// Auto-generated file. Do not edit manually.\n")
        fout.write("// Generated by scripts/python/generate_lse_add_vectors.py\n\n")
        fout.write("typedef struct {\n")
        fout.write("    logic [23:0] operand_a;\n")
        fout.write("    logic [23:0] operand_b;\n")
        fout.write("    logic [23:0] expected;\n")
        fout.write("    logic [23:0] min_expected;\n")
        fout.write("    logic [23:0] max_expected;\n")
        fout.write("    real exact_value;\n")
        fout.write("    real error_tolerance;\n")
        fout.write("    string label;\n")
        fout.write("} lse_add_reference_vector_t;\n\n")
        fout.write(
            f"localparam int LSE_ADD_REFERENCE_VECTOR_COUNT = {len(vectors)};\n"
        )
        tolerance = vectors[0].max_expected - vectors[0].expected if vectors else 0
        fout.write(
            f"localparam real LSE_ADD_REFERENCE_DEFAULT_TOLERANCE = {tolerance / SCALE:.6f};\n\n"
        )
        if vectors:
            fout.write(
                "lse_add_reference_vector_t LSE_ADD_REFERENCE_VECTORS"\
                " [0:LSE_ADD_REFERENCE_VECTOR_COUNT-1] = '{\n"
            )
            for idx, vec in enumerate(vectors):
                comma = "," if idx < len(vectors) - 1 else ""
                fout.write(
                    "    '{"
                    f"24'h{vec.operand_a:06X}, "
                    f"24'h{vec.operand_b:06X}, "
                    f"24'h{vec.expected:06X}, "
                    f"24'h{vec.min_expected:06X}, "
                    f"24'h{vec.max_expected:06X}, "
                    f"{vec.exact_value:.12f}, "
                    f"{vec.error_tolerance:.12f}, "
                    f"\"{vec.label}\"}}{comma}\n"
                )
            fout.write("};\n\n")
        else:
            fout.write(
                "lse_add_reference_vector_t LSE_ADD_REFERENCE_VECTORS"\
                " [0:LSE_ADD_REFERENCE_VECTOR_COUNT-1];\n\n"
            )
        fout.write("`endif // LSE_ADD_REFERENCE_VECTORS_SVH\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-json",
        type=Path,
        default=(Path(__file__).resolve().parents[2]
                 / "simulation_output" / "lse_add_reference_vectors.json"),
        help="Path to the JSON output file.",
    )
    parser.add_argument(
        "--output-svh",
        type=Path,
        default=(Path(__file__).resolve().parents[2]
                 / "testbenches" / "core" / "reference" / "lse_add_reference_vectors.svh"),
        help="Path to the SystemVerilog include file.",
    )
    parser.add_argument(
        "--tolerance-lsb",
        type=int,
        default=64,
        help="Symmetric tolerance applied around the exact result (in LSBs).",
    )
    parser.add_argument(
        "--random",
        type=int,
        default=16,
        help="Number of additional random cases to generate.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=2025,
        help="Random seed for reproducibility.",
    )
    parser.add_argument(
        "--range",
        type=float,
        nargs=2,
        default=(0.0, 12.0),
        metavar=("MIN", "MAX"),
        help="Range for randomly generated logarithmic values (base-2).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    rng = random.Random(args.seed)
    vectors = build_reference_vectors(
        base_cases=BASE_CASES,
        random_count=args.random,
        rng=rng,
        tolerance_lsb=args.tolerance_lsb,
        value_range=tuple(args.range),
    )
    write_json(vectors, args.output_json)
    write_svh(vectors, args.output_svh)
    print(
        f"Generated {len(vectors)} reference vectors with tolerance ±{args.tolerance_lsb} LSB "
        f"({args.tolerance_lsb / SCALE:.6f})."
    )
    print(f"JSON written to: {args.output_json}")
    print(f"SVH written to:  {args.output_svh}")


if __name__ == "__main__":
    main()
