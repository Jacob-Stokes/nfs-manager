#!/bin/bash

# NearlyFreeSpeech CLI - Command-line interface for all NFS operations

set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$SCRIPT_DIR/commands"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/modules/common.sh"

show_help() {
    echo "NearlyFreeSpeech CLI Tool"
    echo ""
    echo "Usage:"
    echo "  $0 [GLOBAL_OPTIONS] COMMAND [COMMAND_OPTIONS]"
    echo ""
    echo "Global Options:"
    echo "  --json              Output in JSON format"
    echo "  --help              Show this help"
    echo ""
    echo "Commands:"
    echo "  account             Account operations"
    echo "  sites               Site operations"
    echo "  dns                 DNS operations"
    echo "  domains             Domain management"
    echo "  config              Configuration"
    echo ""
    echo "DNS Commands:"
    echo "  $0 dns --domain DOMAIN --list"
    echo "  $0 dns --domain DOMAIN --add --name NAME --type TYPE --data DATA [--ttl TTL]"
    echo "  $0 dns --domain DOMAIN --delete --name NAME --type TYPE --data DATA"
    echo ""
    echo "Account Commands:"
    echo "  $0 account --info"
    echo ""
    echo "Sites Commands:"
    echo "  $0 sites --list"
    echo ""
    echo "Examples:"
    echo "  $0 dns --domain jacobstokes.com --list"
    echo "  $0 dns --domain jacobstokes.com --add --name www --type A --data 1.2.3.4"
    echo "  $0 account --info"
    echo "  $0 sites --list"
}

main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    local json_output=false

    # Parse global options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --json)
                json_output=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            account|sites|dns|domains|config)
                local command="$1"
                shift
                break
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -z "${command:-}" ]]; then
        log_error "No command specified"
        show_help
        exit 1
    fi

    if ! ensure_dependencies jq curl openssl; then
        exit 1
    fi

    # Suppress log messages in JSON mode
    if [[ "$json_output" == "true" ]]; then
        export SUPPRESS_LOGS=true
    fi

    if ! prompt_for_credentials; then
        exit 1
    fi

    case "$command" in
        "account")
            handle_account_command "$json_output" "$@"
            ;;
        "sites")
            handle_sites_command "$json_output" "$@"
            ;;
        "dns")
            handle_dns_command "$json_output" "$@"
            ;;
        "domains")
            handle_domains_command "$json_output" "$@"
            ;;
        "config")
            handle_config_command "$json_output" "$@"
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

handle_account_command() {
    local json_output="$1"
    shift

    case "${1:-}" in
        --info|"")
            if [[ "$json_output" == "true" ]]; then
                # Get account info as JSON
                if ! make_api_call "GET" "info" "" "member" "$NFS_USERNAME"; then
                    exit 1
                fi
                if [[ $API_STATUS == "200" ]]; then
                    printf '%s\n' "$API_BODY"
                else
                    jq -n --arg error "Failed to get account info" --arg status "$API_STATUS" \
                       '{"error": $error, "status": $status}' >&2
                    exit 1
                fi
            else
                "$COMMANDS_DIR/nfs-account-info.sh"
            fi
            ;;
        *)
            log_error "Unknown account option: $1"
            echo "Usage: $0 account [--info]"
            exit 1
            ;;
    esac
}

handle_sites_command() {
    local json_output="$1"
    shift

    case "${1:-}" in
        --list|"")
            if [[ "$json_output" == "true" ]]; then
                # Get sites as JSON
                if ! make_api_call "GET" "sites" "" "member" "$NFS_USERNAME"; then
                    exit 1
                fi
                if [[ $API_STATUS == "200" ]]; then
                    printf '%s\n' "$API_BODY"
                else
                    jq -n --arg error "Failed to get sites" --arg status "$API_STATUS" \
                       '{"error": $error, "status": $status}' >&2
                    exit 1
                fi
            else
                "$COMMANDS_DIR/nfs-sites-list.sh"
            fi
            ;;
        *)
            log_error "Unknown sites option: $1"
            echo "Usage: $0 sites [--list]"
            exit 1
            ;;
    esac
}

