#!/bin/sh
# Records the pages the `recorded` scenario replays. Reads the key from Config/Secrets.xcconfig, never prints it,
# and keeps only the fields the app uses. Costs four API requests.
set -eu
cd "$(dirname "$0")/.." || exit 1
KEY=$(sed -n 's/^UNSPLASH_ACCESS_KEY *= *//p' Config/Secrets.xcconfig | tr -d '[:space:]')
OUTPUT=Packages/FramesKit/Sources/MockServices/Resources
FIELDS='{id, description, alt_description, width, height, color, urls: {thumb: .urls.thumb, small: .urls.small, regular: .urls.regular}, user: {name: .user.name, links: {html: .user.links.html}}}'
RESPONSE=$(mktemp)
fetch() {
  STATUS=$(curl -s -o "$RESPONSE" -w "%{http_code}" -H "Authorization: Client-ID $KEY" -H "Accept-Version: v1" "https://api.unsplash.com$1")
  if [ "$STATUS" != "200" ]; then
    echo "Request failed with HTTP $STATUS: $(cat "$RESPONSE")" >&2
    exit 1
  fi
}
for page in 1 2 3; do
  fetch "/photos?page=$page&per_page=30"
  jq "[.[] | $FIELDS]" "$RESPONSE" > "$OUTPUT/editorial-$page.json"
done
fetch "/search/photos?query=nature&page=1&per_page=30"
jq "{total: .total, total_pages: .total_pages, results: [.results[] | $FIELDS]}" "$RESPONSE" > "$OUTPUT/search.json"
rm -f "$RESPONSE"
echo "Recorded $(ls "$OUTPUT" | wc -l | tr -d ' ') files in $OUTPUT"
