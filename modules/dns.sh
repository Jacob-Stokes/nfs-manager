#!/bin/bash

# DNS helper routines for NearlyFreeSpeech.NET scripts.

if [[ -n "${NFS_DNS_LOADED:-}" ]]; then
    return
fi
NFS_DNS_LOADED=1

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_ROOT/modules/common.sh"

DNS_ALLOWED_TYPES=(A AAAA CNAME MX NS PTR SRV TXT)
DNS_EDITABLE_TYPES=(A AAAA TXT)

DNS_RECORDS=""

_dns_validate_type() {
    local type="$1"
    shift
    local valid_list=("$@")
    local upper_type=${type^^}
    local t
    for t in "${valid_list[@]}"; do
        if [[ "$upper_type" == "$t" ]]; then
            printf '%s' "$upper_type"
            return 0
        fi
    done
    return 1
}

dns_fetch_records() {
    local domain="$1"
    # Remove any trailing whitespace/newlines
    domain=$(printf '%s' "$domain" | tr -d '\n\r')
    if ! make_api_call "POST" "listRRs" "" "dns" "$domain"; then
        return 1
    fi

    if [[ $API_STATUS != "200" ]]; then
        log_error "Failed to fetch DNS records for $domain (HTTP $API_STATUS)"
        log_info "Response: $API_BODY"
        return 1
    fi

    DNS_RECORDS="$API_BODY"
}

dns_print_records_table() {
    local domain="$1"
    local records_json="$2"

    echo ""
    echo -e "${MAGENTA}DNS records for $domain:${NC}"
    echo "========================================"
    printf '%-3s %-25s %-8s %-35s %-8s\n' "ID" "NAME" "TYPE" "DATA" "TTL"
    echo "----------------------------------------"

    local has_rows=false
    local id=1
    while IFS=$'\t' read -r name type data ttl; do
        has_rows=true
        local display_name="${name:-@}"
        printf '%-3d %-25s %-8s %-35s %-8s\n' "$id" "$display_name" "$type" "$data" "$ttl"
        ((id++))
    done < <(printf '%s' "$records_json" | jq -r '.[] | [(.name // ""), .type, .data, (.ttl // "")] | @tsv')

    if [[ "$has_rows" == false ]]; then
        log_warning "No DNS records found"
    fi

    echo ""
}

dns_select_record() {
    local records_json="$1"
    local prompt="$2"

    local total
    total=$(printf '%s' "$records_json" | jq 'length') || return 1
    if (( total == 0 )); then
        return 1
    fi

    while true; do
        log_prompt "$prompt (1-$total, c to cancel):"
        read -r choice
        case "$choice" in
            c|C) return 1 ;;
        esac

        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            log_warning "Please enter a number between 1 and $total"
            continue
        fi

        local index=$((choice - 1))
        if (( index < 0 || index >= total )); then
            log_warning "Please enter a number between 1 and $total"
            continue
        fi

        local record
        record=$(printf '%s' "$records_json" | jq -c ".[$index]")
        if [[ "$record" == "null" ]]; then
            log_error "Could not read selected record"
            return 1
        fi

        printf '%s' "$record"
        return 0
    done
}

dns_add_record() {
    local domain="$1"
    echo ""
    echo -e "${CYAN}Add DNS record${NC}"

    local name type data ttl
    get_input "Record name (@ for root)" "" name
    get_input "Record type" "A" type
    get_input "Record data" "" data
    get_input "TTL (seconds)" "$DEFAULT_TTL" ttl

    [[ -n "$data" ]] || { log_error "Record data is required"; return 1; }

    if ! type=$(_dns_validate_type "$type" "${DNS_ALLOWED_TYPES[@]}"); then
        log_error "Unsupported record type: $type"
        return 1
    fi

    [[ "$name" == "@" ]] && name=""

    local body="name=$(urlencode "$name")&type=$type&data=$(urlencode "$data")&ttl=$ttl"
    if ! make_api_call "POST" "addRR" "$body" "dns" "$domain"; then
        return 1
    fi

    if [[ $API_STATUS == "200" ]]; then
        log_success "Record added"
        return 0
    fi

    log_error "Failed to add record (HTTP $API_STATUS)"
    log_info "Response: $API_BODY"
    return 1
}