handle_dns_command() {
    local json_output="$1"
    shift

    # Pass all DNS arguments to the DNS module
    source "$SCRIPT_DIR/modules/dns.sh"

    local domain="" operation="" name="" type="" data="" ttl="$DEFAULT_TTL"

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
            *)
                log_error "Unknown DNS option: $1"
                echo "Usage: $0 dns --domain DOMAIN [--list|--add|--delete] [options]"
                exit 1
                ;;
        esac
    done

    if [[ -z "$domain" ]]; then
        log_error "Domain is required for DNS operations"
        echo "Usage: $0 dns --domain DOMAIN [--list|--add|--delete] [options]"
        exit 1
    fi

    case "$operation" in
        "list")
            if ! dns_fetch_records "$domain"; then
                exit 1
            fi
            if [[ "$json_output" == "true" ]]; then
                printf '%s\n' "$DNS_RECORDS"
            else
                dns_print_records_table "$domain" "$DNS_RECORDS"
            fi
            ;;
        "add")
            if [[ -z "$name" || -z "$type" || -z "$data" ]]; then
                log_error "Name, type, and data are required for add operation"
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
                if [[ "$json_output" == "true" ]]; then
                    jq -n --arg name "${name:-@}" --arg type "$type" --arg data "$data" --arg ttl "$ttl" \
                       '{"status": "success", "action": "added", "record": {"name": $name, "type": $type, "data": $data, "ttl": ($ttl | tonumber)}}'
                else
                    log_success "Record added: ${name:-@} $type $data (TTL: $ttl)"
                fi
            else
                if [[ "$json_output" == "true" ]]; then
                    jq -n --arg error "Failed to add record" --arg status "$API_STATUS" --arg response "$API_BODY" \
                       '{"status": "error", "error": $error, "http_status": $status, "response": $response}' >&2
                else
                    log_error "Failed to add record (HTTP $API_STATUS)"
                    log_info "Response: $API_BODY"
                fi
                exit 1
            fi
            ;;
        "delete")
            if [[ -z "$name" || -z "$type" || -z "$data" ]]; then
                log_error "Name, type, and data are required for delete operation"
                exit 1
            fi

            [[ "$name" == "@" ]] && name=""

            local body="name=$(urlencode "$name")&type=$type&data=$(urlencode "$data")"
            if ! make_api_call "POST" "removeRR" "$body" "dns" "$domain"; then
                exit 1
            fi

            if [[ $API_STATUS == "200" ]]; then
                if [[ "$json_output" == "true" ]]; then
                    jq -n --arg name "${name:-@}" --arg type "$type" --arg data "$data" \
                       '{"status": "success", "action": "deleted", "record": {"name": $name, "type": $type, "data": $data}}'
                else
                    log_success "Record deleted: ${name:-@} $type $data"
                fi
            else
                if [[ "$json_output" == "true" ]]; then
                    jq -n --arg error "Failed to delete record" --arg status "$API_STATUS" --arg response "$API_BODY" \
                       '{"status": "error", "error": $error, "http_status": $status, "response": $response}' >&2
                else
                    log_error "Failed to delete record (HTTP $API_STATUS)"
                    log_info "Response: $API_BODY"
                fi
                exit 1
            fi
            ;;
        "")
            log_error "DNS operation is required (--list, --add, or --delete)"
            exit 1
            ;;
        *)
            log_error "Unknown DNS operation: $operation"
            exit 1
            ;;
    esac
}

handle_domains_command() {
    local json_output="$1"
    shift

    case "${1:-}" in
        --list|"")
            if [[ "$json_output" == "true" ]]; then
                # Get domains as JSON
                if ! make_api_call "GET" "domains" "" "member" "$NFS_USERNAME"; then
                    exit 1
                fi
                if [[ $API_STATUS == "200" ]]; then
                    printf '%s\n' "$API_BODY"
                else
                    jq -n --arg error "Failed to get domains" --arg status "$API_STATUS" \
                       '{"error": $error, "status": $status}' >&2
                    exit 1
                fi
            else
                "$COMMANDS_DIR/nfs-domains.sh"
            fi
            ;;
        *)
            log_error "Unknown domains option: $1"
            echo "Usage: $0 domains [--list]"
            exit 1
            ;;
    esac
}

handle_config_command() {
    local json_output="$1"
    shift

    case "${1:-}" in
        --show|"")
            if [[ "$json_output" == "true" ]]; then
                jq -n \
                    --arg username "${NFS_USERNAME:-}" \
                    --arg account_id "${NFS_ACCOUNT_ID:-}" \
                    --arg default_domain "${DEFAULT_DOMAIN:-}" \
                    --arg default_ttl "${DEFAULT_TTL:-3600}" \
                    '{"username": $username, "account_id": $account_id, "default_domain": $default_domain, "default_ttl": ($default_ttl | tonumber)}'
            else
                "$COMMANDS_DIR/nfs-config.sh"
            fi
            ;;
        *)
            log_error "Unknown config option: $1"
            echo "Usage: $0 config [--show]"
            exit 1
            ;;
    esac
}

main "$@"