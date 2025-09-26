#!/bin/bash

# Shared helpers for NearlyFreeSpeech.NET shell tooling.
# This file is meant to be sourced; it keeps state in exported variables.

# Only initialize variables once, but always define functions
if [[ -z "${NFS_COMMON_LOADED:-}" ]]; then
    NFS_COMMON_LOADED=1

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load .env if present so developers can store credentials securely.
if [[ -f "$SCRIPT_ROOT/.env" ]]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_ROOT/.env"
fi

# Core configuration (environment variables override defaults).
NFS_USERNAME="${NFS_USERNAME:-}"
NFS_API_KEY="${NFS_API_KEY:-}"
NFS_ACCOUNT_ID="${NFS_ACCOUNT_ID:-}"
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-}"
DEFAULT_TTL="${DEFAULT_TTL:-3600}"

# ANSI colors for user feedback.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
fi

# Function definitions (always loaded)
log_info()    { [[ "${SUPPRESS_LOGS:-}" != "true" ]] && echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { [[ "${SUPPRESS_LOGS:-}" != "true" ]] && echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warning() { [[ "${SUPPRESS_LOGS:-}" != "true" ]] && echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_prompt()  { [[ "${SUPPRESS_LOGS:-}" != "true" ]] && echo -e "${CYAN}[PROMPT]${NC} $1" >&2; }

ensure_dependencies() {
    local missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        return 1
    fi
}

prompt_for_credentials() {
    if [[ -z "$NFS_USERNAME" ]]; then
        read -r -p "NFS Username: " NFS_USERNAME
        [[ -n "$NFS_USERNAME" ]] || { log_error "Username is required"; return 1; }
    fi

    if [[ -z "$NFS_API_KEY" ]]; then
        read -r -s -p "NFS API Key: " NFS_API_KEY
        echo ""
        [[ -n "$NFS_API_KEY" ]] || { log_error "API Key is required"; return 1; }
    fi

    if [[ -z "$NFS_ACCOUNT_ID" ]]; then
        log_info "Discovering account ID for $NFS_USERNAME..."

        local timestamp=$(date +%s)
        local salt=$(openssl rand -hex 16)
        local uri="/member/$NFS_USERNAME/accounts"
        local body=""
        local body_hash=$(printf %s "$body" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')
        local hash_string="$NFS_USERNAME;$timestamp;$salt;$NFS_API_KEY;$uri;$body_hash"
        local hash=$(printf %s "$hash_string" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')
        local auth_header="$NFS_USERNAME;$timestamp;$salt;$hash"

        local raw
        if ! raw=$(curl -sS -w "%{http_code}" -H "X-NFSN-Authentication: $auth_header" -X GET "https://api.nearlyfreespeech.net$uri"); then
            log_warning "Failed to contact API while discovering account ID"
        else
            local discovery_status=${raw: -3}
            local discovery_body=${raw%???}
            if [[ $discovery_status == "200" ]]; then
                NFS_ACCOUNT_ID=$(printf %s "$discovery_body" | jq -r '.[0]' 2>/dev/null)
                if [[ -n "$NFS_ACCOUNT_ID" && "$NFS_ACCOUNT_ID" != "null" ]]; then
                    log_success "Discovered account ID: $NFS_ACCOUNT_ID"
                else
                    read -r -p "Could not auto-discover account ID. Please enter your account ID: " NFS_ACCOUNT_ID
                fi
            else
                log_warning "Could not auto-discover account ID (HTTP $discovery_status)"
                read -r -p "Please enter your account ID: " NFS_ACCOUNT_ID
            fi
        fi

        [[ -n "$NFS_ACCOUNT_ID" ]] || { log_error "Account ID is required"; return 1; }
    fi

    if [[ -z "${_CREDENTIALS_CONFIGURED:-}" ]]; then
        log_success "Credentials configured successfully"
        export _CREDENTIALS_CONFIGURED=1
    fi

    export NFS_USERNAME NFS_API_KEY NFS_ACCOUNT_ID DEFAULT_DOMAIN DEFAULT_TTL
    return 0
}

create_auth_header() {
    local method="$1"
    local uri="$2"
    local body="$3"

    local timestamp=$(date +%s)
    local salt=$(openssl rand -hex 16)
    local body_hash=$(printf %s "$body" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')
    local hash_string="$NFS_USERNAME;$timestamp;$salt;$NFS_API_KEY;$uri;$body_hash"
    local hash=$(printf %s "$hash_string" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')
    printf '%s' "$NFS_USERNAME;$timestamp;$salt;$hash"
}

# Shared response holders so callers can examine both status and body.
API_STATUS=""
API_BODY=""

make_api_call() {
    local method="$1"
    local endpoint="$2"
    local body="$3"
    local object_type="$4"
    local object_id="$5"

    local uri="/$object_type/$object_id/$endpoint"
    local auth_header
    auth_header=$(create_auth_header "$method" "$uri" "$body") || return 1

    local curl_args=(-sS -w '%{http_code}' -H "X-NFSN-Authentication: $auth_header" -X "$method")

    if [[ -n "$body" ]]; then
        curl_args+=(-H 'Content-Type: application/x-www-form-urlencoded')
        curl_args+=(-d "$body")
    fi

    curl_args+=("https://api.nearlyfreespeech.net$uri")

    local response
    if ! response=$(curl "${curl_args[@]}"); then
        API_STATUS=0
        API_BODY=""
        log_error "Network error while calling $uri"
        return 1
    fi

    API_STATUS=${response: -3}
    API_BODY=${response%???}
    return 0
}

get_input() {
    local prompt="$1"
    local default="$2"
    local result_var="$3"
    local input

    if [[ -n "$default" ]]; then
        read -r -p "$prompt [$default]: " input
        input=${input:-$default}
    else
        read -r -p "$prompt: " input
    fi

    printf -v "$result_var" '%s' "$input"
}

confirm() {
    local prompt="$1"
    local default_choice="$2"
    local default_label

    case "$default_choice" in
        y|Y) default_label="Y/n" ;;
        n|N) default_label="y/N" ;;
        *) default_label="y/n" ;;
    esac

    while true; do
        read -r -p "$prompt [$default_label]: " reply
        reply=${reply:-$default_choice}
        case "$reply" in
            y|Y) return 0 ;;
            n|N) return 1 ;;
            *) log_warning "Please answer y or n." ;;
        esac
    done
}

urlencode() {
    local string="$1"
    local length=${#string}
    local encoded=""

    local i c
    for ((i = 0; i < length; i++)); do
        c=${string:i:1}
        case "$c" in
            [a-zA-Z0-9.~_-])
                encoded+="$c"
                ;;
            *)
                printf -v encoded '%s%%%02X' "$encoded" "'$c"
                ;;
        esac
    done

    printf '%s' "$encoded"
}

