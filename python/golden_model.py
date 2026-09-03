"""
Golden Model - IEEE SSCS Egypt Chapter 2026 Student Design Competition
SPEC COMPLIANCE NOTES (assumptions, per Instruction #4 - "assume missing
info, state clearly"):
  - Kernel size: 3x3 (N=3), VALID convolution (no padding) -> output size
    = (H-2) x (W-2). For a 32x32 input this gives a 30x30 output.
  - Input: unsigned 8-bit, 0-255 (matches Req #2, "fixed point unsigned")
  - Kernel: signed 8-bit integer (matches Req #4, "8-bit signed")
  - Output: signed, MINIMUM 16-bit per Req #6 ("wider output precision is
    allowed"). out_width=16 is used for every official test vector below;
    the parameter still supports wider widths for internal debug use
    (e.g. checking a wider MAC accumulator) - see the Issue 2 fix below.
  - No bias term (not required by spec, not mentioned anywhere in it)
  - Overflow handling: SATURATE (clip) to [-2^(w-1), 2^(w-1)-1], no rounding
  - Convolution = correlation (no kernel flip) - standard CNN/hardware
    convention, matches the spec's use of "convolution" loosely
  - ReLU (Req #7, optional bonus): applied AFTER the MAC sum, BEFORE the
    saturation clip
"""
from fixed_point import signed_range, saturate, pick_dtype, hex_string
import numpy as np
from scipy.signal import correlate2d
import os

# --- CHANGED: now reuses fixed_point.py instead of duplicating saturation,
# dtype-picking, and two's-complement hex logic inline. One source of truth
# for these rules, shared with quantization.py too.
from fixed_point import signed_range, saturate, pick_dtype, hex_string

os.makedirs("test_vectors", exist_ok=True)


def golden_model_convolution(image, kernel, apply_relu=False, out_width=16):
    """
    Reference (golden) convolution matching the intended hardware behavior:
    MAC sum -> optional ReLU -> saturate to out_width bits.
    """
    img_h, img_w = image.shape
    ker_h, ker_w = kernel.shape
    out_h, out_w = img_h - ker_h + 1, img_w - ker_w + 1
    output = np.zeros((out_h, out_w), dtype=np.int64)

    for i in range(out_h):
        for j in range(out_w):
            window = image[i:i + ker_h, j:j + ker_w]
            pixel_sum = np.sum(window.astype(np.int64) * kernel.astype(np.int64))

            if apply_relu:
                pixel_sum = max(0, pixel_sum)

            output[i, j] = saturate(pixel_sum, out_width, signed=True)

    # --- CHANGED (Issue 2 fix, now centralized in fixed_point.pick_dtype) --
    # OLD CODE (bug): always returned int16 no matter what out_width was:
    #     return output.astype(np.int16)
    # This silently mismatched the result any time out_width != 16.
    # NEW CODE: pick_dtype() picks the dtype that actually matches out_width.
    # For the spec-compliant default (out_width=16, used everywhere below)
    # this behaves EXACTLY as before - no change to any existing result.
    return output.astype(pick_dtype(out_width, signed=True))
    # --------------------------------------------------------------------


def cross_check(image, kernel, apply_relu=False):
    """
    Independent recomputation using SciPy's correlate2d, used ONLY to catch
    bugs in golden_model_convolution's hand-written loop above.
    This is never itself compared against the RTL - only
    golden_model_convolution's output is used for that.
    """
    ref = correlate2d(image.astype(np.int64), kernel.astype(np.int64), mode='valid')
    if apply_relu:
        ref = np.maximum(ref, 0)
    return ref


def save_for_verilog(arr, filename, width):
    filepath = os.path.join("test_vectors", filename)
    with open(filepath, 'w') as f:
        for val in arr.flatten():
            f.write(hex_string(val, width) + "\n")


def run_case(name, input_image, kernel, apply_relu, out_width=16):
    result = golden_model_convolution(input_image, kernel, apply_relu, out_width)
    ref = cross_check(input_image, kernel, apply_relu)

    lo, hi = signed_range(out_width)
    ref_clipped = np.clip(ref, lo, hi)

    match = np.array_equal(result, ref_clipped)
    sat_count = np.sum((result == lo) | (result == hi))

    print(f"[{name:14}] Cross-Check: {'PASS' if match else 'FAIL'} | Saturated Pixels: {sat_count}")

    save_for_verilog(input_image, f"{name}_input.hex", 8)
    save_for_verilog(kernel, f"{name}_kernel.hex", 8)
    save_for_verilog(result, f"{name}_output.hex", out_width)

    # --- CHANGED: run_case now returns result so extra checks can be run
    # on it afterward (used by the all_zero / identity / worst_case tests
    # below to assert the exact expected behavior, not just "PASS/FAIL"
    # against the cross-check).
    return result


