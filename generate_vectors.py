from PIL import Image
import numpy as np
import os

# Paths relative to script directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
dataset_path = os.path.join(BASE_DIR, "cifar10", "train", "truck")
output_file = os.path.join(BASE_DIR, "test_vectors.txt")

all_vectors = []

# Read first 10 images
image_files = os.listdir(dataset_path)[:10]

for img_name in image_files:

    img_path = os.path.join(dataset_path, img_name)

    # Open image
    img = Image.open(img_path)

    # Convert to grayscale
    img = img.convert('L')

    # Convert to numpy array
    pixels = np.array(img).flatten()

    # Create operand pairs
    for i in range(0, len(pixels)-1, 2):

        A = int(pixels[i])
        B = int(pixels[i+1])

        # IMPORTANT:
        # NO SPACE BETWEEN VALUES
        vector = f"{A:04X}{B:04X}"

        all_vectors.append(vector)

# Save vectors
with open(output_file, "w") as f:

    for vec in all_vectors:
        f.write(vec + "\n")

print("test_vectors.txt generated successfully!")
print("Total vectors:", len(all_vectors))