DOMAINS_CONFIG="$SCRIPT_ROOT/.domains"
DOMAIN_SETTINGS_CONFIG="$SCRIPT_ROOT/.domain_settings"

load_domains() {
    [[ -f "$DOMAINS_CONFIG" ]] || return 0
    grep -v '^[[:space:]]*$' "$DOMAINS_CONFIG" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

save_domain() {
    local domain="$1"
    [[ -n "$domain" ]] || return
    if ! load_domains | grep -Fxq "$domain"; then
        echo "$domain" >>"$DOMAINS_CONFIG"
        log_success "Domain '$domain' saved to your list"
    fi
}

remove_domain() {
    local domain="$1"
    [[ -f "$DOMAINS_CONFIG" ]] || return
    grep -Fvx "$domain" "$DOMAINS_CONFIG" >"${DOMAINS_CONFIG}.tmp" 2>/dev/null && mv "${DOMAINS_CONFIG}.tmp" "$DOMAINS_CONFIG"
    log_success "Domain '$domain' removed from your list"
}

get_domain_save_setting() {
    local setting="$1"
    [[ -f "$DOMAIN_SETTINGS_CONFIG" ]] || return 1
    grep "^$setting=" "$DOMAIN_SETTINGS_CONFIG" 2>/dev/null | cut -d'=' -f2
}

set_domain_save_setting() {
    local setting="$1"
    local value="$2"
    if [[ -f "$DOMAIN_SETTINGS_CONFIG" ]]; then
        grep -v "^$setting=" "$DOMAIN_SETTINGS_CONFIG" >"${DOMAIN_SETTINGS_CONFIG}.tmp" 2>/dev/null && mv "${DOMAIN_SETTINGS_CONFIG}.tmp" "$DOMAIN_SETTINGS_CONFIG"
    fi
    echo "$setting=$value" >>"$DOMAIN_SETTINGS_CONFIG"
}

ask_save_domain() {
    local domain="$1"

    if [[ "$(get_domain_save_setting "prompt_all")" == "false" ]]; then
        return 1
    fi

    if [[ "$(get_domain_save_setting "skip_$domain")" == "true" ]]; then
        return 1
    fi

    echo ""
    echo -e "${YELLOW}New domain detected: ${NC}$domain"
    echo ""
    echo "1) Save this domain"
    echo "2) Use once"
    echo "3) Use once and never ask for this domain"
    echo "4) Use once and never ask for new domains"
    log_prompt "Select option (1-4):"
    read -r choice

    case "$choice" in
        1) save_domain "$domain" ;;
        2) return 1 ;;
        3) set_domain_save_setting "skip_$domain" "true"; log_info "Won't ask again for $domain" ;;
        4) set_domain_save_setting "prompt_all" "false"; log_info "Domain prompting disabled" ;;
        *) log_warning "Invalid choice, using domain once"; return 1 ;;
    esac
}

