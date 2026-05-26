#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OTP_DIR="${OTP_DIR:-$ROOT_DIR/data/raw/otp}"
GRAPH_DIR="$OTP_DIR/graph"
GTFS_DIR="$GRAPH_DIR"
NAP_LIST_URL="${NAP_LIST_URL:-https://nap.transportes.gob.es/Files/List?showFilterTT=False&filterTT=1&filterTT=2&showFilterR=False&filterC=3&filterR=33&filterC=6&filterR=39&filterC=7&filterR=5&filterR=9&filterR=24&filterR=34&filterR=37&filterR=40&filterR=42&filterR=47&filterR=49&filterC=8&filterR=2&filterR=13&filterR=16&filterR=19&filterR=45&filterC=12&filterR=15&filterR=27&filterR=32&filterR=36&filterC=13&filterR=28&filterC=16&filterR=1&filterR=20&filterR=48&filterC=17&filterR=26&showfilterAU=true&filterAU=78&filterAU=5&filterAU=34&filterAU=7&filterAU=18&filterAU=44&filterAU=30&filterAU=57&filterAU=1&filterAU=46&filterAU=55&filterAU=32&filterAU=22&filterAU=68&filterAU=82&filterAU=19&showFilterTF=False&search=autob%C3%BAs&orderby=Relevancia&page=1}"
NAP_MAX_PAGES="${NAP_MAX_PAGES:-5}"

mkdir -p "$GTFS_DIR"

download_if_missing() {
  local url="$1"
  local output="$2"
  if [ -s "$output" ]; then
    printf '[otp-download] existe: %s\n' "$output"
    return 0
  fi
  printf '[otp-download] descargando: %s\n' "$url"
  curl -L --fail --retry 3 --retry-delay 2 "$url" -o "$output"
}

download_if_missing "https://download.geofabrik.de/europe/spain/castilla-y-leon-latest.osm.pbf" "$GRAPH_DIR/castilla-y-leon-latest.osm.pbf"
download_if_missing "https://download.geofabrik.de/europe/spain/madrid-latest.osm.pbf" "$GRAPH_DIR/madrid-latest.osm.pbf"
download_if_missing "https://ssl.renfe.com/ftransit/Fichero_CER_FOMENTO/fomento_transit.zip" "$GTFS_DIR/renfe_cercanias.gtfs.zip"
download_if_missing "https://ssl.renfe.com/gtransit/Fichero_AV_LD/google_transit.zip" "$GTFS_DIR/renfe_media_larga.gtfs.zip"

NAP_HTML="$OTP_DIR/nap_burgos_madrid_list.html"
NAP_MANIFEST="$OTP_DIR/nap_burgos_madrid_candidates.tsv"
printf '[otp-download] leyendo listado NAP Burgos/Madrid...\n'
rm -f "$OTP_DIR"/nap_burgos_madrid_list_page_*.html
for page in $(seq 1 "$NAP_MAX_PAGES"); do
  page_url="$(python3 - "$NAP_LIST_URL" "$page" <<'PY'
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
import sys
url, page = sys.argv[1:3]
parts = urlsplit(url)
query = [(k, v) for k, v in parse_qsl(parts.query, keep_blank_values=True) if k != 'page']
query.append(('page', page))
print(urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment)))
PY
)"
  page_file="$OTP_DIR/nap_burgos_madrid_list_page_${page}.html"
  curl -L --fail "$page_url" -o "$page_file"
done
cat "$OTP_DIR"/nap_burgos_madrid_list_page_*.html > "$NAP_HTML"

python3 - "$NAP_HTML" "$NAP_MANIFEST" <<'PY'
from html.parser import HTMLParser
import html
import re
import sys

html_path, manifest_path = sys.argv[1:3]
text = open(html_path, encoding='utf-8', errors='ignore').read()

class Parser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.cards = []
        self.in_card = False
        self.current_href = None
        self.current_text = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'a' and 'item-listado' in attrs.get('class', ''):
            self.in_card = True
            self.current_href = attrs.get('href', '')
            self.current_text = []

    def handle_endtag(self, tag):
        if tag == 'a' and self.in_card:
            label = re.sub(r'\s+', ' ', html.unescape(' '.join(self.current_text))).strip()
            self.cards.append((self.current_href, label))
            self.in_card = False

    def handle_data(self, data):
        if self.in_card:
            self.current_text.append(data)

parser = Parser()
parser.feed(text)

with open(manifest_path, 'w', encoding='utf-8') as out:
    out.write('detail_id\tdetail_url\tlabel\n')
    for href, label in parser.cards:
        m = re.search(r'Detail/(\d+)', href)
        if not m:
            continue
        detail_id = m.group(1)
        out.write(f'{detail_id}\thttps://nap.transportes.gob.es/Files/Detail/{detail_id}\t{label}\n')

print(f'[otp-download] candidatos NAP guardados: {manifest_path} ({len(parser.cards)} tarjetas)')
PY

cat <<EOF
[otp-download] Inputs base preparados en: $GRAPH_DIR
[otp-download] NAP requiere login para descargar los GTFS-ZIP desde la web.
[otp-download] Revisa candidatos en: $NAP_MANIFEST
[otp-download] Si descargas feeds NAP manualmente, guarda los .zip como *.gtfs.zip en: $GTFS_DIR
EOF
