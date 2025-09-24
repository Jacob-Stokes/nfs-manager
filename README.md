# NearlyFreeSpeech Manager

Complete management tool for NearlyFreeSpeech.NET accounts using their API.

## Features

### 🏦 Account Management
- View account balance and financial information
- List and manage your sites

### 🌐 DNS Management
- List existing DNS records in a formatted table
- Add new DNS records (A, AAAA, CNAME, MX, TXT, etc.)
- Delete specific DNS records
- Edit existing records

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd nfs-scripts
   ```

2. **Run the manager**
   ```bash
   ./nfs-manager.sh
   ```

3. **First-time setup**
   - Enter your NearlyFreeSpeech credentials when prompted
   - Use Configuration menu (option 7) for auto-setup to save credentials

## 🔐 Credential Setup

### Option 1: Auto-Setup (Easiest)
Run the script and use **Configuration → Auto-setup environment variables**

### Option 2: Manual Setup
Add to your `~/.bashrc`:
```bash
export NFS_USERNAME="your_username"
export NFS_API_KEY="your_api_key"
export NFS_ACCOUNT_ID="your_account_id"  # Optional - can be auto-discovered
```
Then run: `source ~/.bashrc`

### Option 3: Interactive Mode
Just run the script - it will prompt for credentials if not found.

## Usage

```bash
# Run the main manager
./nfs-manager.sh

# Run API test (for debugging)
./nfs-correct-test.sh
```

## Menu Options

1. **View Account Information** - Shows balance, cash/credit breakdown
2. **View Sites** - Lists all your NFS sites
3. **List DNS Records** - Shows all DNS records for a domain
4. **Add DNS Record** - Add new DNS record
5. **Delete DNS Record** - Remove specific DNS record
6. **Edit DNS Record** - Modify existing record
7. **Configuration** - View current settings and setup instructions
8. **Help** - Detailed help information

## Requirements

- `curl` - HTTP client
- `jq` - JSON processor
- `openssl` - Cryptographic functions
- `bc` - Calculator (optional, for percentage calculations)

## API Information

This tool works with any NearlyFreeSpeech.NET account. Your specific account details will be discovered automatically when you first run the script.

## Security Notes

- Never commit API keys to version control
- Environment variables are stored in `~/.bashrc`
- Protect your `~/.bashrc` file: `chmod 600 ~/.bashrc`
- API key is masked in display (shows only first 8 characters)

## Files

- `nfs-manager.sh` - Main comprehensive manager script
- `nfs-correct-test.sh` - API testing utility
- `README.md` - This documentation