select_domain_with_save() {
    mapfile -t saved_domains < <(load_domains)

    echo "" >&2
    echo -e "${CYAN}=== Select Domain ===${NC}" >&2
    echo "" >&2

    if [[ ${#saved_domains[@]} -gt 0 ]]; then
        echo -e "${MAGENTA}Saved Domains:${NC}" >&2
        echo "════════════════════════════════════════" >&2
        local idx
        for idx in "${!saved_domains[@]}"; do
            printf '%2d) %s\n' "$((idx + 1))" "${saved_domains[$idx]}" >&2
        done
        printf '%2d) Enter a new domain\n' "$(( ${#saved_domains[@]} + 1 ))" >&2
        log_prompt "Select domain number or enter a domain (c to cancel):"
        read -r choice

        case "$choice" in
            c|C|q|Q) return 1 ;;
            '' ) log_error "Domain name cannot be empty"; return 1 ;;
        esac

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            local numeric_choice=$((choice))
            if (( numeric_choice >=1 && numeric_choice <= ${#saved_domains[@]} )); then
                printf '%s' "${saved_domains[$((numeric_choice - 1))]}"
                return 0
            elif (( numeric_choice == ${#saved_domains[@]} + 1 )); then
                log_prompt "Enter domain name:"
                read -r new_domain
                [[ -n "$new_domain" ]] || { log_error "Domain name cannot be empty"; return 1; }
                ask_save_domain "$new_domain"
                printf '%s' "$new_domain"
                return 0
            fi
        fi

        ask_save_domain "$choice"
        printf '%s' "$choice"
        return 0
    fi

    log_prompt "Enter domain name (c to cancel):"
    read -r domain_choice
    case "$domain_choice" in
        c|C) return 1 ;;
        '') log_error "Domain name cannot be empty"; return 1 ;;
    esac

    ask_save_domain "$domain_choice"
    printf '%s' "$domain_choice"
    return 0
}

select_domain() {
    echo ""
    echo -e "${CYAN}=== Select Domain ===${NC}"
    echo ""
    log_info "Fetching your domains..."

    if ! make_api_call "GET" "domains" "" "member" "$NFS_USERNAME"; then
        return 1
    fi

    if [[ $API_STATUS != "200" ]]; then
        log_error "Failed to retrieve domains (HTTP $API_STATUS)"
        printf '%s' "$API_BODY" >&2
        return 1
    fi

    mapfile -t domains_array < <(printf '%s' "$API_BODY" | jq -r '.[]')
    if [[ ${#domains_array[@]} -eq 0 ]]; then
        log_error "No domains found in your account"
        return 1
    fi

    local idx
    for idx in "${!domains_array[@]}"; do
        printf '%2d) %s\n' "$((idx + 1))" "${domains_array[$idx]}"
    done
    log_prompt "Select domain number (c to cancel):"
    read -r choice

    case "$choice" in
        c|C) return 1 ;;
    esac

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        log_error "Invalid selection"
        return 1
    fi

    local numeric_choice=$((choice))
    if (( numeric_choice < 1 || numeric_choice > ${#domains_array[@]} )); then
        log_error "Invalid selection"
        return 1
    fi

    printf '%s' "${domains_array[$((numeric_choice - 1))]}"
    return 0
}
