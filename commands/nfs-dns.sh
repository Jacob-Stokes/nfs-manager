#!/bin/bash

# DNS management entry point - supports both interactive and command-line usage.

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/dns.sh"

show_help() {
    echo "DNS Management Tool"
    echo ""
    echo "Usage:"
    echo "  $0                                    # Interactive mode"
    echo "  $0 [OPTIONS] --domain DOMAIN --add --name NAME --type TYPE --data DATA [--ttl TTL]"
    echo "  $0 [OPTIONS] --domain DOMAIN --delete --name NAME --type TYPE --data DATA"
    echo "  $0 [OPTIONS] --domain DOMAIN --list"
    echo ""
    echo "Options:"
    echo "  --domain DOMAIN     Domain to operate on"
    echo "  --add               Add a DNS record"
    echo "  --delete            Delete a DNS record"
    echo "  --list              List all DNS records"
    echo "  --name NAME         Record name (use @ for root domain)"
    echo "  --type TYPE         Record type (A, AAAA, CNAME, TXT, etc.)"
    echo "  --data DATA         Record data (IP address, hostname, etc.)"
    echo "  --ttl TTL           TTL in seconds (default: $DEFAULT_TTL)"
    echo "  --help              Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --domain jacobstokes.com --add --name squeeze --type A --data 46.101.66.88"
    echo "  $0 --domain jacobstokes.com --delete --name postiz --type A --data 46.101.66.88"
    echo "  $0 --domain jacobstokes.com --list"
}

main() {
    if ! ensure_dependencies jq curl openssl; then
        exit 1
    fi

    local domain="" operation="" name="" type="" data="" ttl="$DEFAULT_TTL"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                domain="$2"
                shift 2
                ;;
            --add)
                operation="add"
                shift
                ;;
            --delete)
                operation="delete"
                shift
                ;;
            --list)
                operation="list"
                shift
                ;;
            --name)
                name="$2"
                shift 2
                ;;
            --type)
                type="$2"
                shift 2
                ;;
            --data)
                data="$2"
                shift 2
                ;;
            --ttl)
                ttl="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if ! prompt_for_credentials; then
        exit 1
    fi

    # If no arguments provided, run interactive mode
    if [[ -z "$operation" ]]; then
        dns_management_loop
        return
    fi

    # Validate required arguments for non-interactive mode
    if [[ -z "$domain" ]]; then
        log_error "Domain is required for non-interactive mode"
        show_help
        exit 1
    fi

    case "$operation" in
        "list")
            if ! dns_fetch_records "$domain"; then
                exit 1
            fi
            dns_print_records_table "$domain" "$DNS_RECORDS"
            ;;
        "add")
            if [[ -z "$name" || -z "$type" || -z "$data" ]]; then
                log_error "Name, type, and data are required for add operation"
                show_help
                exit 1
            fi

            if ! type=$(_dns_validate_type "$type" "${DNS_ALLOWED_TYPES[@]}"); then
                log_error "Unsupported record type: $type"
                exit 1
            fi

            [[ "$name" == "@" ]] && name=""

            local body="name=$(urlencode "$name")&type=$type&data=$(urlencode "$data")&ttl=$ttl"
            if ! make_api_call "POST" "addRR" "$body" "dns" "$domain"; then
                exit 1
            fi

            if [[ $API_STATUS == "200" ]]; then
                log_success "Record added: ${name:-@} $type $data (TTL: $ttl)"
            else
                log_error "Failed to add record (HTTP $API_STATUS)"
                log_info "Response: $API_BODY"
                exit 1
            fi
            ;;
        "delete")
            if [[ -z "$name" || -z "$type" || -z "$data" ]]; then
                log_error "Name, type, and data are required for delete operation"
                show_help
                exit 1
            fi

            [[ "$name" == "@" ]] && name=""

            local body="name=$(urlencode "$name")&type=$type&data=$(urlencode "$data")"
            if ! make_api_call "POST" "removeRR" "$body" "dns" "$domain"; then
                exit 1
            fi

            if [[ $API_STATUS == "200" ]]; then
                log_success "Record deleted: ${name:-@} $type $data"
            else
                log_error "Failed to delete record (HTTP $API_STATUS)"
                log_info "Response: $API_BODY"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown operation: $operation"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
