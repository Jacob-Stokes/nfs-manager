#!/bin/bash

# NearlyFreeSpeech.NET Complete Management Script
# Manage DNS records, account info, sites, and more

set -e

# Load environment variables from .env file if it exists
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
fi

# Configuration - Use environment variables or prompt for sensitive data
NFS_USERNAME="${NFS_USERNAME:-}"
NFS_API_KEY="${NFS_API_KEY:-}"
NFS_ACCOUNT_ID="${NFS_ACCOUNT_ID:-}"
DEFAULT_DOMAIN="${DEFAULT_DOMAIN:-yourdomain.com}"
DEFAULT_TTL="${DEFAULT_TTL:-3600}"

# Function to prompt for credentials if not set via environment variables
prompt_for_credentials() {
    if [[ -z "$NFS_USERNAME" ]]; then
        read -p "NFS Username: " NFS_USERNAME
        if [[ -z "$NFS_USERNAME" ]]; then
            log_error "Username is required"
            exit 1
        fi
    fi

    if [[ -z "$NFS_API_KEY" ]]; then
        read -s -p "NFS API Key: " NFS_API_KEY
        echo ""
        if [[ -z "$NFS_API_KEY" ]]; then
            log_error "API Key is required"
            exit 1
        fi
    fi

    if [[ -z "$NFS_ACCOUNT_ID" ]]; then
        log_info "Discovering account ID for $NFS_USERNAME..."

        # Try to discover account ID
        local timestamp=$(date +%s)
        local salt=$(openssl rand -hex 16)
        local uri="/member/$NFS_USERNAME/accounts"
        local body=""
        local body_hash=$(echo -n "$body" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')
        local hash_string="$NFS_USERNAME;$timestamp;$salt;$NFS_API_KEY;$uri;$body_hash"
        local hash=$(echo -n "$hash_string" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')
        local auth_header="$NFS_USERNAME;$timestamp;$salt;$hash"

        local response=$(curl -s -w "%{http_code}" \
            -H "X-NFSN-Authentication: $auth_header" \
            -X GET \
            "https://api.nearlyfreespeech.net$uri")

        local http_code="${response: -3}"
        local body="${response%???}"

        if [[ $http_code == "200" ]]; then
            NFS_ACCOUNT_ID=$(echo "$body" | jq -r '.[0]' 2>/dev/null)
            if [[ -n "$NFS_ACCOUNT_ID" && "$NFS_ACCOUNT_ID" != "null" ]]; then
                log_success "Discovered account ID: $NFS_ACCOUNT_ID"
            else
                read -p "Could not auto-discover account ID. Please enter your account ID: " NFS_ACCOUNT_ID
            fi
        else
            log_warning "Could not auto-discover account ID (HTTP $http_code)"
            read -p "Please enter your account ID: " NFS_ACCOUNT_ID
        fi

        if [[ -z "$NFS_ACCOUNT_ID" ]]; then
            log_error "Account ID is required"
            exit 1
        fi
    fi

    log_success "Credentials configured successfully"
    log_info "Username: $NFS_USERNAME"
    log_info "Account ID: $NFS_ACCOUNT_ID"
    log_info "API Key: ${NFS_API_KEY:0:8}..."
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_prompt() { echo -e "${CYAN}[PROMPT]${NC} $1"; }

# Function to create NFS authentication header
create_auth_header() {
    local method="$1"
    local uri="$2"
    local body="$3"

    local timestamp=$(date +%s)
    local salt=$(openssl rand -hex 16)
    local body_hash=$(echo -n "$body" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')

    # Hash string: login;timestamp;salt;api-key;request-uri;body-hash
    local hash_string="$NFS_USERNAME;$timestamp;$salt;$NFS_API_KEY;$uri;$body_hash"
    local hash=$(echo -n "$hash_string" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')

    echo "$NFS_USERNAME;$timestamp;$salt;$hash"
}

# Function to make API call
make_api_call() {
    local method="$1"
    local endpoint="$2"
    local body="$3"
    local object_type="$4"
    local object_id="$5"

    local uri="/$object_type/$object_id/$endpoint"
    local auth_header=$(create_auth_header "$method" "$uri" "$body")

    local curl_opts=(-s -w "%{http_code}")
    curl_opts+=(-H "X-NFSN-Authentication: $auth_header")

    if [[ -n "$body" ]]; then
        curl_opts+=(-H "Content-Type: application/x-www-form-urlencoded")
        curl_opts+=(-d "$body")
    fi

    curl_opts+=(-X "$method")
    curl_opts+=("https://api.nearlyfreespeech.net$uri")

    curl "${curl_opts[@]}"
}

# Function to get user input with default value
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    if [[ -n "$default" ]]; then
        read -p "$prompt [$default]: " input
        eval "$var_name=\"\${input:-$default}\""
    else
        read -p "$prompt: " input
        eval "$var_name=\"$input\""
    fi
}

# ====== ACCOUNT FUNCTIONS ======

show_account_info() {
    echo ""
    echo -e "${CYAN}=== Account Information ===${NC}"
    echo ""

    # Get account balance information
    echo -e "${MAGENTA}Account Balance:${NC}"
    echo "══════════════════════════════════"

    local balance=$(make_api_call "GET" "balance" "" "account" "$NFS_ACCOUNT_ID" | sed 's/...$//')
    local balance_cash=$(make_api_call "GET" "balanceCash" "" "account" "$NFS_ACCOUNT_ID" | sed 's/...$//')
    local balance_credit=$(make_api_call "GET" "balanceCredit" "" "account" "$NFS_ACCOUNT_ID" | sed 's/...$//')
    local balance_high=$(make_api_call "GET" "balanceHigh" "" "account" "$NFS_ACCOUNT_ID" | sed 's/...$//')

    printf "%-20s %s\n" "Current Balance:" "\$${balance}"
    printf "%-20s %s\n" "Cash Balance:" "\$${balance_cash}"
    printf "%-20s %s\n" "Credit Balance:" "\$${balance_credit}"
    printf "%-20s %s\n" "Highest Balance:" "\$${balance_high}"

    # Calculate percentage of high water mark
    if [[ "$balance_high" != "0" ]]; then
        local percentage=$(echo "scale=1; $balance * 100 / $balance_high" | bc 2>/dev/null || echo "N/A")
        printf "%-20s %s%%\n" "% of High Mark:" "$percentage"
    fi

    echo ""
    log_success "Account information retrieved"
}

# ====== SITE FUNCTIONS ======

show_sites() {
    echo ""
    echo -e "${CYAN}=== Sites Management ===${NC}"
    echo ""

    log_info "Fetching sites for $NFS_USERNAME..." >&2

    local response=$(make_api_call "GET" "sites" "" "member" "$NFS_USERNAME")
    local http_code="${response: -3}"
    local sites="${response%???}"

    if [[ $http_code == "200" ]]; then
        echo -e "${MAGENTA}Your Sites:${NC}"
        echo "══════════════════════════════════"
        echo "$sites" | jq -r '.[]' | nl -w2 -s'. '
        echo ""
        log_success "Sites retrieved successfully"
    else
        log_error "Failed to retrieve sites (HTTP $http_code)"
        echo "Response: $sites" >&2
        return 1
    fi
}

# ====== DNS FUNCTIONS ======

# Function to list DNS records
list_dns_records() {
    local domain="$1"

    log_info "Fetching DNS records for $domain..." >&2

    local response=$(make_api_call "POST" "listRRs" "" "dns" "$domain")
    local http_code="${response: -3}"
    local body="${response%???}"

    # Debug: show raw response if not JSON
    if [[ ! "$body" =~ ^\[.*\]$ ]]; then
        log_error "API response is not valid JSON:"
        echo "Raw response: '$body'" >&2
        echo "HTTP code: $http_code" >&2
        return 1
    fi

    if [[ $http_code == "200" ]]; then
        if [[ "$body" == "[]" ]]; then
            log_warning "No DNS records found for $domain"
            return 1
        else
            echo "$body"
            return 0
        fi
    else
        log_error "Failed to list DNS records (HTTP $http_code)"
        echo "Response: $body" >&2
        return 1
    fi
}

# Function to display DNS records in a formatted table
display_dns_records() {
    local domain="$1"
    local records=$(list_dns_records "$domain")

    if [[ $? -ne 0 ]]; then
        return 1
    fi

    echo ""
    echo -e "${MAGENTA}DNS Records for $domain:${NC}"
    echo "========================================"
    printf "%-3s %-20s %-8s %-20s %-8s\n" "ID" "NAME" "TYPE" "DATA" "TTL"
    echo "----------------------------------------"

    local id=1
    if ! echo "$records" | jq empty 2>/dev/null; then
        log_error "Records JSON is invalid, cannot display"
        return 1
    fi

    echo "$records" | jq -r '.[] | [.name, .type, .data, .ttl] | @tsv' | while IFS=$'\t' read name type data ttl; do
        # Handle empty name (root domain)
        display_name="${name:-@}"
        printf "%-3d %-20s %-8s %-20s %-8s\n" "$id" "$display_name" "$type" "$data" "$ttl"
        id=$((id + 1))
    done
    echo ""
}

show_dns_records() {
    echo ""
    echo -e "${CYAN}=== DNS Records ===${NC}"

    get_input "Domain" "$DEFAULT_DOMAIN" "domain"
    display_dns_records "$domain"
}

# ====== MENU FUNCTIONS ======

show_main_menu() {
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║        NearlyFreeSpeech Manager              ║${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Account Management:${NC}"
    echo "1) View Account Information"
    echo "2) View Sites"
    echo ""
    echo -e "${CYAN}DNS Management:${NC}"
    echo "3) List DNS Records"
    echo "4) Add DNS Record"
    echo "5) Delete DNS Record"
    echo "6) Edit DNS Record"
    echo ""
    echo -e "${CYAN}Other:${NC}"
    echo "7) Configuration"
    echo "8) Help"
    echo "q) Quit"
    echo ""
    log_prompt "Select an option:"
}

show_config() {
    echo ""
    echo -e "${CYAN}=== Configuration ===${NC}"
    echo ""
    echo -e "${MAGENTA}Current Settings:${NC}"
    echo "  Username: $NFS_USERNAME"
    echo "  Account ID: $NFS_ACCOUNT_ID"
    echo "  API Key: ${NFS_API_KEY:0:8}..."
    echo "  Default Domain: $DEFAULT_DOMAIN"
    echo "  Default TTL: $DEFAULT_TTL"
    echo ""
    echo -e "${MAGENTA}Setup Options:${NC}"
    echo "1) Auto-setup environment variables in ~/.bashrc"
    echo "2) Show manual setup instructions"
    echo "3) Back to main menu"
    echo ""
    log_prompt "Select option:"
    read -r setup_choice

    case $setup_choice in
        1)
            setup_environment_variables
            ;;
        2)
            show_manual_setup
            ;;
        3)
            return
            ;;
        *)
            log_error "Invalid option"
            ;;
    esac
}

setup_environment_variables() {
    echo ""
    echo -e "${CYAN}=== Auto-Setup Environment Variables ===${NC}"
    echo ""

    if [[ -n "$NFS_USERNAME" && -n "$NFS_API_KEY" && -n "$NFS_ACCOUNT_ID" ]]; then
        echo "Current credentials will be saved to ~/.bashrc:"
        echo "  Username: $NFS_USERNAME"
        echo "  Account ID: $NFS_ACCOUNT_ID"
        echo "  API Key: ${NFS_API_KEY:0:8}..."
        echo ""
        log_prompt "Save these credentials to ~/.bashrc? (y/N):"
        read -r confirm

        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Check if already exists
            if grep -q "NFS_USERNAME" ~/.bashrc 2>/dev/null; then
                log_warning "NFS variables already exist in ~/.bashrc"
                log_prompt "Overwrite existing values? (y/N):"
                read -r overwrite
                if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                    log_info "Setup cancelled"
                    return
                fi
                # Remove existing entries
                sed -i '/# NearlyFreeSpeech API Configuration/,+3d' ~/.bashrc
            fi

            # Add new entries
            echo "" >> ~/.bashrc
            echo "# NearlyFreeSpeech API Configuration" >> ~/.bashrc
            echo "export NFS_USERNAME=\"$NFS_USERNAME\"" >> ~/.bashrc
            echo "export NFS_API_KEY=\"$NFS_API_KEY\"" >> ~/.bashrc
            echo "export NFS_ACCOUNT_ID=\"$NFS_ACCOUNT_ID\"" >> ~/.bashrc

            log_success "Environment variables saved to ~/.bashrc"
            log_info "Run 'source ~/.bashrc' to load them in new terminals"
        else
            log_info "Setup cancelled"
        fi
    else
        log_error "Please enter your credentials first (they will be prompted when needed)"
    fi

    echo ""
    log_prompt "Press Enter to continue..."
    read
}

show_manual_setup() {
    echo ""
    echo -e "${CYAN}=== Manual Setup Instructions ===${NC}"
    echo ""
    echo "Add these lines to your ~/.bashrc file:"
    echo ""
    echo -e "${YELLOW}export NFS_USERNAME=\"your_username_here\"${NC}"
    echo -e "${YELLOW}export NFS_API_KEY=\"your_api_key_here\"${NC}"
    echo -e "${YELLOW}export NFS_ACCOUNT_ID=\"your_account_id_here\"${NC}"
    echo ""
    echo "Then run: ${YELLOW}source ~/.bashrc${NC}"
    echo ""
    echo -e "${MAGENTA}Security Notes:${NC}"
    echo "• Never commit API keys to version control"
    echo "• Get your API key from NearlyFreeSpeech.NET member interface"
    echo "• Account ID can be auto-discovered by this script"
    echo ""
    log_prompt "Press Enter to continue..."
    read
}

show_help() {
    echo ""
    echo -e "${CYAN}=== NearlyFreeSpeech Manager Help ===${NC}"
    echo ""
    echo "This script provides a complete interface for managing your"
    echo "NearlyFreeSpeech.NET account using their API."
    echo ""
    echo "Features:"
    echo -e "${YELLOW}Account Management:${NC}"
    echo "  • View account balance and financial information"
    echo "  • List and manage your sites"
    echo ""
    echo -e "${YELLOW}DNS Management:${NC}"
    echo "  • List existing DNS records in a formatted table"
    echo "  • Add new DNS records (A, AAAA, CNAME, MX, TXT, etc.)"
    echo "  • Delete specific DNS records"
    echo "  • Edit existing records"
    echo ""
    echo -e "${YELLOW}Requirements:${NC}"
    echo "  • Valid NearlyFreeSpeech.NET account with API access"
    echo "  • API key generated from your account profile"
    echo "  • jq (JSON processor), curl, and openssl utilities"
    echo ""
    log_prompt "Press Enter to continue..."
    read
}

# Main execution loop
main() {
    # Check dependencies
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Please install jq to continue."
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed. Please install curl to continue."
        exit 1
    fi

    if ! command -v openssl &> /dev/null; then
        log_error "openssl is required but not installed. Please install openssl to continue."
        exit 1
    fi

    # Prompt for credentials if not set via environment variables
    prompt_for_credentials

    # Main menu loop
    while true; do
        show_main_menu
        read -r choice

        case $choice in
            1) show_account_info ;;
            2) show_sites ;;
            3) show_dns_records ;;
            4) echo "DNS Add functionality - call existing DNS manager script option 1" ;;
            5) echo "DNS Delete functionality - call existing DNS manager script option 3" ;;
            6) echo "DNS Edit functionality - call existing DNS manager script option 4" ;;
            7) show_config ;;
            8) show_help ;;
            q|Q)
                echo ""
                log_success "Goodbye!"
                exit 0
                ;;
            *)
                log_error "Invalid option. Please try again."
                ;;
        esac

        echo ""
        log_prompt "Press Enter to continue..."
        read
    done
}

# Run main function
main "$@"