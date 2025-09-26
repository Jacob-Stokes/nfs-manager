#!/bin/bash

# Exercise the NearlyFreeSpeech authentication header construction.

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"

main() {
    if ! ensure_dependencies jq curl openssl; then
        exit 1
    fi

    if ! prompt_for_credentials; then
        exit 1
    fi

    local domain="${1:-${DEFAULT_DOMAIN:-yourdomain.com}}"
    local uri="/dns/$domain/listRRs"
    local body=""

    local body_hash
    body_hash=$(printf %s "$body" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')

    local auth_header
    auth_header=$(create_auth_header "POST" "$uri" "$body")

    IFS=';' read -r header_login header_timestamp header_salt header_hash <<<"$auth_header"

    echo "=== NearlyFreeSpeech Auth Test ==="
    echo "Username:  $NFS_USERNAME"
    echo "Domain:    $domain"
    echo "Timestamp: $header_timestamp"
    echo "Salt:      $header_salt"
    echo "URI:       $uri"
    echo "Body hash: $body_hash"
    echo "Hash:      $header_hash"
    echo "Header:    $auth_header"
    echo ""
    echo "Making API request..."

    local response
    if ! response=$(curl -sS -w "\nHTTP: %{http_code}" -H "X-NFSN-Authentication: $auth_header" -X POST "https://api.nearlyfreespeech.net$uri"); then
        log_error "Curl failed"
        return 1
    fi

    echo "$response"
    echo ""
    echo "=== Test Complete ==="
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
