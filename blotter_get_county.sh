#!/usr/bin/env bash
set -euo pipefail

# Gets Mesa County Sheriff's Office blotter reports, OCRs them, and prints text.

script_path="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s\n' "${BASH_SOURCE[0]}")"
script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd -P)"

find_repo_dir() {
  local candidate
  for candidate in "${BLOTTER_REPO_DIR:-}" "$script_dir" "$PWD" "$HOME/ocr_blotter_scrape"; do
    if [[ -n "$candidate" && -f "$candidate/pdf2text.sh" ]]; then
      cd "$candidate" && pwd -P
      return
    fi
  done

  echo "Could not locate pdf2text.sh. Run from the repo or set BLOTTER_REPO_DIR." >&2
  exit 72
}

require_cmds() {
  local cmd
  for cmd in curl date grep sed awk head basename mktemp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Missing required command: $cmd" >&2
      exit 127
    fi
  done
}

curl_browser_args=(
  --location
  --silent
  --show-error
  --compressed
  --http1.1
  --connect-timeout "${BLOTTER_CONNECT_TIMEOUT:-15}"
  --max-time "${BLOTTER_MAX_TIME:-90}"
  --retry "${BLOTTER_RETRIES:-2}"
  --user-agent "${BLOTTER_USER_AGENT:-Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36}"
  --header "Accept-Language: en-US,en;q=0.9"
  --header "Cache-Control: no-cache"
)

