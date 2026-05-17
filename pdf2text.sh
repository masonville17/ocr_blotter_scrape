#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 REPORT.pdf [output_dir]" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 64
fi

for cmd in basename cat pdfimages pdftoppm realpath sed tesseract; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 127
  fi
done

pdf_for_ocr="$1"
if [[ ! -f "$pdf_for_ocr" ]]; then
  echo "PDF not found: $pdf_for_ocr" >&2
  exit 66
fi

output_root="${2:-ocr_output}"
pdf_path="$(realpath "$pdf_for_ocr")"
pdf_name="$(basename "$pdf_path")"
pdf_stem="${pdf_name%.*}"
pdf_stem="$(printf '%s' "$pdf_stem" | sed -E 's/[^A-Za-z0-9._-]+/_/g; s/_+/_/g; s/^_//; s/_$//')"

render_dir="$output_root/rendered_pages/$pdf_stem"
image_dir="$output_root/extracted_images/$pdf_stem"
text_dir="$output_root/text/$pdf_stem"
combined_text="$text_dir/$pdf_stem.txt"

rm -rf "$render_dir" "$image_dir" "$text_dir"
mkdir -p "$render_dir" "$image_dir" "$text_dir"

pdftoppm -r "${BLOTTER_PDF_DPI:-200}" -png "$pdf_path" "$render_dir/page"

# Extract original embedded images when the PDF contains them. This complements
# rendered pages above, which are still used for OCR.
if ! pdfimages -all "$pdf_path" "$image_dir/image" >/dev/null 2>&1; then
  echo "Warning: unable to extract embedded images from $pdf_name" >&2
fi

shopt -s nullglob
page_images=("$render_dir"/page-*.png)
if [[ ${#page_images[@]} -eq 0 ]]; then
  echo "No rendered page images found for $pdf_name" >&2
  exit 65
fi

: > "$combined_text"
for img in "${page_images[@]}"; do
  out_base="$text_dir/$(basename "${img%.png}")"
  tesseract "$img" "$out_base" -l "${BLOTTER_TESSERACT_LANG:-eng}" >/dev/null 2>&1
  cat "$out_base.txt" >> "$combined_text"
  printf '\n' >> "$combined_text"
done

cat "$combined_text"
