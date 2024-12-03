# ocr_blotter_scrape
---
scrapes county and city pdf blotter reports converts to images, then ocrs them, and prints extracted text for easier reading or analysis purposes.

#### with a single-line modification, this can be used to automatically track, measure, or analyze any other reports, like financialn records, upcoming ballot items, BOLs, or even parking ticket fees 

## SETUP
---
need to be on arch linux, debian-based distro, such as ubuntu, mx linux or a thousand others, as long as requisites can be installed.

### REQUISITE SOFTWARE / LIBRARIES:
---
imagemagick for pdf preprocessing
> pacman -S imagemagick

pdftoppm / poppler / libpoppler for pdf to png conversion
> pacman -S poppler

tesseract and tesseract-data-eng for OCR'ing images to text, english text recognition
> pacman -S tesseract tesseract-data-eng

## INSTALLING: 
1. Clone this repo to your home directory in folder, called ocr_blotter_scrape 

> git clone https://github.com/masonville17/ocr_blotter_scrape ~/ocr_blotter_scrape

2. Then add this to your $PATH or copy the county/city scripts into a folder already on path.

> sudo cp ~/ocr_blotter_scrape/blotter_get_city.sh /usr/bin/blotter_get_city && sudo chmod +x /usr/bin/blotter_get_city

> sudo cp ~/ocr_blotter_scrape/blotter_get_county.sh /usr/bin/blotter_get_county && sudo chmod +x /usr/bin/blotter_get_county

## USING:
to get latest 3 county blotter records in plaintext format:

> blotter_get_county

to get latest 3 city blotter records in plaintext format:

> blotter_get_city

## MODIFICATION and NOTES:
MODIFY THIS- at your own peril, but if you're a tinkerer, it's pretty easy to get any number of public records for analysis/measurement/statistics/information. just don't ask me.

PLEASE- dont do any egregious full-scraping of these resources. it's nice that they are available, so don't abuse the system or they might not be in the same way that we see them now. Use legally and reasonably, and keep your requests count low, and request_limits low. These default to 3-per.

NOTE- This tool is intended to be used for personal, legal purposes. use responsibly and only for purposes / within request_limitations described by the law.

