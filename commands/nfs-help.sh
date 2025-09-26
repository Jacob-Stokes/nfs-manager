#!/bin/bash

# NearlyFreeSpeech.NET Help Script

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"

show_help() {
    echo ""
    echo -e "${CYAN}=== NearlyFreeSpeech Manager Help ===${NC}"
    echo ""
    echo "This toolkit offers a terminal-first workflow for the NearlyFreeSpeech.NET API."
    echo "Each task builds on shared helpers in \`modules/\` so credentials and formatting stay consistent."
    echo ""
    echo -e "${YELLOW}Highlights:${NC}"
    echo "  • Interactive manager: \`nfs-manager.sh\`"
    echo "  • Unified DNS flow: \`nfs-dns.sh\` (list, add, edit, delete)"
    echo "  • Domain shortcuts: \`nfs-domains.sh\`"
    echo "  • Account + sites: \`nfs-account-info.sh\`, \`nfs-sites-list.sh\`"
    echo ""
    echo -e "${YELLOW}Requirements:${NC}"
    echo "  • NearlyFreeSpeech.NET login, API key, and account ID"
    echo "  • CLI dependencies: jq, curl, openssl (bc for balance math)"
    echo ""
    echo -e "${YELLOW}Tips:${NC}"
    echo "  • Launch \`nfs-manager.sh\` for the main menu"
    echo "  • The DNS manager lets you stay within one domain while making multiple changes"
    echo "  • Saved domains live in \`.domains\`; settings go in \`.domain_settings\`"
    echo ""
    log_prompt "Press Enter to continue..."
    read -r
}

main() {
    show_help
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
