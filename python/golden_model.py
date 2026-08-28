import numpy as np
from scipy.signal import correlate2d
import os

os.makedirs("test_vectors", exist_ok=True)

def golden_model_convolution(image, kernel, apply_relu=False, out_width=16):
    img_h, img_w = image.shape
    ker_h, ker_w = kernel.shape
    out_h, out_w = img_h - ker_h + 1, img_w - ker_w + 1
    output = np.zeros((out_h, out_w), dtype=np.int64)
    
    lo, hi = -(1 << (out_width - 1)), (1 << (out_width - 1)) - 1
    
    for i in range(out_h):
        for j in range(out_w):
            window = image[i:i+ker_h, j:j+ker_w]
            pixel_sum = np.sum(window.astype(np.int64) * kernel.astype(np.int64))
            
            if apply_relu:
                pixel_sum = max(0, pixel_sum)
            
            output[i, j] = np.clip(pixel_sum, lo, hi)
            
    return output.astype(np.int16)

def cross_check(image, kernel, apply_relu=False):
    ref = correlate2d(image.astype(np.int64), kernel.astype(np.int64), mode='valid')
    if apply_relu:
        ref = np.maximum(ref, 0)
    return ref

def save_for_verilog(arr, filename, width):
    hex_digits = (width + 3) // 4
    mask = (1 << width) - 1
    filepath = os.path.join("test_vectors", filename)
    with open(filepath, 'w') as f:
        for val in arr.flatten():
            f.write(f"{int(val) & mask:0{hex_digits}x}\n")

def run_case(name, input_image, kernel, apply_relu, out_width=16):
    result = golden_model_convolution(input_image, kernel, apply_relu, out_width)
    ref = cross_check(input_image, kernel, apply_relu)
    
    lo, hi = -(1 << (out_width - 1)), (1 << (out_width - 1)) - 1
    ref_clipped = np.clip(ref, lo, hi)
    
    match = np.array_equal(result, ref_clipped)
    sat_count = np.sum((result == lo) | (result == hi))
    
    print(f"[{name:10}] Cross-Check: {'PASS' if match else 'FAIL'} | Saturated Pixels: {sat_count}")
    
    save_for_verilog(input_image, f"{name}_input.hex", 8)
    save_for_verilog(kernel, f"{name}_kernel.hex", 8)
    save_for_verilog(result, f"{name}_output.hex", out_width)

rng = np.random.default_rng(42)

img = rng.integers(0, 256, (32, 32), dtype=np.uint8)
ker_norm = rng.integers(-15, 16, (3, 3), dtype=np.int8)
run_case("normal", img, ker_norm, apply_relu=True)

ker_ext = rng.integers(-128, 128, (3, 3), dtype=np.int8)
run_case("extreme", img, ker_ext, apply_relu=True)

ker_bal = rng.integers(-16, 16, (3, 3), dtype=np.int8)
ker_bal -= int(round(ker_bal.mean()))
run_case("balanced", img, ker_bal, apply_relu=False)