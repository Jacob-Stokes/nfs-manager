#!/bin/bash

# List DNS records for a domain.

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/dns.sh"

main() {
    if ! ensure_dependencies jq curl openssl; then
        exit 1
    fi

    if ! prompt_for_credentials; then
        exit 1
    fi

    local domain
    if [[ $# -gt 0 ]]; then
        domain="$1"
    else
        domain=$(select_domain_with_save) || exit 0
    fi

    if ! dns_fetch_records "$domain"; then
        exit 1
    fi

    dns_print_records_table "$domain" "$DNS_RECORDS"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
