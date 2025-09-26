#!/bin/bash

# NearlyFreeSpeech.NET configuration helper

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"

persist_to_bashrc() {
    local bashrc="$HOME/.bashrc"

    if [[ ! -f "$bashrc" ]]; then
        touch "$bashrc"
    fi

    if grep -q "NearlyFreeSpeech API Configuration" "$bashrc" 2>/dev/null; then
        if ! confirm "Overwrite existing NearlyFreeSpeech config in ~/.bashrc?" "n"; then
            log_info "Leaving existing configuration untouched"
            return
        fi
        sed -i '/# NearlyFreeSpeech API Configuration/,+3d' "$bashrc"
    fi

    {
        echo ""
        echo "# NearlyFreeSpeech API Configuration"
        echo "export NFS_USERNAME=\"$NFS_USERNAME\""
        echo "export NFS_API_KEY=\"$NFS_API_KEY\""
        echo "export NFS_ACCOUNT_ID=\"$NFS_ACCOUNT_ID\""
    } >>"$bashrc"

    log_success "Credentials saved to $bashrc"
    log_info "Run 'source $bashrc' to apply them in existing shells"
}

show_manual_setup() {
    echo ""
    echo -e "${CYAN}=== Manual Setup Instructions ===${NC}"
    echo "Add the following to your shell profile (e.g. ~/.bashrc):"
    echo ""
    echo -e "${YELLOW}export NFS_USERNAME=\"your_username_here\"${NC}"
    echo -e "${YELLOW}export NFS_API_KEY=\"your_api_key_here\"${NC}"
    echo -e "${YELLOW}export NFS_ACCOUNT_ID=\"your_account_id_here\"${NC}"
    echo ""
    echo "Reload your shell with: ${YELLOW}source ~/.bashrc${NC}"
    echo ""
    echo -e "${MAGENTA}Security notes:${NC} keep secrets out of version control and rotate keys regularly."
    echo ""
    log_prompt "Press Enter to continue..."
    read -r
}

show_config() {
    echo ""
    echo -e "${CYAN}=== Configuration ===${NC}"
    echo ""
    echo -e "${MAGENTA}Current values:${NC}"
    echo "  Username:        $NFS_USERNAME"
    echo "  Account ID:      $NFS_ACCOUNT_ID"
    echo "  API Key prefix:  ${NFS_API_KEY:0:8}..."
    echo "  Default Domain:  ${DEFAULT_DOMAIN:-<none>}"
    echo "  Default TTL:     $DEFAULT_TTL"
    echo ""
    echo "1) Save credentials to ~/.bashrc"
    echo "2) Show manual setup instructions"
    echo "3) Back"
    log_prompt "Select option:"
    read -r setup_choice

    case "$setup_choice" in
        1)
            persist_to_bashrc
            ;;
        2)
            show_manual_setup
            ;;
        3|q|Q|"")
            return
            ;;
        *)
            log_warning "Invalid option"
            ;;
    esac
}

main() {
    if ! ensure_dependencies jq curl openssl; then
        exit 1
    fi

    if ! prompt_for_credentials; then
        exit 1
    fi

    show_config
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
