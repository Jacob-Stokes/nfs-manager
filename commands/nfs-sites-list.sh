#!/bin/bash

# NearlyFreeSpeech.NET Sites List Script

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"

show_sites() {
    echo ""
    echo -e "${CYAN}=== Sites ===${NC}"
    echo ""

    log_info "Fetching sites for $NFS_USERNAME..."

    if ! make_api_call "GET" "sites" "" "member" "$NFS_USERNAME"; then
        return 1
    fi

    if [[ $API_STATUS != "200" ]]; then
        log_error "Failed to retrieve sites (HTTP $API_STATUS)"
        log_info "Response: $API_BODY"
        return 1
    fi

    echo -e "${MAGENTA}Your Sites:${NC}"
    echo "════════════════════════════════════════"
    printf '%s' "$API_BODY" | jq -r '.[]' | nl -w2 -s'. '
    echo ""
    log_success "Sites retrieved successfully"
}

main() {
    if ! ensure_dependencies jq curl openssl; then
        exit 1
    fi

    if ! prompt_for_credentials; then
        exit 1
    fi

    show_sites
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
