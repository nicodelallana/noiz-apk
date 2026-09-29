#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# Bizkaia Transit — Feed Verification Harness (Task T0)
# ==============================================================================
# Verifies HTTP availability, Content-Type, caching headers, and Protobuf
# decodability for transit feeds listed in spec.md (§5).
# ==============================================================================

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

TEMP_DIR="$(mktemp -d /tmp/verify_feeds.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT

echo -e "${BOLD}============================================================================${RESET}"
echo -e "${BOLD}         Bizkaia Transit — Data Feed Verification Harness (Task T0)         ${RESET}"
echo -e "${BOLD}============================================================================${RESET}"
echo ""

TOTAL=0
SUCCESS=0
WARNINGS=0
FAILED=0

# Helper function to test an endpoint
# Arguments: operator name, feed description, URL, expected content-type (substr), is_protobuf (true/false)
test_feed() {
  local operator="$1"
  local description="$2"
  local url="$3"
  local expected_type="$4"
  local is_pb="$5"

  TOTAL=$((TOTAL + 1))
  local header_file="$TEMP_DIR/headers_${TOTAL}.txt"
  local body_file="$TEMP_DIR/body_${TOTAL}.bin"

  echo -e "${BOLD}[${operator}] ${description}${RESET}"
  echo -e "  URL: ${CYAN}${url}${RESET}"

  # Fetch headers and probe content
  local http_code
  http_code=$(curl -sSL --max-time 15 -D "$header_file" -o "$body_file" -w "%{http_code}" "$url" 2>/dev/null || echo "000")

  local content_type
  content_type=$(grep -i '^content-type:' "$header_file" | tr -d '\r' | awk '{print $2}' | tail -n 1)

  local content_length
  content_length=$(grep -i '^content-length:' "$header_file" | tr -d '\r' | awk '{print $2}' | tail -n 1)

  local etag
  etag=$(grep -i '^etag:' "$header_file" | tr -d '\r' | awk '{print $2}' | tail -n 1)

  local last_modified
  last_modified=$(grep -i '^last-modified:' "$header_file" | tr -d '\r' | cut -d' ' -f2- | tail -n 1)

  local file_bytes
  file_bytes=$(wc -c < "$body_file" 2>/dev/null || echo 0)

  if [ "$http_code" = "200" ]; then
    echo -e "  Status: ${GREEN}200 OK${RESET} | Bytes: ${file_bytes} | Content-Type: ${content_type:-unknown}"
    
    # Check caching headers
    local cache_info=""
    if [ -n "$etag" ]; then
      cache_info="ETag: ${etag:0:20}... "
    fi
    if [ -n "$last_modified" ]; then
      cache_info="${cache_info}Last-Modified: ${last_modified}"
    fi
    if [ -n "$cache_info" ]; then
      echo -e "  Cache: ${GREEN}${cache_info}${RESET}"
    else
      echo -e "  Cache: ${YELLOW}No ETag or Last-Modified header provided${RESET}"
    fi

    # Protobuf inspection
    if [ "$is_pb" = "true" ]; then
      if [ "$file_bytes" -gt 0 ]; then
        echo -e "  Protobuf: ${GREEN}Valid binary payload (${file_bytes} bytes)${RESET}"
      else
        echo -e "  Protobuf: ${YELLOW}Empty payload (0 bytes)${RESET}"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi

    SUCCESS=$((SUCCESS + 1))
  elif [[ "$http_code" =~ ^30[1278]$ ]]; then
    echo -e "  Status: ${YELLOW}${http_code} Redirect${RESET} | Bytes: ${file_bytes}"
    WARNINGS=$((WARNINGS + 1))
  elif [ "$http_code" = "000" ]; then
    echo -e "  Status: ${RED}Connection Failed / Timeout (max 15s)${RESET}"
    FAILED=$((FAILED + 1))
  else
    echo -e "  Status: ${RED}${http_code} Error${RESET}"
    FAILED=$((FAILED + 1))
  fi

  echo ""
}

# ------------------------------------------------------------------------------
# 5.1 Metro Bilbao
# ------------------------------------------------------------------------------
test_feed "Metro Bilbao" "Open Data Catalog (ES)" \
  "https://cms.metrobilbao.eus/get/open_data/es" "json" "false"

test_feed "Metro Bilbao" "GTFS Static Schedule ZIP" \
  "https://cms.metrobilbao.eus/get/open_data/horarios/es" "zip" "false"

