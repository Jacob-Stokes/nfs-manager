#!/bin/bash

# Manage locally saved domain shortcuts

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"

add_domain_manually() {
    echo ""
    log_prompt "Enter domain name to add:"
    read -r domain
    if [[ -n "$domain" ]]; then
        save_domain "$domain"
    else
        log_error "Domain name cannot be empty"
    fi
}

remove_domain_interactive() {
    mapfile -t saved_domains < <(load_domains)
    if [[ ${#saved_domains[@]} -eq 0 ]]; then
        log_warning "No domains to remove"
        return
    fi

    echo ""
    echo -e "${MAGENTA}Select domain to remove:${NC}"
    local idx
    for idx in "${!saved_domains[@]}"; do
        printf '%2d) %s\n' "$((idx + 1))" "${saved_domains[$idx]}"
    done

    log_prompt "Select domain number to remove (c to cancel):"
    read -r choice
    case "$choice" in
        c|C) return ;;
    esac

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local selection=$((choice))
        if (( selection >= 1 && selection <= ${#saved_domains[@]} )); then
            local domain_to_remove="${saved_domains[$((selection - 1))]}"
            if confirm "Remove domain '$domain_to_remove'?" "n"; then
                remove_domain "$domain_to_remove"
            fi
            return
        fi
    fi

    log_error "Invalid selection"
}

clear_all_domains() {
    echo ""
    if confirm "Clear ALL saved domains?" "n"; then
        rm -f "$DOMAINS_CONFIG"
        log_success "All domains cleared"
    else
        log_info "Operation cancelled"
    fi
}

manage_domain_settings() {
    while true; do
        echo ""
        echo -e "${CYAN}=== Domain Save Settings ===${NC}"
        local prompt_all=$(get_domain_save_setting "prompt_all")
        prompt_all=${prompt_all:-true}
        echo "Auto-prompt for new domains: $([[ "$prompt_all" == "true" ]] && echo Enabled || echo Disabled)"
        echo ""
        echo "1) Enable auto-prompting"
        echo "2) Disable auto-prompting"
        echo "3) Clear domain-specific skip settings"
        echo "4) Back"
        log_prompt "Select option:"
        read -r choice
        case "$choice" in
            1)
                set_domain_save_setting "prompt_all" "true"
                log_success "Auto-prompting enabled"
                ;;
            2)
                set_domain_save_setting "prompt_all" "false"
                log_success "Auto-prompting disabled"
                ;;
            3)
                if [[ -f "$DOMAIN_SETTINGS_CONFIG" ]]; then
                    grep -v '^skip_' "$DOMAIN_SETTINGS_CONFIG" >"${DOMAIN_SETTINGS_CONFIG}.tmp" 2>/dev/null && mv "${DOMAIN_SETTINGS_CONFIG}.tmp" "$DOMAIN_SETTINGS_CONFIG"
                    log_success "Domain-specific skip settings cleared"
                else
                    log_info "No domain-specific settings to clear"
                fi
                ;;
            4|c|C|q|Q|"")
                return
                ;;
            *)
                log_warning "Invalid option"
                ;;
        esac
    done
}

show_domain_management() {
    while true; do
        mapfile -t saved_domains < <(load_domains)
        echo ""
        echo -e "${CYAN}=== Domain Management ===${NC}"

        if [[ ${#saved_domains[@]} -gt 0 ]]; then
            echo -e "${MAGENTA}Saved Domains:${NC}"
            echo "════════════════════════════════════════"
            local idx
            for idx in "${!saved_domains[@]}"; do
                printf '%2d) %s\n' "$((idx + 1))" "${saved_domains[$idx]}"
            done
        else
            echo -e "${MAGENTA}No saved domains yet.${NC}"
        fi

        echo ""
        echo "a) Add a domain"
        echo "r) Remove a domain"
        echo "c) Clear all domains"
        echo "s) Domain save settings"
        echo "b) Back to main menu"
        log_prompt "Select option:"
        read -r choice

        case "$choice" in
            a|A) add_domain_manually ;;
            r|R) remove_domain_interactive ;;
            c|C) clear_all_domains ;;
            s|S) manage_domain_settings ;;
            b|B|q|Q|"") return ;;
            *) log_warning "Invalid option" ;;
        esac
    done
}

main() {
    if ! ensure_dependencies jq curl openssl; then
        exit 1
    fi

    if ! prompt_for_credentials; then
        exit 1
    fi

    show_domain_management
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
