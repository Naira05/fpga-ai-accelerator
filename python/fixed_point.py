"""
fixed_point.py 

Reusable, spec-justifying utilities for the CNN accelerator's fixed-point
math. This is the module that answers "why these bit widths?" and "what
happens on overflow?" - the exact things Req #2 and Req #6 ask you to
justify in the report.

Design choices this file assumes (see golden_model.py header for the full
list): input = unsigned integer (UQ_w.0), kernel = signed integer (Qk.0 by
default, but quantize_to_fixed supports fractional formats too if you ever
want a non-integer kernel like a normalized Gaussian blur).
"""

import numpy as np


# ---------------------------------------------------------------------------
# Bit-width range helpers
# ---------------------------------------------------------------------------

def signed_range(width):
    """Min/max representable value for a signed two's-complement integer
    of `width` bits. e.g. width=16 -> (-32768, 32767)."""
    lo = -(1 << (width - 1))
    hi = (1 << (width - 1)) - 1
    return lo, hi


def unsigned_range(width):
    """Min/max representable value for an unsigned integer of `width` bits."""
    return 0, (1 << width) - 1


def pick_dtype(width, signed=True):
    """
    Picks the smallest numpy dtype that can hold a value of `width` bits.
    Centralizes the same logic golden_model.py used to hardcode as int16 -
    used both there (for the accumulator/output) and here (for quantized
    kernels/inputs), so there is exactly one place this decision is made.
    """
    if signed:
        if width <= 8:
            return np.int8
        elif width <= 16:
            return np.int16
        elif width <= 32:
            return np.int32
        else:
            return np.int64
    else:
        if width <= 8:
            return np.uint8
        elif width <= 16:
            return np.uint16
        elif width <= 32:
            return np.uint32
        else:
            return np.uint64


def required_accumulator_bits(input_width, kernel_width, num_taps):
    """
    Computes the minimum accumulator width (bits) needed to guarantee NO
    internal overflow during the MAC sum, before any saturation is applied.

    Reasoning:
      - An (unsigned input_width-bit) x (signed kernel_width-bit) product
        needs exactly input_width + kernel_width bits to represent exactly,
        signed (no extra bit needed - this is a standard fixed-point rule).
      - Summing `num_taps` such worst-case products can grow the magnitude
        by up to a factor of num_taps, which costs ceil(log2(num_taps))
        extra bits.

    Example: input_width=8, kernel_width=8, num_taps=9 (3x3 kernel)
             -> 8 + 8 + ceil(log2(9)) = 8 + 8 + 4 = 20 bits.
    This matches the empirical worst-case sum from golden_model.py's
    worst_case_neg test (-293,760, which needs exactly 20 signed bits) -
    see the self-check at the bottom of this file.
    """
    product_bits = input_width + kernel_width
    growth_bits = int(np.ceil(np.log2(num_taps))) if num_taps > 1 else 0
    return product_bits + growth_bits


# ---------------------------------------------------------------------------
# Saturation
# ---------------------------------------------------------------------------

def saturate(value, width, signed=True):
    """
    Clips value(s) to the representable range of `width` bits.
    Works on scalars or numpy arrays. This is the single saturation
    implementation golden_model.py now calls, instead of recomputing
    lo/hi inline in two separate places.
    """
    lo, hi = signed_range(width) if signed else unsigned_range(width)
    return np.clip(value, lo, hi)


# ---------------------------------------------------------------------------
# Quantization (float <-> fixed-point integer)
# ---------------------------------------------------------------------------

def quantize_to_fixed(value, total_bits, frac_bits=0, signed=True, rounding="nearest"):
    """
    Converts float value(s) into a fixed-point INTEGER representation:
    the raw bits you'd actually load into hardware memory.

    total_bits : total word width (e.g. 8 for your kernel memory)
    frac_bits  : how many of those bits are fractional (0 = plain integer,
                 e.g. Q7.0; 7 = Q1.7 normalized weights, etc.)
    rounding   : "nearest" (round-half-away-from-zero) or "truncate"

    Not needed for integer kernels like Sobel (already whole numbers), but
    essential if you ever want a kernel defined with real-valued weights
    (e.g. a normalized Gaussian blur, whose weights sum to 1.0) - this is
    where those get converted into legal 8-bit signed integers.
    """
    scale = 1 << frac_bits
    scaled = np.asarray(value, dtype=np.float64) * scale

    if rounding == "nearest":
        scaled = np.round(scaled)
    elif rounding == "truncate":
        scaled = np.trunc(scaled)
    else:
        raise ValueError(f"Unknown rounding mode: {rounding}")

    saturated = saturate(scaled, total_bits, signed=signed)
    return saturated.astype(pick_dtype(total_bits, signed=signed))


