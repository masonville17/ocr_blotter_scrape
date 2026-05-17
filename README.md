# ocr_blotter_scrape

Small shell scripts for downloading recent PDF blotter reports, rendering them to page images, OCRing them with
Tesseract, and printing cleaned text for a much nicer reading experience or analysis.

## Defaults and Switching to Your Locality

By default this script is pointed at Grand Junction Police and Mesa County Sheriff, but I've found other localities that work with this project.

To use it for a different city or county:

1. **Find the correct blotter PDF URLs** for your local police or sheriff's office. Many agencies publish daily or weekly blotter/activity reports in PDF format on their websites.
2. **Edit the script URLs:**
	- Open `blotter_get_city.sh` or `blotter_get_county.sh` in a text editor.
	- Replace the default Grand Junction or Mesa County URLs with those for your locality.
3. **Save and run the script** as usual.

**Tip:** If your locality uses a different report format, you may need to adjust the parsing logic in the scripts. Most agencies with similar PDF layouts will work with minimal changes.

**Tip:** The default county service is geofenced and is not available when using a VPN.

If you improve support for another locality, consider contributing your changes!

## Requirements

On Arch Linux:

```sh
sudo pacman -S curl poppler tesseract tesseract-data-eng
```

On Debian/Ubuntu:

```sh
sudo apt install curl poppler-utils tesseract-ocr tesseract-ocr-eng
```

Poppler provides both `pdftoppm` and `pdfimages`.

## Install

Clone the repo wherever you want. The scripts now locate the repo from their own
path, so the folder no longer has to live at `~/ocr_blotter_scrape`.

```sh
git clone https://github.com/masonville17/ocr_blotter_scrape.git
cd ocr_blotter_scrape
```

Recommended: symlink the commands into a directory on your `PATH`:

```sh
sudo ln -sf "$PWD/blotter_get_city.sh" /usr/local/bin/blotter_get_city
sudo ln -sf "$PWD/blotter_get_county.sh" /usr/local/bin/blotter_get_county
```

If you copy the scripts instead of symlinking them, set `BLOTTER_REPO_DIR` to the
repo path so they can find `pdf2text.sh`.

## Usage

Fetch the latest 3 city blotter PDFs:

```sh
./blotter_get_city.sh
```

Fetch the latest 3 Mesa County daily activity PDFs:

```sh
./blotter_get_county.sh
```

Pass a number to change the request limit:

```sh
./blotter_get_city.sh 1
./blotter_get_county.sh 5
```

Use `0` for no limit. Please keep this reasonable and within terms of service.

County report type can be changed with `BLOTTER_COUNTY_REPORT_TYPE`:

```sh
BLOTTER_COUNTY_REPORT_TYPE=booking blotter_get_county
BLOTTER_COUNTY_REPORT_TYPE=all blotter_get_county
```

Valid values are `activity`, `booking`, and `all`.

## Output

By default the combined OCR text is written to `result.txt` in the repo and then printed. Intermediate files are kept under `tmp/`:

```text
tmp/pdfs/
tmp/ocr/city/rendered_pages/
tmp/ocr/city/extracted_images/
tmp/ocr/city/text/
tmp/ocr/county/rendered_pages/
tmp/ocr/county/extracted_images/
tmp/ocr/county/text/
```

Useful environment variables:

```sh
BLOTTER_WORKDIR=/path/to/output       # where result.txt and tmp/ are written
BLOTTER_RESULT_FILE=/path/result.txt  # exact text output path
BLOTTER_REPO_DIR=/path/to/repo        # needed if scripts are copied elsewhere
BLOTTER_REQUEST_LIMIT=3               # default download count
BLOTTER_COUNTY_GENERATE_DAYS=30       # fallback county URL search window
BLOTTER_NO_LESS=1                     # print directly instead of opening less
BLOTTER_PDF_DPI=200                   # render DPI for OCR page images
BLOTTER_TESSERACT_LANG=eng            # OCR language
```

The county script visits the Mesa County parent page before requesting the
blotter app, sends browser-like headers, and falls back to generated PDF URLs if
the listing page does not respond.

## Notes

These reports are public records, but please keep request counts low and use the
data responsibly. The defaults intentionally fetch only a few recent PDFs.