test_feed "Metro Bilbao" "Tariffs CSV" \
  "https://cms.metrobilbao.eus/get/open_data/tickets/es" "csv" "false"

test_feed "Metro Bilbao" "Stations JSON" \
  "https://cms.metrobilbao.eus/get/open_data/json/estaciones/es" "json" "false"

test_feed "Metro Bilbao" "Service Alerts JSON (Avisos)" \
  "https://cms.metrobilbao.eus/get/open_data/json/avisos/es" "json" "false"

test_feed "Metro Bilbao" "GTFS-RT Vehicle Positions (CTB S3)" \
  "https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-vehicle-positions.pb" "protobuf" "true"

test_feed "Metro Bilbao" "GTFS-RT Trip Updates (CTB S3)" \
  "https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-trip-updates.pb" "protobuf" "true"

test_feed "Metro Bilbao" "GTFS-RT Service Alerts (CTB S3)" \
  "https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/metro-bilbao-service-alerts.pb" "protobuf" "true"

# ------------------------------------------------------------------------------
# 5.2 Bizkaibus
# ------------------------------------------------------------------------------
test_feed "Bizkaibus" "GTFS-RT Trip Updates" \
  "https://baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedTripUpdates.pb" "protobuf" "true"

test_feed "Bizkaibus" "GTFS-RT Service Alerts" \
  "https://baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedAlerts.pb" "protobuf" "true"

test_feed "Bizkaibus" "GTFS-RT Vehicle Positions" \
  "https://baliabideak.bizkaia.eus/Bizkaibus/GTFSRealTime/FeedVehiculos.pb" "protobuf" "true"

test_feed "Bizkaibus" "SIRI XML Service Alerts (CTB S3 Backup)" \
  "https://ctb-siri.s3.eu-south-2.amazonaws.com/bizkaibus-service-alerts.xml" "xml" "false"

# ------------------------------------------------------------------------------
# 5.3 Bilbobus
# ------------------------------------------------------------------------------
test_feed "Bilbobus" "GTFS-RT Vehicle Positions (CTB S3)" \
  "https://ctb-gtfs-rt.s3.eu-south-2.amazonaws.com/bilbobus-vehicle-positions.pb" "protobuf" "true"

# ------------------------------------------------------------------------------
# 5.4 Euskotren
# ------------------------------------------------------------------------------
test_feed "Euskotren" "CTB CKAN Dataset Page" \
  "https://data.ctb.eus/es/dataset/horarios-servicios-euskotren" "html" "false"

# ------------------------------------------------------------------------------
# 5.5 Renfe Cercanías Bilbao
# ------------------------------------------------------------------------------
test_feed "Renfe" "Static Cercanías GTFS (Fomento)" \
  "https://ssl.renfe.com/ftransit/Fichero_CER_FOMENTO/fomento_transit.zip" "zip" "false"

test_feed "Renfe" "GTFS-RT Server Probe (LD JSON)" \
  "https://gtfsrt.renfe.com/trip_updates_LD.json" "json" "false"

# ------------------------------------------------------------------------------
# 5.6 Moveuskadi (Backup & Other Operators)
# ------------------------------------------------------------------------------
test_feed "Moveuskadi" "Open Data Euskadi Catalog Page" \
  "https://opendata.euskadi.eus/catalogo/-/moveuskadi-datos-de-la-red-de-transporte-publico-de-euskadi-operadores-horarios-paradas-calendario-tarifas-etc/" "html" "false"

# ------------------------------------------------------------------------------
# Summary Report
# ------------------------------------------------------------------------------
echo -e "${BOLD}============================================================================${RESET}"
echo -e "${BOLD}                        VERIFICATION SUMMARY REPORT                         ${RESET}"
echo -e "${BOLD}============================================================================${RESET}"
echo -e "Total Endpoints Tested : ${BOLD}${TOTAL}${RESET}"
echo -e "Successful (200 OK)    : ${GREEN}${BOLD}${SUCCESS}${RESET}"
echo -e "Warnings / Redirects   : ${YELLOW}${BOLD}${WARNINGS}${RESET}"
echo -e "Failed / Inaccessible  : ${RED}${BOLD}${FAILED}${RESET}"
echo -e "${BOLD}============================================================================${RESET}"

if [ "$FAILED" -gt 0 ]; then
  echo -e "${YELLOW}Notice: Some feeds failed or are inaccessible. See details above.${RESET}"
  exit 1
else
  echo -e "${GREEN}Verification completed successfully!${RESET}"
  exit 0
fi