normalize_url() {
  local href="$1"
  case "$href" in
    http://*|https://*) printf '%s\n' "$href" ;;
    //*) printf 'https:%s\n' "$href" ;;
    /*) printf '%s%s\n' "$base_url" "$href" ;;
    *) printf '%s/%s\n' "$base_url" "$href" ;;
  esac
}

safe_pdf_name() {
  local url_path file_name
  url_path="${1%%\?*}"
  file_name="$(basename "$url_path")"
  file_name="${file_name//%20/_}"
  file_name="$(printf '%s' "$file_name" | sed -E 's/[^A-Za-z0-9._-]+/_/g; s/_+/_/g; s/^_//; s/_$//')"
  case "$file_name" in
    *.[Pp][Dd][Ff]) ;;
    *) file_name="$file_name.pdf" ;;
  esac
  printf '%s\n' "$file_name"
}

filter_county_urls() {
  case "$county_report_type" in
    activity|daily)
      grep -Ei '/daily(%20|[ _+-])*activity/'
      ;;
    booking|jail)
      grep -Ei '/booking(%20|[ _+-])*summary/'
      ;;
    all)
      cat
      ;;
    *)
      echo "Unknown BLOTTER_COUNTY_REPORT_TYPE: $county_report_type" >&2
      echo "Use activity, booking, or all." >&2
      exit 64
      ;;
  esac
}

generated_county_urls() {
  local days offset report_date
  days="${BLOTTER_COUNTY_GENERATE_DAYS:-30}"

  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo "BLOTTER_COUNTY_GENERATE_DAYS must be a non-negative integer: $days" >&2
    exit 64
  fi

  for ((offset = 0; offset < days; offset++)); do
    report_date="$(date -d "-$offset day" +%F)"
    case "$county_report_type" in
      activity|daily)
        printf '%s/mcweb/so/daily%%20activity/MCSO%%20Daily%%20Resume%%20%s.pdf\n' "$base_url" "$report_date"
        ;;
      booking|jail)
        printf '%s/mcweb/so/booking%%20summary/Mesa%%20County%%20Jail%%20Records%%20%%283%%29%%20%s.pdf\n' "$base_url" "$report_date"
        ;;
      all)
        printf '%s/mcweb/so/booking%%20summary/Mesa%%20County%%20Jail%%20Records%%20%%283%%29%%20%s.pdf\n' "$base_url" "$report_date"
        printf '%s/mcweb/so/daily%%20activity/MCSO%%20Daily%%20Resume%%20%s.pdf\n' "$base_url" "$report_date"
        ;;
      *)
        echo "Unknown BLOTTER_COUNTY_REPORT_TYPE: $county_report_type" >&2
        echo "Use activity, booking, or all." >&2
        exit 64
        ;;
    esac
  done
}

print_result() {
  if [[ -t 1 && "${BLOTTER_NO_LESS:-0}" != "1" ]] && command -v less >/dev/null 2>&1; then
    less "$result_file"
  else
    cat "$result_file"
  fi
}

require_cmds

repo_dir="$(find_repo_dir)"
work_dir="${BLOTTER_WORKDIR:-$repo_dir}"
tmp_dir="$work_dir/tmp"
pdf_dir="$tmp_dir/pdfs/county"
ocr_dir="$tmp_dir/ocr/county"
result_file="${BLOTTER_RESULT_FILE:-$work_dir/result.txt}"
request_limit="${1:-${BLOTTER_REQUEST_LIMIT:-3}}"
county_report_type="${BLOTTER_COUNTY_REPORT_TYPE:-activity}"

if ! [[ "$request_limit" =~ ^[0-9]+$ ]]; then
  echo "Request limit must be a non-negative integer: $request_limit" >&2
  exit 64
fi


# URLs
base_url="https://apps.mesacounty.us"
blotter_page="$base_url/so-blotter-reports/"
parent_page="https://www.mesacounty.us/departments-and-services/sheriff/services/blotter-reports"

# Temp files
temp_file="$(mktemp)"
cookie_file="$(mktemp)"
trap 'rm -f "$temp_file" "$cookie_file"' EXIT

mkdir -p "$pdf_dir" "$ocr_dir"
rm -rf "$pdf_dir" "$ocr_dir"
mkdir -p "$pdf_dir" "$ocr_dir" "$(dirname "$result_file")"
: > "$result_file"


# Step 1: Visit parent page first, matching how a normal browser reaches the app.
if ! curl --fail "${curl_browser_args[@]}" \
  --header "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
  --cookie-jar "$cookie_file" \
  "$parent_page" >/dev/null; then
  echo "Warning: county parent page did not respond; trying the app directly." >&2
fi

# Step 2: Fetch the actual blotter page using the browser-like request context.
if ! curl --fail "${curl_browser_args[@]}" \
  --header "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" \
  --cookie "$cookie_file" \
  --cookie-jar "$cookie_file" \
  --referer "$parent_page" \
  --output "$temp_file" \
  "$blotter_page"; then
  echo "Warning: county listing page did not respond; trying generated PDF URLs." >&2
  : > "$temp_file"
fi

mapfile -t pdf_urls < <(
  grep -Eo 'href="[^"]+"' "$temp_file" |
    sed -E 's/^href="//; s/"$//; s/&amp;/\&/g' |
    grep -Ei '\.pdf([?#].*)?$' |
    while IFS= read -r href; do normalize_url "$href"; done |
    filter_county_urls |
    awk '!seen[$0]++'
)

if [[ ${#pdf_urls[@]} -eq 0 ]]; then
  mapfile -t pdf_urls < <(generated_county_urls)
fi

download_count=0

for pdf_url in "${pdf_urls[@]}"; do
  if (( request_limit > 0 && download_count >= request_limit )); then
    break
  fi

  pdf_file="$pdf_dir/$(safe_pdf_name "$pdf_url")"
  echo "Downloading $pdf_url..." >&2
  if ! curl --fail "${curl_browser_args[@]}" \
    --header "Accept: application/pdf,application/octet-stream,*/*;q=0.8" \
    --cookie "$cookie_file" \
    --cookie-jar "$cookie_file" \
    --referer "$blotter_page" \
    --output "$pdf_file" \
    "$pdf_url"; then
    echo "Warning: failed to download $pdf_url" >&2
    rm -f "$pdf_file"
    continue
  fi

  if [[ ! -s "$pdf_file" ]]; then
    echo "Downloaded file is empty: $pdf_url" >&2
    rm -f "$pdf_file"
    continue
  fi

  bash "$repo_dir/pdf2text.sh" "$pdf_file" "$ocr_dir" >> "$result_file"
  printf '\n' >> "$result_file"
  download_count=$((download_count + 1))
done

if (( download_count == 0 )); then
  echo "No county PDFs could be downloaded from $blotter_page or generated PDF URLs." >&2
  exit 69
fi

awk 'length($0) >= 14 && $0 != "State"' "$result_file" > "$result_file.tmp" && mv "$result_file.tmp" "$result_file"
print_result
