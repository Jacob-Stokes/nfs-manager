# NearlyFreeSpeech Manager

Management tools for NearlyFreeSpeech.NET accounts via API.

## Structure

```
nfs-repo/
├── nfs-manager.sh          # Interactive menu interface
├── nfs-cli.sh              # Command-line interface
├── commands/               # Individual command scripts (interactive)
│   ├── nfs-account-info.sh
│   ├── nfs-dns.sh
│   ├── nfs-sites-list.sh
│   ├── nfs-domains.sh
│   ├── nfs-config.sh
│   └── nfs-help.sh
└── modules/               # Shared functionality
    ├── common.sh          # Authentication, utilities
    └── dns.sh            # DNS operations
```

## Usage

### Interactive Mode
```bash
./nfs-manager.sh           # Main menu interface
./commands/nfs-dns.sh      # DNS management only
```

### Command Line Mode
```bash
# DNS operations
./nfs-cli.sh dns --domain example.com --list
./nfs-cli.sh dns --domain example.com --add --name www --type A --data 1.2.3.4
./nfs-cli.sh dns --domain example.com --delete --name www --type A --data 1.2.3.4

# Account and sites
./nfs-cli.sh account --info
./nfs-cli.sh sites --list
```

## Setup

Credentials can be provided via:
1. Environment variables: `NFS_USERNAME`, `NFS_API_KEY`, `NFS_ACCOUNT_ID`
2. `.env` file in repository root
3. Interactive prompts (auto-discovers account ID)

## DNS Management

Supports both interactive menu and command-line operations:
- List all DNS records for a domain
- Add records (A, AAAA, CNAME, MX, TXT, etc.)
- Delete existing records
- Edit records (A, AAAA, TXT only)

Domain names can be saved and reused across sessions.

## Requirements

- curl
- jq
- openssl

## Security

- API keys are never logged or displayed in full
- Credentials are prompted securely when needed
- Account ID auto-discovery prevents manual entry errors