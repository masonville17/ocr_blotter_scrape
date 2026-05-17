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
  for cmd in curl grep sed awk head basename mktemp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "Missing required command: $cmd" >&2
      exit 127
    fi
  done
}

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

base_url="https://apps.mesacounty.us"
blotter_page="$base_url/so-blotter-reports/"
temp_file="$(mktemp)"
trap 'rm -f "$temp_file"' EXIT

mkdir -p "$pdf_dir" "$ocr_dir"
rm -rf "$pdf_dir" "$ocr_dir"
mkdir -p "$pdf_dir" "$ocr_dir" "$(dirname "$result_file")"
: > "$result_file"

curl --fail --location --silent --show-error \
  --connect-timeout "${BLOTTER_CONNECT_TIMEOUT:-15}" \
  --max-time "${BLOTTER_MAX_TIME:-90}" \
  --retry "${BLOTTER_RETRIES:-2}" \
  --user-agent "ocr_blotter_scrape/1.0" \
  --output "$temp_file" \
  "$blotter_page"

mapfile -t pdf_urls < <(
  grep -Eo 'href="[^"]+"' "$temp_file" |
    sed -E 's/^href="//; s/"$//; s/&amp;/\&/g' |
    grep -Ei '\.pdf([?#].*)?$' |
    while IFS= read -r href; do normalize_url "$href"; done |
    filter_county_urls |
    awk '!seen[$0]++' |
    { if (( request_limit > 0 )); then head -n "$request_limit"; else cat; fi; }
)

if [[ ${#pdf_urls[@]} -eq 0 ]]; then
  echo "No county PDFs found at $blotter_page" >&2
  exit 69
fi

for pdf_url in "${pdf_urls[@]}"; do
  pdf_file="$pdf_dir/$(safe_pdf_name "$pdf_url")"
  echo "Downloading $pdf_url..." >&2
  curl --fail --location --silent --show-error \
    --connect-timeout "${BLOTTER_CONNECT_TIMEOUT:-15}" \
    --max-time "${BLOTTER_MAX_TIME:-90}" \
    --retry "${BLOTTER_RETRIES:-2}" \
    --user-agent "ocr_blotter_scrape/1.0" \
    --output "$pdf_file" \
    "$pdf_url"

  if [[ ! -s "$pdf_file" ]]; then
    echo "Downloaded file is empty: $pdf_url" >&2
    rm -f "$pdf_file"
    continue
  fi

  bash "$repo_dir/pdf2text.sh" "$pdf_file" "$ocr_dir" >> "$result_file"
  printf '\n' >> "$result_file"
done

awk 'length($0) >= 14 && $0 != "State"' "$result_file" > "$result_file.tmp" && mv "$result_file.tmp" "$result_file"
print_result
