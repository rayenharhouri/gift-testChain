#!/usr/bin/env bash
set -euo pipefail

# Load .env
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

: "${RPC_URL:?RPC_URL not set}"
: "${PRIVATE_KEY:?PRIVATE_KEY not set}"
: "${TARGET_ADDRESS:?TARGET_ADDRESS not set}"
: "${TX_ALLOW_LIST:?TX_ALLOW_LIST not set}"

print_role() {
  local role
  role=$(cast call \
    --rpc-url "$RPC_URL" \
    "$TX_ALLOW_LIST" \
    "readAllowList(address)(uint256)" "$TARGET_ADDRESS")

  echo "Raw role value for $TARGET_ADDRESS: $role"
  case "$role" in
    0x0) echo "Decoded role: None (0)";;
    0x1) echo "Decoded role: Enabled (1)";;
    0x2) echo "Decoded role: Admin (2)";;
    0x3) echo "Decoded role: Manager (3)";;
    *)  echo "Decoded role: Unknown ($role)";;
  esac
}

echo ">>> Before:"
print_role

echo ">>> Setting Enabled for $TARGET_ADDRESS on TxAllowList $TX_ALLOW_LIST"
cast send \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  "$TX_ALLOW_LIST" \
  "setEnabled(address)" "$TARGET_ADDRESS"

echo ">>> After:"
print_role
