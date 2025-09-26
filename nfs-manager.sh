#!/bin/bash

# NearlyFreeSpeech.NET Management Script
# Provides a top-level interactive menu for day-to-day tasks.

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$SCRIPT_DIR/commands"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/common.sh"

pause_for_menu() {
    log_prompt "Press Enter to return to the main menu..."
    read -r || true
    echo ""
}

show_main_menu() {
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║        NearlyFreeSpeech Manager              ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Account:${NC}"
    echo " 1) View account information"
    echo " 2) View sites"
    echo ""
    echo -e "${CYAN}DNS:${NC}"
    echo " 3) Manage DNS records"
    echo " 4) Manage saved domains"
    echo ""
    echo -e "${CYAN}Other:${NC}"
    echo " 5) Configuration"
    echo " 6) Help"
    echo " q) Quit"
    echo ""
    log_prompt "Select an option:"
}

invoke_script() {
    local script_path="$1"
    shift || true

    if [[ ! -x "$script_path" ]]; then
        log_error "Script not executable: $script_path"
        return 1
    fi

    "$script_path" "$@"
    local status=$?
    if (( status == 1 )); then
        log_warning "$(basename "$script_path") exited with error (status $status)"
    elif (( status > 2 )); then
        log_warning "$(basename "$script_path") exited with status $status"
    fi
    return $status
}

main() {
    if ! ensure_dependencies jq curl openssl; then
        exit 1
    fi

    if ! prompt_for_credentials; then
        exit 1
    fi

    while true; do
        show_main_menu
        if ! read -r choice; then
            echo ""
            log_info "EOF received, exiting."
            break
        fi

        case "$choice" in
            1)
                invoke_script "$COMMANDS_DIR/nfs-account-info.sh"
                local status=$?
                if (( status == 0 )); then
                    pause_for_menu
                fi
                ;;
            2)
                invoke_script "$COMMANDS_DIR/nfs-sites-list.sh"
                local status=$?
                if (( status == 0 )); then
                    pause_for_menu
                fi
                ;;
            3)
                invoke_script "$COMMANDS_DIR/nfs-dns.sh"
                local status=$?
                if (( status == 0 )); then
                    pause_for_menu
                fi
                ;;
            4)
                invoke_script "$COMMANDS_DIR/nfs-domains.sh"
                local status=$?
                if (( status == 0 )); then
                    pause_for_menu
                fi
                ;;
            5)
                invoke_script "$COMMANDS_DIR/nfs-config.sh"
                local status=$?
                if (( status == 0 )); then
                    pause_for_menu
                fi
                ;;
            6)
                invoke_script "$COMMANDS_DIR/nfs-help.sh"
                local status=$?
                if (( status == 0 )); then
                    pause_for_menu
                fi
                ;;
            q|Q)
                echo ""
                log_success "Goodbye!"
                return 0
                ;;
            *)
                log_warning "Invalid option. Please try again."
                ;;
        esac

        echo ""
    done
}

main "$@"
