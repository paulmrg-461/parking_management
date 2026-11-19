#!/bin/sh
# Generate the Ed25519 key pair for signed barrier commands.
#
#   sh edge/barrier/tools/gen_command_key.sh
#
# Put BARRIER_COMMAND_SIGNING_KEY in .env (functions container only) and
# embed COMMAND_PUBKEY_B64 in the firmware before shipping it. Rotate by
# shipping the new public key first (the firmware accepts two during
# rotation) and then switching the server key.
set -eu

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required" >&2
  exit 1
fi

pem=$(mktemp)
trap 'rm -f "$pem"' EXIT
openssl genpkey -algorithm ED25519 -out "$pem" 2>/dev/null

private=$(openssl pkey -in "$pem" -outform DER 2>/dev/null | base64 -w0)
public=$(openssl pkey -in "$pem" -pubout -outform DER 2>/dev/null | base64 -w0)

echo "# server environment (never commit a real value)"
echo "BARRIER_COMMAND_SIGNING_KEY=$private"
echo
echo "# firmware (COMMAND_PUBKEYS[0])"
echo "COMMAND_PUBKEY_B64=$public"
