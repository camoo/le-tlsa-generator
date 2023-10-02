#!/bin/bash
# Update/generate DANE and update cloudflare TLSA RECORD WHEN using LET'S ENCRYPT Certificate
# -------------------------------------------------------------------------
# Copyright (c) 2023 Camoo Sarl

#Using Renewal Configuration File:
#Alternatively, you can edit the renewal configuration file directly.
# For each domain, there is a separate configuration file located in /etc/letsencrypt/renewal/. The file would be named something like domain.com.conf.

# [renewalparams]
# post_hook = /etc/letsencrypt/renewal-hooks/post/update_cf_dns.sh
# -------------------------------------------------------------------------
show_usage() {
  echo "Usage: $0 --zone-id ZONE_ID --record-id RECORD_ID --api-token API_TOKEN"
  exit 1
}
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
  -z | --zone-id)
    ZONE_ID="$2"
    shift 2 # past argument and value
    ;;
  -r | --record-id)
    RECORD_ID="$2"
    shift 2 # past argument and value
    ;;
  -a | --api-token)
    API_TOKEN="$2"
    shift 2 # past argument and value
    ;;
  -h | --help)
    show_usage
    ;;
  *)
    echo "Unknown option: $key"
    show_usage
    ;;
  esac
done

# Check for mandatory arguments
if [ -z "$ZONE_ID" ] || [ -z "$RECORD_ID" ] || [ -z "$API_TOKEN" ]; then
  show_usage
fi

# Check Dependencies
for cmd in openssl curl hexdump wget; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: $cmd could not be found."
    exit 1
  fi
done

# Cloudflare API URL
API_URL="https://api.cloudflare.com/client/v4"

# The parameters for your TLSA record
USAGE="3"
SELECTOR="1"
MATCHING_TYPE="1"

MX_NAME=$(uname -n)
LE_PATH="/etc/letsencrypt/live"
LE_AUTH="x3"
LE_CROSS_SIGNED="lets-encrypt-${LE_AUTH}-cross-signed.pem"

# Check if file exists
if [ -e "$LE_CROSS_SIGNED" ]; then
  # Check if file is older than 60 days
  if find "$LE_CROSS_SIGNED" -type f -mtime +59 | grep -q .; then
    echo "The file $LE_CROSS_SIGNED exists and is older than 60 days. Replace it"
    # Downloading cross-signed certificate
    if ! wget "https://letsencrypt.org/certs/lets-encrypt-${LE_AUTH}-cross-signed.pem.txt" -O "${LE_CROSS_SIGNED}"; then
      echo "Error: Failed to download cross-signed certificate."
      exit 1
    fi

  else
    echo "The file $LE_CROSS_SIGNED exists but is not older than 60 days."
  fi
else
  echo "The file $LE_CROSS_SIGNED does not exist. Download it"
  # Downloading cross-signed certificate
  if ! wget "https://letsencrypt.org/certs/lets-encrypt-${LE_AUTH}-cross-signed.pem.txt" -O "${LE_CROSS_SIGNED}"; then
    echo "Error: Failed to download cross-signed certificate."
    exit 1
  fi

fi

echo "Checking if ${LE_CROSS_SIGNED} is not empty..."
if [ ! -s "${LE_CROSS_SIGNED}" ]; then
  echo "Error: ${LE_CROSS_SIGNED} file not found or is empty!"
  exit 1
fi

# Check the result of each command
if ! CERTIFICATE_DATA=$(openssl x509 -in "${LE_PATH}/${MX_NAME}/cert.pem" -noout -pubkey |
  openssl pkey -pubin -outform DER |
  openssl dgst -sha256 -binary |
  hexdump -ve '/1 "%02x"'); then
  echo "Error: Failed to execute openssl or hexdump command."
  exit 1
fi

# Update the DNS record with safer JSON data handling
RESPONSE=$(curl -s -X PUT "$API_URL/zones/$ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "$(printf '{"type":"TLSA","name":"_25._tcp.%s", "data":{"usage":"%s", "selector":"%s", "matching_type":"%s", "certificate":"%s"}}' "${MX_NAME}" "${USAGE}" "${SELECTOR}" "${MATCHING_TYPE}" "${CERTIFICATE_DATA}")")

# JSON parsing for response validation
if echo "${RESPONSE}" | grep -q '\"success\":true'; then
  echo "TLSA record updated successfully."
else
  echo "Failed to update TLSA record. Response: ${RESPONSE}"
  exit 1
fi

exit 0