dns_delete_record() {
    local domain="$1"
    local records_json="$2"

    local selected
    if ! selected=$(dns_select_record "$records_json" "Select record to delete"); then
        log_info "Delete cancelled"
        return 1
    fi

    local name type data
    name=$(printf '%s' "$selected" | jq -r '.name // ""')
    type=$(printf '%s' "$selected" | jq -r '.type')
    data=$(printf '%s' "$selected" | jq -r '.data')

    if ! confirm "Delete $type record '${name:-@}' -> $data?" "n"; then
        log_info "Delete cancelled"
        return 1
    fi

    local body="name=$(urlencode "$name")&type=$type&data=$(urlencode "$data")"
    if ! make_api_call "POST" "removeRR" "$body" "dns" "$domain"; then
        return 1
    fi

    if [[ $API_STATUS == "200" ]]; then
        log_success "Record removed"
        return 0
    fi

    log_error "Failed to remove record (HTTP $API_STATUS)"
    log_info "Response: $API_BODY"
    return 1
}

dns_edit_record() {
    local domain="$1"
    local records_json="$2"

    local selected
    if ! selected=$(dns_select_record "$records_json" "Select record to edit"); then
        log_info "Edit cancelled"
        return 1
    fi

    local current_name current_type current_data current_ttl
    current_name=$(printf '%s' "$selected" | jq -r '.name // ""')
    current_type=$(printf '%s' "$selected" | jq -r '.type')
    current_data=$(printf '%s' "$selected" | jq -r '.data')
    current_ttl=$(printf '%s' "$selected" | jq -r '.ttl // empty')
    [[ -n "$current_ttl" ]] || current_ttl="$DEFAULT_TTL"

    if ! current_type=$(_dns_validate_type "$current_type" "${DNS_EDITABLE_TYPES[@]}"); then
        log_error "Editing $current_type records is not supported by this tool"
        return 1
    fi

    local name type data ttl
    get_input "Record name" "${current_name:-@}" name
    get_input "Record type" "$current_type" type
    get_input "Record data" "$current_data" data
    get_input "TTL (seconds)" "$current_ttl" ttl

    if ! type=$(_dns_validate_type "$type" "${DNS_EDITABLE_TYPES[@]}"); then
        log_error "Unsupported record type for edit: $type"
        return 1
    fi

    [[ "$name" == "@" ]] && name=""

    local body="name=$(urlencode "$name")&type=$type&data=$(urlencode "$data")&ttl=$ttl"
    if ! make_api_call "POST" "replaceRR" "$body" "dns" "$domain"; then
        return 1
    fi

    if [[ $API_STATUS == "200" ]]; then
        log_success "Record updated"
        return 0
    fi

    log_error "Failed to update record (HTTP $API_STATUS)"
    log_info "Response: $API_BODY"
    return 1
}

dns_manage_records() {
    local domain="$1"

    while true; do
        if ! dns_fetch_records "$domain"; then
            return 1
        fi

        dns_print_records_table "$domain" "$DNS_RECORDS"

        echo "1) Add record"
        echo "2) Edit record"
        echo "3) Delete record"
        echo "4) Refresh"
        echo "5) Change domain"
        echo "6) Back to main menu"
        log_prompt "Select option:"
        read -r action

        case "$action" in
            1)
                dns_add_record "$domain" ;;
            2)
                dns_edit_record "$domain" "$DNS_RECORDS" ;;
            3)
                dns_delete_record "$domain" "$DNS_RECORDS" ;;
            4)
                continue ;;
            5)
                return 2 ;;
            6|q|Q)
                return 0 ;;
            *)
                log_warning "Invalid selection"
                ;;
        esac
    done
}

dns_management_loop() {
    while true; do
        local domain
        if [[ -n "$DEFAULT_DOMAIN" ]]; then
            if confirm "Use default domain $DEFAULT_DOMAIN?" "y"; then
                domain="$DEFAULT_DOMAIN"
            else
                domain=$(select_domain_with_save) || return 0
            fi
        else
            domain=$(select_domain_with_save) || return 0
        fi

        log_info "Managing DNS for $domain"
        while true; do
            dns_manage_records "$domain"
            local result=$?
            case $result in
                0)
                    if confirm "Manage another domain?" "n"; then
                        break
                    else
                        return 0
                    fi
                    ;;
                1)
                    log_warning "Returning to domain selection"
                    break
                    ;;
                2)
                    # User asked to change domain
                    break
                    ;;
                *)
                    return "$result"
                    ;;
            esac
        done
    done
}
