#!/bin/bash

# Add a DNS record to a domain.

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

    dns_add_record "$domain"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
