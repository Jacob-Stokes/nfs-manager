#!/bin/bash

# Correct NFS API test based on official documentation

NFS_USERNAME="${NFS_USERNAME:-}"
NFS_API_KEY="${NFS_API_KEY:-}"
DOMAIN="${DEFAULT_DOMAIN:-yourdomain.com}"

# Check if credentials are set
if [[ -z "$NFS_USERNAME" || -z "$NFS_API_KEY" ]]; then
    echo "Error: NFS_USERNAME and NFS_API_KEY environment variables must be set"
    echo "Run the main nfs-manager.sh script first to set up credentials"
    exit 1
fi

echo "=== NFS API Correct Authentication Test ==="
echo "Username: $NFS_USERNAME"
echo "Domain: $DOMAIN"
echo

# Correct format from documentation:
# Hash: SHA1 of "login;timestamp;salt;api-key;request-uri;body-hash"
# Header: "login;timestamp;salt;hash"

timestamp=$(date +%s)
salt=$(openssl rand -hex 16)
uri="/dns/$DOMAIN/listRRs"
body=""
body_hash=$(echo -n "$body" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')

# Create hash string: login;timestamp;salt;api-key;request-uri;body-hash
hash_string="$NFS_USERNAME;$timestamp;$salt;$NFS_API_KEY;$uri;$body_hash"

# Calculate SHA1 hash (not HMAC!)
hash=$(echo -n "$hash_string" | openssl dgst -sha1 -binary | hexdump -v -e '/1 "%02x"')

# Create auth header: login;timestamp;salt;hash
auth_header="$NFS_USERNAME;$timestamp;$salt;$hash"

echo "Timestamp: $timestamp"
echo "Salt: $salt"
echo "URI: $uri"
echo "Body hash: $body_hash"
echo "Hash string: $hash_string"
echo "Final hash: $hash"
echo "Auth header: $auth_header"
echo

echo "Making API request..."
response=$(curl -s -w "\nHTTP: %{http_code}" \
    -H "X-NFSN-Authentication: $auth_header" \
    -X POST \
    "https://api.nearlyfreespeech.net$uri")

echo "$response"
echo
echo "=== Test Complete ==="