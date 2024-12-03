#!/bin/bash
# gets mesa county blotter reports, ocrs them and cat-pipes textfile to less

pdf_cwd="/home/$USER/ocr_blotter_scrape"
pdf_tmp="$pdf_cwd/tmp"
mkdir_result=$(mkdir -p "$pdf_tmp")
result_file="result.txt"

cd "$pdf_cwd"
echo "" > "$pdf_cwd/result.txt"
rm_pdfs=$(rm -rf ./*.pdf && rm -rf ./tmp/*.pdf)

wget -r -l1 -nd -A "*.pdf" --spider "https://apps.mesacounty.us/so-blotter-reports/" 2>&1 | \
grep -oP 'https?://[^\s"]+\.pdf' | \
head -n 3 | \
xargs -n 1 wget

for file in *.pdf; do
  if [[ -f "$file" ]]; then
    mv "$file" "${file// /_}"
  fi
done

mv_pdfs=$(mv ./*.pdf ./tmp)

for pdf in ./tmp/*.pdf; do
	echo "$(./pdf2text.sh $pdf)" >> "$pdf_cwd/result.txt"
done
sed -i '/^State$/d' "$pdf_cwd/result.txt"
sed -i '/^$/d' "$pdf_cwd/result.txt"

grep '.\{14,\}' "$pdf_cwd/result.txt" > "$pdf_cwd/result.txt.tmp" && mv "$pdf_cwd/result.txt.tmp" "$pdf_cwd/result.txt"


cat "$pdf_cwd/result.txt" | less

