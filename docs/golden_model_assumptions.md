# Golden Model — Assumptions & Design Decisions
**IEEE SSCS Egypt Chapter 2026 Student Design Competition**

The competition spec leaves several parameters open ("assume any missing
information, but state all assumptions clearly"). This document lists every
assumption baked into `golden_model.py` / `fixed_point.py`, why it was
chosen, and what it means for the rest of the team. 

---

## 0. Module structure — `golden_model.py` + `fixed_point.py`
**Reason:** Bit-width math, saturation, dtype selection, and two's-complement
hex conversion were originally written directly inside `golden_model.py`.
They've since been factored out into a separate `fixed_point.py` module, so
there is exactly **one** implementation of each rule instead of duplicated
logic that could silently drift apart. `golden_model.py` now imports from
it: `signed_range`, `saturate`, `pick_dtype`, `hex_string`.
**Impact:** Any future module that needs the same rules (e.g. an image-input
module, or an RTL-output comparison script) should import from
`fixed_point.py` rather than re-implementing this logic. `fixed_point.py`
also exposes `from_twos_complement_bits()` — the reverse of `hex_string()` —
intended for converting RTL simulation hex dumps back into signed integers
for comparison against the golden model.

`golden_model.py`'s test-case execution (all `run_case(...)` calls) is now
wrapped under `if __name__ == "__main__":`, so importing
`golden_model_convolution` from another script no longer triggers test
output or writes to `test_vectors/` as a side effect.

---

## 1. Kernel size — N = 3 (3×3)
**Reason:** Spec requires "N×N, programmable coefficients" but doesn't fix N.
3×3 is the smallest practical CNN kernel, keeps the adder tree small (9
taps), and is the standard choice for edge-detection kernels (Sobel,
Laplacian) used in the bonus demo. N is not runtime-configurable — it is
fixed at synthesis time. Coefficients *within* the 3×3 kernel remain
programmable, satisfying Req #3.

## 2. Padding — VALID (no padding)
**Reason:** Spec never specifies padding. VALID is the simpler hardware
implementation (no border zero-injection logic needed in the window
generator) and is explicitly allowed since the spec never mandates fixed
output size.
**Impact:** Output size = input − (N−1) in each dimension. For a 32×32 input,
output is **30×30**, not 32×32. The window generator must produce
exactly 900 output windows, not 1024.

## 3. Input precision — 8-bit unsigned (0–255)
**Reason:** Req #2 mandates "unsigned fixed point" but doesn't give a width.
8-bit unsigned is the natural choice for grayscale pixel data (standard 0–255
range, matches typical image sensor/frame-buffer output) and keeps the
multiplier size reasonable.

## 4. Kernel precision — 8-bit signed
**Reason:** Explicitly mandated by Req #4 ("8-bit signed fixed-point or
integer"). No assumption needed here — this one is fixed by the spec itself.
`fixed_point.py`'s `quantize_to_fixed()` additionally supports fractional
Q-formats (e.g. Q1.7) if a non-integer kernel is ever needed, though the
current test kernels (Sobel, random integers) don't require it.

## 5. Output precision — 16-bit signed (minimum, as required)
**Reason:** Req #6 sets 16-bit signed as the floor; wider is allowed but not
used here to keep BRAM/FF usage minimal for the FoM calculation (which
penalizes resource usage in the denominator).

## 6. Accumulator width — 20-bit signed (internal, before final saturation)
**Reason:** Derived, not chosen freely, and now computed by
`fixed_point.required_accumulator_bits(input_width=8, kernel_width=8,
num_taps=9)` rather than by hand:
- Product bits: `input_width + kernel_width` = 8 + 8 = 16 bits
- Growth from summing 9 worst-case products: `ceil(log2(9))` = 4 bits
- Total: **20 bits**
This is cross-checked in `fixed_point.py`'s self-test against the actual
worst-case sum produced by `golden_model.py` (−293,760, from
`worst_case_neg`), confirming 20 bits is sufficient with margin (20-bit
signed range extends to ±524,288).
**Impact:** The MAC/adder-tree accumulator must be ≥20 bits.
Only the *final* 20-bit sum is saturated down to 16-bit output — there must
be **no intermediate saturation** on partial sums, or results will not match
the golden model bit-for-bit.

## 7. Overflow handling — Saturate, no rounding
**Reason:** Req #6 requires overflow to be handled but doesn't specify how.
Saturation (clip to [-32768, 32767], via `fixed_point.saturate()`) was chosen
over wraparound because wraparound produces visually/numerically meaningless
results for an image-processing accelerator — saturation is the standard,
sensible choice for Edge-AI vision. No rounding is applied since there's no
fractional truncation happening (integer MAC only, no fixed-point shift-down).

## 8. No bias term
**Reason:** Not mentioned anywhere in the spec. Omitted to keep the design
minimal and match the letter of the requirements exactly.

## 9. Convolution = correlation (no kernel flip)
**Reason:** True mathematical convolution flips the kernel 180°; virtually
all CNN/hardware accelerator literature (and the spec's casual use of the
word "convolution") actually means cross-correlation (no flip). This matches
standard hardware/ML convention and avoids unnecessary complexity.

## 10. ReLU — applied after MAC sum, before saturation clip
**Reason:** Req #7 says ReLU is optional/bonus but doesn't specify where in
the pipeline it goes if implemented. Applying ReLU before the final clip
means negative sums are zeroed first, so they can never trigger negative
saturation — this ordering was chosen because it's the standard order in ML
frameworks (bias → activation → quantize/clip).
**Note:** because of this ordering, the negative-saturation path is only
reachable when ReLU is *off* — see item 12 below.

## 11. Golden model language — Python (NumPy + SciPy)
**Reason:** Easiest to produce bit-exact `.hex` test vectors for
`$readmemh` and to independently cross-check via `scipy.signal.correlate2d`
against a hand-written reference loop, catching bugs in either
implementation. Bit-width and conversion utilities (saturation, dtype
selection, two's-complement hex encode/decode, quantization) live separately
in `fixed_point.py` — see item 0.

## 12. Test vector selection (not random alone)
**Reason:** Random test data alone doesn't reliably exercise edge cases like
saturation boundaries. In addition to 3 randomized cases (`normal`,
`extreme`, `balanced`), the following deliberate/synthetic cases were added:
- `all_zero` — sanity check, output must be exactly 0.
- `identity` — single-tap kernel, output must exactly equal a cropped copy
  of the input; catches sliding-window misalignment immediately.
- `worst_case_neg` — every pixel/tap set to force the most negative possible
  sum (9 × 255 × −128 = −293,760), guaranteeing negative saturation (with
  ReLU off, since ReLU would zero this path — see item 10).
- `worst_case_pos` — symmetric positive case (9 × 255 × 127 = 291,465),
  guaranteeing positive saturation. Added because saturation logic is a
  common source of asymmetric off-by-one bugs in RTL (e.g. clamping to
  32768 instead of 32767); the positive boundary needs its own explicit
  test and is not covered by the negative test.

**Known open gap:** none of the current test cases yet distinguish "correct
20-bit accumulator, saturate once at the end" from "buggy narrow accumulator
that saturates too early mid-sum" — `worst_case_neg`/`worst_case_pos` use a
uniform kernel, so every partial sum moves in the same direction and a
prematurely-clamped accumulator would coincidentally land on the same final
answer. A future `no_intermediate_saturation` test case (a kernel that
overshoots the 16-bit range early, then returns within range by the final
tap) would close this gap. Not yet implemented.

## 13. Hex file / memory word order — row-major (C order)
**Reason:** `numpy.flatten()` defaults to row-major: entire row 0
left-to-right, then row 1, etc. This is the natural/simplest order and the
one assumed by most Verilog `$readmemh` usage patterns. The actual hex
formatting (two's-complement encode + zero-pad) is done by
`fixed_point.hex_string()`, called from `save_for_verilog()` — a single
implementation, not duplicated inline.
**Impact:** The line buffer / window generator and the testbench must read
pixels in this same row-major order, or output pixel positions will silently
misalign against the golden model despite both "passing" independently.

## 14. Single kernel / single channel only
**Reason:** The base spec only requires a single grayscale input channel and
a single configurable kernel. "Support for multiple kernels" is listed only
as a bonus item — not implemented in the mandatory design.

## 15. Real-image / quantization support — deliberately out of scope for now
**Reason:** Not required by the spec (Req #8 only requires verification
against test cases, which the synthetic vectors above already satisfy). An
optional `quantization.py` module (real/synthetic image loading +
input/output visualization) exists separately in the repo for the
optional bonus edge-detection demo, but is **not** part of the core golden
model pipeline and is not assumed or depended on by any of the items above.

---

## Summary table for the report (Table 1 / Table 2 style)

| Parameter | Value | Source |
|---|---|---|
| Kernel size (N) | 3×3 | Assumption |
| Padding | Valid (no pad) | Assumption |
| Output size | 30×30 (for 32×32 input) | Derived from N + padding |
| Input precision | 8-bit unsigned | Assumption |
| Kernel precision | 8-bit signed | **Required by spec** |
| Output precision | 16-bit signed | **Required by spec (min)** |
| Accumulator width | 20-bit signed | Derived (`fixed_point.required_accumulator_bits`), no overflow, no intermediate saturation |
| Overflow handling | Saturate, no rounding | Assumption |
| Bias | None | Assumption |
| Convolution type | Correlation (no flip) | Assumption / convention |
| ReLU position | After MAC, before final clip | Assumption |
| Hex word order | Row-major | Assumption |
| Kernels/channels | Single kernel, single channel | Assumption (spec baseline) |
| Real image / quantization | Not used in core pipeline | Deliberately deferred |

---