def dequantize_from_fixed(fixed_val, frac_bits=0):
    """Converts a fixed-point integer back to its real (float) value -
    useful for reporting quantization error, not used in the hardware
    path itself."""
    return np.asarray(fixed_val, dtype=np.float64) / (1 << frac_bits)


# ---------------------------------------------------------------------------
# Two's-complement <-> hex, for Verilog memory files and RTL sim comparison
# ---------------------------------------------------------------------------

def to_twos_complement_bits(value, width):
    """Converts a signed integer into its unsigned bit-pattern representation
    (what actually gets stored in an 8/16-bit hardware register)."""
    mask = (1 << width) - 1
    return int(value) & mask


def hex_string(value, width):
    """Formats a signed value as a zero-padded two's-complement hex string,
    ready for $readmemh. Same logic save_for_verilog used inline before."""
    hex_digits = (width + 3) // 4
    return f"{to_twos_complement_bits(value, width):0{hex_digits}x}"


def from_twos_complement_bits(bits, width):
    """
    Reverse direction: interprets an unsigned bit pattern (e.g. read back
    from an RTL simulation dump) as a signed two's-complement value.
    Not used by golden_model.py yet, but this is exactly what Person 4's
    testbench comparison will need when parsing RTL output hex dumps back
    into signed integers to compare against the golden model.
    """
    bits = int(bits) & ((1 << width) - 1)
    if bits >= (1 << (width - 1)):
        bits -= (1 << width)
    return bits


# ---------------------------------------------------------------------------
# Self-check / demo - run this file directly to see it in action
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=== Accumulator bit-width for your 3x3, 8-bit/8-bit design ===")
    acc_bits = required_accumulator_bits(input_width=8, kernel_width=8, num_taps=9)
    print(f"Required accumulator width: {acc_bits} bits")

    print("\n=== Cross-check against golden_model.py's actual worst case ===")
    worst_case_sum = 9 * 255 * -128  # every tap = max input x most-negative kernel value
    lo, hi = signed_range(acc_bits)
    print(f"Worst-case raw sum: {worst_case_sum}")
    print(f"{acc_bits}-bit signed range: [{lo}, {hi}]")
    assert lo <= worst_case_sum <= hi, "accumulator width formula is WRONG - overflow would occur!"
    print("Confirmed: the formula's bit width is sufficient (no overflow).")

    print("\n=== Two's-complement round-trip self-test ===")
    for test_val in [-128, -1, 0, 1, 127]:
        bits = to_twos_complement_bits(test_val, 8)
        back = from_twos_complement_bits(bits, 8)
        status = "OK" if back == test_val else "MISMATCH"
        print(f"  {test_val:5} -> 0x{bits:02x} -> {back:5}  [{status}]")
        assert back == test_val

    print("\n=== Example: quantizing a fractional kernel (Gaussian blur) ===")
    gaussian_float = np.array([[1, 2, 1],
                                [2, 4, 2],
                                [1, 2, 1]], dtype=np.float64) / 16.0  # normalized, sums to 1.0
    print("Original float kernel:\n", gaussian_float)

    gaussian_fixed = quantize_to_fixed(gaussian_float, total_bits=8, frac_bits=7, signed=True)
    print("Quantized to Q1.7 signed 8-bit:\n", gaussian_fixed)

    gaussian_recovered = dequantize_from_fixed(gaussian_fixed, frac_bits=7)
    print("Dequantized back to float:\n", gaussian_recovered)

    error = np.abs(gaussian_float - gaussian_recovered)
    print(f"Max quantization error: {error.max():.6f}")