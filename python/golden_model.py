import numpy as np
from scipy.signal import correlate2d


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
    return output


def cross_check(image, kernel, apply_relu=False):
    ref = correlate2d(image.astype(np.int64), kernel.astype(np.int64), mode='valid')
    if apply_relu:
        ref = np.maximum(ref, 0)
    return ref


def save_for_verilog(arr, filename, width):
    hex_digits = (width + 3) // 4
    mask = (1 << width) - 1
    with open(filename, 'w') as f:
        for val in arr.flatten():
            f.write(f"{int(val) & mask:0{hex_digits}x}\n")


def run_case(name, input_image, kernel, apply_relu, out_width=16):
    result = golden_model_convolution(input_image, kernel, apply_relu, out_width)
    ref = cross_check(input_image, kernel, apply_relu)
    lo, hi = -(1 << (out_width - 1)), (1 << (out_width - 1)) - 1
    ref_clipped = np.clip(ref, lo, hi)
    match = np.array_equal(result, ref_clipped)
    print(f"[{name}] shape={result.shape} cross_check={'PASS' if match else 'FAIL'} "
          f"saturated_pixels={(np.sum((result == lo) | (result == hi)))}")
    save_for_verilog(input_image, f"{name}_input_image.hex", 8)
    save_for_verilog(kernel, f"{name}_kernel.hex", 8)
    save_for_verilog(result, f"{name}_expected_output.hex", out_width)
    return result


def make_zero_mean_kernel(low, high, shape, rng):
    k = rng.integers(low, high + 1, size=shape)
    k = k - int(round(k.mean()))
    return np.clip(k, low, high).astype(np.int8)


np.random.seed(42)
rng = np.random.default_rng(42)

input_image = np.random.randint(0, 256, (32, 32), dtype=np.uint8)
kernel_normal = np.random.randint(-16, 17, (3, 3), dtype=np.int8)
run_case("normal", input_image, kernel_normal, apply_relu=True)

kernel_extreme = np.random.randint(-128, 128, (3, 3), dtype=np.int8)
run_case("saturation", input_image, kernel_extreme, apply_relu=True)

kernel_balanced = make_zero_mean_kernel(-16, 16, (3, 3), rng)
run_case("balanced", input_image, kernel_balanced, apply_relu=False)