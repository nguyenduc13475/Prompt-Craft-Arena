import cv2
import numpy as np


def process_8bit_flat(input_path, output_path):
    img = cv2.imread(input_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        print("Không thấy ảnh!")
        return
    # This formula base on your real image
    height_real = (img.astype(np.float32) - 128.0) * 0.07
    final_img = (height_real + 128.0).clip(0, 255).astype(np.uint8)

    cv2.imwrite(output_path, final_img)
    print(f"Đã xuất ảnh 8-bit 'phẳng': {output_path}")


# Change to your image path
process_8bit_flat("height_map_2.png", "height_map_2.png")
