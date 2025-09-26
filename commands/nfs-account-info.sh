#!/bin/bash

# NearlyFreeSpeech.NET Account Information Script

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"

fetch_account_metric() {
    local endpoint="$1"
    if ! make_api_call "GET" "$endpoint" "" "account" "$NFS_ACCOUNT_ID"; then
        return 1
    fi

    if [[ $API_STATUS != "200" ]]; then
        log_error "Failed to fetch $endpoint (HTTP $API_STATUS)"
        log_info "Response: $API_BODY"
        return 1
    fi

    printf '%s' "$API_BODY"
}

show_account_info() {
    echo ""
    echo -e "${CYAN}=== Account Information ===${NC}"
    echo ""

    echo -e "${MAGENTA}Account Balance:${NC}"
    echo "════════════════════════════════════════"

    local balance balance_cash balance_credit balance_high

    balance=$(fetch_account_metric "balance") || return 1
    balance_cash=$(fetch_account_metric "balanceCash") || return 1
    balance_credit=$(fetch_account_metric "balanceCredit") || return 1
    balance_high=$(fetch_account_metric "balanceHigh") || return 1

    printf "%-20s %s\n" "Current Balance:" "\$${balance}"
    printf "%-20s %s\n" "Cash Balance:" "\$${balance_cash}"
    printf "%-20s %s\n" "Credit Balance:" "\$${balance_credit}"
    printf "%-20s %s\n" "Highest Balance:" "\$${balance_high}"

    if [[ "$balance_high" != "0" && "$balance_high" != "0.00" ]]; then
        local percentage
        percentage=$(echo "scale=1; $balance * 100 / $balance_high" | bc 2>/dev/null || printf 'N/A')
        printf "%-20s %s%%\n" "% of High Mark:" "$percentage"
    fi

    echo ""
    log_success "Account information retrieved"
}

main() {
    if ! ensure_dependencies jq curl openssl bc; then
        exit 1
    fi

    if ! prompt_for_credentials; then
        exit 1
    fi

    show_account_info
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
