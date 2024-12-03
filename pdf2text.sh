#!/bin/bash
pdf_for_ocr="$1"
output_dir="ocr_output"
mkdir -p "$output_dir"
rm -rf "$output_dir/*.png $output_dir/*.txt"


# Convert PDF to images
pdftoppm -png "$pdf_for_ocr" "$output_dir/page"

# OCR each image
for img in "$output_dir"/page-*.png; do
    tesseract "$img" "${img%.png}" -l eng
done


echo "$(cat $output_dir/*.txt)"