rng = np.random.default_rng(42)
img = rng.integers(0, 256, (32, 32), dtype=np.uint8)

# ---------------------------------------------------------------------
# Test: "normal" - typical case, mild kernel, ReLU on (unchanged)
# ---------------------------------------------------------------------
ker_norm = rng.integers(-15, 16, (3, 3), dtype=np.int8)
run_case("normal", img, ker_norm, apply_relu=True)

# ---------------------------------------------------------------------
# Test: "extreme" - CHANGED (Issue 1 fix): apply_relu is now False.
# Reason: with apply_relu=True, every negative MAC sum is zeroed BEFORE
# the saturation check runs, so the output could never actually equal
# the negative limit (lo) - that branch was mathematically unreachable.
# Setting apply_relu=False lets negative sums survive so the negative
# saturation path has a real chance to be exercised.
# ---------------------------------------------------------------------
ker_ext = rng.integers(-128, 128, (3, 3), dtype=np.int8)
run_case("extreme", img, ker_ext, apply_relu=False)

# ---------------------------------------------------------------------
# Test: "balanced" - mean-zero kernel, ReLU off (unchanged)
# ---------------------------------------------------------------------
ker_bal = rng.integers(-16, 16, (3, 3), dtype=np.int8)
ker_bal -= int(round(ker_bal.mean()))
run_case("balanced", img, ker_bal, apply_relu=False)

# ---------------------------------------------------------------------
# ADDED (Issue 3): "all_zero" sanity check.
# If every input pixel is 0, the output must be all 0 (0 x anything = 0).
# Fast "did I break something basic" alarm.
# ---------------------------------------------------------------------
img_zero = np.zeros((32, 32), dtype=np.uint8)
ker_any = rng.integers(-16, 16, (3, 3), dtype=np.int8)
zero_result = run_case("all_zero", img_zero, ker_any, apply_relu=False)
assert np.all(zero_result == 0), "all_zero test FAILED: expected all-zero output"

# ---------------------------------------------------------------------
# ADDED (Issue 3): "identity" sanity check.
# Kernel has a single 1 at the center, 0 elsewhere -> output must exactly
# equal a cropped copy of the input (nothing scaled or summed). Useful
# for Person 3 later: if the hardware sliding-window logic is misaligned,
# this test will fail immediately and obviously.
# ---------------------------------------------------------------------
ker_identity = np.zeros((3, 3), dtype=np.int8)
ker_identity[1, 1] = 1
identity_result = run_case("identity", img, ker_identity, apply_relu=False)
expected_crop = img[1:-1, 1:-1].astype(np.int16)  # crop matches valid-mode output size
assert np.array_equal(identity_result, expected_crop), "identity test FAILED: output != cropped input"

# ---------------------------------------------------------------------
# ADDED: deliberate (non-random) worst-case NEGATIVE saturation test.
# Diagnostics on the random "extreme" case showed it never actually
# produces a raw sum below the 16-bit negative limit (-32768) - it only
# got within 896 of it, even with ReLU off. Relying on random data to
# "accidentally" reach the saturation edge is unreliable, so this test
# forces it directly: every pixel = max input (255) x most-negative
# kernel tap (-128), guaranteeing the largest possible negative sum
# (9 x 255 x -128 = -293,760) at every single output position.
# ---------------------------------------------------------------------
img_worst = np.full((32, 32), 255, dtype=np.uint8)
ker_worst_neg = np.full((3, 3), -128, dtype=np.int8)
worst_neg_result = run_case("worst_case_neg", img_worst, ker_worst_neg, apply_relu=False)
lo16, hi16 = signed_range(16)
assert np.all(worst_neg_result == lo16), "worst_case_neg test FAILED: expected full negative saturation"
print(f"worst_case_neg: confirmed all {worst_neg_result.size} pixels saturated at {lo16} (negative clip verified)")

# ---------------------------------------------------------------------
# ADDED: symmetric deliberate worst-case POSITIVE saturation test.
# Mirrors worst_case_neg above, but for the opposite direction: max input
# (255) x max positive kernel tap (127) at every position, guaranteeing
# the largest possible POSITIVE sum (9 x 255 x 127 = 291,465) at every
# output pixel. Without this, positive saturation was only ever proven by
# the random "extreme" test (213/900 pixels, not a guaranteed full case) -
# this makes the positive side just as rigorously proven as the negative
# side now is.
# ---------------------------------------------------------------------
ker_worst_pos = np.full((3, 3), 127, dtype=np.int8)
worst_pos_result = run_case("worst_case_pos", img_worst, ker_worst_pos, apply_relu=False)
assert np.all(worst_pos_result == hi16), "worst_case_pos test FAILED: expected full positive saturation"
print(f"worst_case_pos: confirmed all {worst_pos_result.size} pixels saturated at {hi16} (positive clip verified)")