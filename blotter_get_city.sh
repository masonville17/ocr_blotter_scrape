#!/bin/bash
# gets grand junction city blotter reports, ocrs them and cat-pipes textfile to less

pdf_cwd="/home/$USER/ocr_blotter_scrape"
pdf_tmp="$pdf_cwd/tmp"
mkdir_result=$(mkdir -p "$pdf_tmp")
result_file="result.txt"
cd "$pdf_cwd"
echo "" > "$pdf_cwd/result.txt"
rm_pdfs=$(rm -rf *PDF* && rm -rf ./tmp/*.pdf)

# Base URL of the website
base_url="https://www.gjcity.org"

# URL of the police blotter page
blotter_page="$base_url/877/Police-Blotter"

# Temporary file to store the HTML content
temp_file=$(mktemp)

# Fetch the webpage
wget -q -O "$temp_file" "$blotter_page"

# Maximum number of files to download (default: unrequest_limited)
request_limit=3
# request_counter to track the number of downloads
request_counter=0

# Extract links to the PDFs
grep -oP '(?<=<a target="_blank" href=")/DocumentCenter/View/\d+/[^"]+' "$temp_file" |
while read -r requested_path; do
    # Check if we've reached the request_limit
    if [[ $request_limit -gt 0 && $request_counter -ge $request_limit ]]; then
        echo "Download request_limit of $request_limit reached. Exiting."
        break
    fi

    # Construct the full URL
    interpolated_url="${base_url}${requested_path}"

    # Extract the pdf_filename from the URL
    pdf_filename=$(basename "$requested_path")

    # Download the PDF if it doesn't already exist
    if [[ ! -f "$pdf_filename" ]]; then
        echo "Downloading $interpolated_url..."
        curl -L -o "$pdf_filename" "$interpolated_url"
        
        # Verify the file is not empty
        if [[ ! -s "$pdf_filename" ]]; then
            echo "Error downloading $interpolated_url. File is empty."
            rm "$pdf_filename"
        else
            # Increment the request_counter for successful downloads
            request_counter=$((request_counter + 1))
        fi
    else
        echo "$pdf_filename already exists, skipping."
    fi
done

# Cleanup
rm "$temp_file"
for file in *PDF*; do
  if [[ -f "$file" ]]; then
    mv "$file" "${file// /_}.pdf"
  fi
done
mv_pdfs=$(mv ./*.pdf ./tmp)
for pdf in ./tmp/*.pdf; do
	echo "$(./pdf2text.sh $pdf)" >> "$pdf_cwd/result.txt"
done
grep '.\{14,\}' "$pdf_cwd/result.txt" > "$pdf_cwd/result.txt.tmp" && mv "$pdf_cwd/result.txt.tmp" "$pdf_cwd/result.txt"

cat "$pdf_cwd/result.txt" | less


