#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# GIFT local Avalanche L1 explorer
# Works with standard EVM RPC and uses txpool views when exposed.
# Requires: cast, jq
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ENV_FILE:-$SCRIPT_DIR/.env}"
DEPLOYMENTS_FILE="${DEPLOYMENTS_FILE:-$SCRIPT_DIR/deployments/avalanche.json}"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

# -----------------------------
# Config
# -----------------------------
BLOCKCHAIN_NAME="${NETWORK_NAME:-gift}"
CHAIN_ID="${CHAIN_ID:-6969}"
RPC_URL="${RPC_URL:-http://127.0.0.1:9656/ext/bc/2QAg6qzA1GMsBrEfwVZBdoWSa7vqsKcPPpX5JeAZPu3yUNs3ca/rpc}"
REFRESH_SECS="${REFRESH_SECS:-2}"
DEFAULT_ADDRESS="${DEFAULT_ADDRESS:-}"
DEFAULT_TX_HASH="${DEFAULT_TX_HASH:-}"
DEFAULT_BLOCK="${DEFAULT_BLOCK:-latest}"
BLOCKCHAIN_ID="${BLOCKCHAIN_ID:-}"

CLIENT_VERSION="unknown"
LATEST_BLOCK_HEX="0x0"
LATEST_BLOCK_DEC="0"
RPC_AVAILABLE=0
RPC_STATUS="unreachable"
TXPOOL_AVAILABLE=0

DEPLOYMENT_KEYS=(
  memberRegistry
  documentRegistry
  goldAssetToken
  goldAccountLedger
  transactionOrderBook
  vaultSiteRegistry
  vaultRegistry
)

# -----------------------------
# Helpers
# -----------------------------
need_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERROR] Missing dependency: $1"
    exit 1
  }
}

pause() {
  echo
  read -r -p "Press Enter to continue..." _
}

hex_to_dec() {
  local v="${1:-0x0}"
  if [[ "$v" =~ ^0x[0-9a-fA-F]+$ ]]; then
    printf '%d' "$((v))"
  else
    printf '%s' "$v"
  fi
}

dec_to_hex() {
  local v="${1:-0}"
  printf '0x%x' "$v"
}

json_scalar() {
  jq -r '.' <<<"$1"
}

rpc() {
  local method="$1"
  shift || true
  cast rpc --rpc-url "$RPC_URL" "$method" "$@"
}

parse_blockchain_id_from_rpc() {
  if [[ "$RPC_URL" =~ /ext/bc/([^/]+)/rpc ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

health_url_from_rpc() {
  if [[ "$RPC_URL" =~ ^(https?://[^/]+)/ext/bc/[^/]+/rpc$ ]]; then
    printf '%s/ext/health' "${BASH_REMATCH[1]}"
  fi
}

normalize_block_ref() {
  local ref="${1:-latest}"
  case "$ref" in
    latest|earliest|pending|safe|finalized)
      printf '%s' "$ref"
      ;;
    0x*)
      printf '%s' "$ref"
      ;;
    *)
      if [[ "$ref" =~ ^[0-9]+$ ]]; then
        dec_to_hex "$ref"
      else
        printf '%s' "$ref"
      fi
      ;;
  esac
}

format_timestamp() {
  local raw="${1:-0x0}"
  local dec
  dec="$(hex_to_dec "$raw")"
  if [[ "$dec" =~ ^[0-9]+$ ]]; then
    date -d "@$dec" '+%Y-%m-%d %H:%M:%S %Z' 2>/dev/null || printf '%s' "$dec"
  else
    printf '%s' "$raw"
  fi
}

refresh_network_metadata() {
  local out

  if [[ -z "$BLOCKCHAIN_ID" ]]; then
    BLOCKCHAIN_ID="$(parse_blockchain_id_from_rpc)"
  fi

  if out="$(rpc net_version 2>/dev/null)"; then
    RPC_AVAILABLE=1
    RPC_STATUS="ok"
    CHAIN_ID="$(json_scalar "$out")"
  else
    RPC_AVAILABLE=0
    RPC_STATUS="route not mounted"
    CLIENT_VERSION="unknown"
    LATEST_BLOCK_HEX="0x0"
    LATEST_BLOCK_DEC="0"
    TXPOOL_AVAILABLE=0
    return 0
  fi

  if out="$(rpc web3_clientVersion 2>/dev/null)"; then
    CLIENT_VERSION="$(json_scalar "$out")"
  fi

  if out="$(fetch_block_json latest false 2>/dev/null)"; then
    LATEST_BLOCK_HEX="$(jq -r '.number // "0x0"' <<<"$out")"
    LATEST_BLOCK_DEC="$(hex_to_dec "$LATEST_BLOCK_HEX")"
  fi

  if rpc txpool_status >/dev/null 2>&1; then
    TXPOOL_AVAILABLE=1
  else
    TXPOOL_AVAILABLE=0
  fi
}

fetch_block_json() {
  local ref="${1:-latest}"
  local full="${2:-false}"
  local normalized
  normalized="$(normalize_block_ref "$ref")"

  if [[ "$normalized" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
    rpc eth_getBlockByHash "$normalized" "$full"
  else
    rpc eth_getBlockByNumber "$normalized" "$full"
  fi
}

print_header() {
  refresh_network_metadata
  clear || true
  cat <<'EOF'
   ██████╗ ██╗███████╗████████╗    ███████╗██╗  ██╗██████╗ ██╗      ██████╗ ██████╗ ███████╗██████╗
  ██╔════╝ ██║██╔════╝╚══██╔══╝    ██╔════╝╚██╗██╔╝██╔══██╗██║     ██╔═══██╗██╔══██╗██╔════╝██╔══██╗
  ██║  ███╗██║█████╗     ██║       █████╗   ╚███╔╝ ██████╔╝██║     ██║   ██║██████╔╝█████╗  ██████╔╝
  ██║   ██║██║██╔══╝     ██║       ██╔══╝   ██╔██╗ ██╔═══╝ ██║     ██║   ██║██╔══██╗██╔══╝  ██╔══██╗
  ╚██████╔╝██║██║        ██║       ███████╗██╔╝ ██╗██║     ███████╗╚██████╔╝██║  ██║███████╗██║  ██║
   ╚═════╝ ╚═╝╚═╝        ╚═╝       ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

                                L O C A L   L 1   E X P L O R E R
EOF
  echo
  echo "RPC URL         : $RPC_URL"
  echo "RPC status      : ${RPC_STATUS}"
  echo "Network         : ${BLOCKCHAIN_NAME:-unknown}"
  echo "Chain ID        : ${CHAIN_ID:-unknown}"
  echo "Blockchain ID   : ${BLOCKCHAIN_ID:-unknown}"
  echo "Client          : ${CLIENT_VERSION:-unknown}"
  echo "Latest block    : ${LATEST_BLOCK_DEC:-0} (${LATEST_BLOCK_HEX:-0x0})"
  echo "Txpool support  : $([[ "$TXPOOL_AVAILABLE" -eq 1 ]] && echo "enabled" || echo "not exposed by this node")"
  echo "Deployments file: $([[ -f "$DEPLOYMENTS_FILE" ]] && echo "$DEPLOYMENTS_FILE" || echo "missing")"
  echo "Refresh (watch) : ${REFRESH_SECS}s"
  echo "============================================================"
  echo
}

require_rpc() {
  if [[ "$RPC_AVAILABLE" -eq 1 ]]; then
    return 0
  fi

  echo "[ERROR] RPC route is not mounted at:"
  echo "  $RPC_URL"
  echo
  echo "Your local Avalanche node is running, but the chain RPC endpoint is broken."
  echo "Fix:"
  echo "  1. Remove \"txpool\" from ~/.avalanche-cli/subnets/gift1/chain.json"
  echo "  2. Restart the local network"
  return 1
}

require_txpool() {
  require_rpc || return 1

  if [[ "$TXPOOL_AVAILABLE" -eq 1 ]]; then
    return 0
  fi

  echo "[ERROR] txpool_* RPC methods are not available on this Avalanche node."
  echo "This local L1 still supports the rest of the explorer through standard EVM RPC."
  return 1
}

show_network_status() {
  local syncing gas_price health_url health_summary

  if [[ "$RPC_AVAILABLE" -ne 1 ]]; then
    health_url="$(health_url_from_rpc)"
    health_summary="unknown"
    if [[ -n "$health_url" ]]; then
      health_summary="$(curl -s "$health_url" 2>/dev/null | jq -r '.healthy // "unknown"' 2>/dev/null || echo "unknown")"
    fi

    echo "RPC URL       : $RPC_URL"
    echo "RPC status    : ${RPC_STATUS}"
    echo "Health URL    : ${health_url:-unavailable}"
    echo "Node health   : $health_summary"
    echo "Hint          : remove \"txpool\" from ~/.avalanche-cli/subnets/gift1/chain.json and restart the local network"
    return 0
  fi

  syncing="$(rpc eth_syncing 2>/dev/null | jq -r '.' 2>/dev/null || echo "unknown")"
  gas_price="$(rpc eth_gasPrice 2>/dev/null | jq -r '.' 2>/dev/null || echo "unknown")"

  echo "RPC URL       : $RPC_URL"
  echo "RPC status    : ${RPC_STATUS}"
  echo "Network       : ${BLOCKCHAIN_NAME:-unknown}"
  echo "Chain ID      : ${CHAIN_ID:-unknown}"
  echo "Blockchain ID : ${BLOCKCHAIN_ID:-unknown}"
  echo "Client        : ${CLIENT_VERSION:-unknown}"
  echo "Latest block  : ${LATEST_BLOCK_DEC:-0} (${LATEST_BLOCK_HEX:-0x0})"
  echo "Gas price     : $gas_price"
  echo "Syncing       : $syncing"
  echo "Txpool        : $([[ "$TXPOOL_AVAILABLE" -eq 1 ]] && echo "available" || echo "unavailable")"
}

show_recent_blocks() {
  local limit="${1:-5}"
  local i block_no block_json hash txs gas_used timestamp

  require_rpc || return 1

  printf "%-8s %-66s %-6s %-10s %s\n" "BLOCK" "HASH" "TXS" "GAS_USED" "TIMESTAMP"
  printf "%-8s %-66s %-6s %-10s %s\n" "-----" "----" "---" "--------" "---------"

  for ((i = 0; i < limit; i++)); do
    block_no=$((LATEST_BLOCK_DEC - i))
    if (( block_no < 0 )); then
      break
    fi

    block_json="$(fetch_block_json "$block_no" false)"
    if [[ "$(jq -r '.hash // empty' <<<"$block_json")" == "" ]]; then
      continue
    fi

    hash="$(jq -r '.hash' <<<"$block_json")"
    txs="$(jq '.transactions | length' <<<"$block_json")"
    gas_used="$(hex_to_dec "$(jq -r '.gasUsed' <<<"$block_json")")"
    timestamp="$(format_timestamp "$(jq -r '.timestamp' <<<"$block_json")")"

    printf "%-8s %-66s %-6s %-10s %s\n" "$block_no" "$hash" "$txs" "$gas_used" "$timestamp"
  done
}

show_block_details() {
  local ref="${1:-$DEFAULT_BLOCK}"
  require_rpc || return 1
  fetch_block_json "$ref" true | jq
}

show_block_transactions() {
  local ref="${1:-$DEFAULT_BLOCK}"
  local block_json

  require_rpc || return 1

  block_json="$(fetch_block_json "$ref" true)"
  if [[ "$(jq -r '.hash // empty' <<<"$block_json")" == "" ]]; then
    echo "[ERROR] Block not found: $ref"
    return 1
  fi

  echo "Block number : $(hex_to_dec "$(jq -r '.number' <<<"$block_json")")"
  echo "Block hash   : $(jq -r '.hash' <<<"$block_json")"
  echo "Timestamp    : $(format_timestamp "$(jq -r '.timestamp' <<<"$block_json")")"
  echo

  jq -r '
    .transactions[]? |
    [
      (.hash // "-"),
      (.from // "-"),
      (.to // "<contract-creation>"),
      (.nonce // "0x0"),
      (.value // "0x0")
    ] | @tsv
  ' <<<"$block_json" | awk -F'\t' 'BEGIN {
      printf "%-66s %-44s %-44s %-8s %s\n", "HASH", "FROM", "TO", "NONCE", "VALUE";
      printf "%-66s %-44s %-44s %-8s %s\n", "----", "----", "--", "-----", "-----";
    }
    {
      printf "%-66s %-44s %-44s %-8s %s\n", $1, $2, $3, $4, $5
    }'
}

address_label() {
  local addr="$1"
  if [[ ! -f "$DEPLOYMENTS_FILE" ]]; then
    return 0
  fi

  jq -r --arg addr "${addr,,}" '
    to_entries[]
    | select(.value | type == "string")
    | select((.value | ascii_downcase) == $addr)
    | .key
  ' "$DEPLOYMENTS_FILE"
}

show_address_summary() {
  local addr="$1"
  local nonce_hex balance_hex code_raw nonce balance code label

  require_rpc || return 1

  nonce_hex="$(rpc eth_getTransactionCount "$addr" latest 2>/dev/null | jq -r '.' 2>/dev/null || echo "0x0")"
  balance_hex="$(rpc eth_getBalance "$addr" latest 2>/dev/null | jq -r '.' 2>/dev/null || echo "0x0")"
  code_raw="$(rpc eth_getCode "$addr" latest 2>/dev/null | jq -r '.' 2>/dev/null || echo "0x")"
  nonce="$(hex_to_dec "$nonce_hex")"
  balance="$(hex_to_dec "$balance_hex")"
  code="$code_raw"
  label="$(address_label "$addr" | paste -sd ',' -)"

  echo "Address  : $addr"
  echo "Label    : ${label:-unlabeled}"
  echo "Nonce    : $nonce"
  echo "Balance  : $balance wei"
  if [[ "$code" == "0x" || -z "$code" ]]; then
    echo "Type     : EOA / no deployed bytecode"
  else
    echo "Type     : Contract"
    echo "Code size: $(( (${#code} - 2) / 2 )) bytes"
  fi
}

show_tx() {
  local hash="$1"
  require_rpc || return 1
  rpc eth_getTransactionByHash "$hash" | jq
}

show_receipt() {
  local hash="$1"
  require_rpc || return 1
  rpc eth_getTransactionReceipt "$hash" | jq
}

show_deployments() {
  local key addr code_size raw code

  if [[ ! -f "$DEPLOYMENTS_FILE" ]]; then
    echo "[ERROR] Missing deployments file: $DEPLOYMENTS_FILE"
    return 1
  fi

  require_rpc || return 1

  echo "Deployment file: $DEPLOYMENTS_FILE"
  echo
  echo "Network   : $(jq -r '.network // "unknown"' "$DEPLOYMENTS_FILE")"
  echo "Timestamp : $(jq -r '.timestamp // "unknown"' "$DEPLOYMENTS_FILE")"
  echo "Chain ID  : $(jq -r '.chainId // "unknown"' "$DEPLOYMENTS_FILE")"
  echo "Deployer  : $(jq -r '.deployer // "unknown"' "$DEPLOYMENTS_FILE")"
  echo

  printf "%-24s %-44s %-9s %s\n" "CONTRACT" "ADDRESS" "DEPLOYED" "CODE_BYTES"
  printf "%-24s %-44s %-9s %s\n" "--------" "-------" "--------" "----------"

  for key in "${DEPLOYMENT_KEYS[@]}"; do
    addr="$(jq -r --arg key "$key" '.[$key] // empty' "$DEPLOYMENTS_FILE")"
    if [[ -z "$addr" ]]; then
      continue
    fi

    code_size="0"
    if raw="$(rpc eth_getCode "$addr" latest 2>/dev/null)"; then
      code="$(jq -r '.' <<<"$raw")"
      if [[ "$code" != "0x" && -n "$code" ]]; then
        code_size="$(( (${#code} - 2) / 2 ))"
        printf "%-24s %-44s %-9s %s\n" "$key" "$addr" "yes" "$code_size"
      else
        printf "%-24s %-44s %-9s %s\n" "$key" "$addr" "no" "0"
      fi
    else
      printf "%-24s %-44s %-9s %s\n" "$key" "$addr" "rpc-error" "-"
    fi
  done
}

show_status() {
  require_txpool || return 1

  local out pending_hex queued_hex pending_dec queued_dec
  out="$(rpc txpool_status)"
  pending_hex="$(jq -r '.pending // "0x0"' <<<"$out")"
  queued_hex="$(jq -r '.queued // "0x0"' <<<"$out")"
  pending_dec="$(hex_to_dec "$pending_hex")"
  queued_dec="$(hex_to_dec "$queued_hex")"

  echo "Pending: $pending_dec ($pending_hex)"
  echo "Queued : $queued_dec ($queued_hex)"
}

show_inspect() {
  require_txpool || return 1

  rpc txpool_inspect | jq -r '
    def rows($bucket):
      .[$bucket] // {}
      | to_entries[]?
      | .key as $from
      | .value
      | to_entries[]?
      | [($bucket|ascii_upcase), $from, .key, .value]
      | @tsv;
    (rows("pending"), rows("queued"))
  ' | awk -F'\t' 'BEGIN {
      printf "%-8s %-44s %-8s %s\n", "STATE", "FROM", "NONCE", "SUMMARY";
      printf "%-8s %-44s %-8s %s\n", "-----", "----", "-----", "-------";
    }
    { printf "%-8s %-44s %-8s %s\n", $1, $2, $3, $4 }'
}

show_list() {
  require_txpool || return 1

  rpc txpool_content | jq -r '
    def rows($bucket):
      .[$bucket] // {}
      | to_entries[]?
      | .key as $from
      | .value
      | to_entries[]?
      | .value as $tx
      | [
          ($bucket|ascii_upcase),
          $from,
          (.key|tostring),
          ($tx.hash // "-"),
          ($tx.to // "<contract-creation>"),
          ($tx.value // "0x0"),
          ($tx.gasPrice // $tx.maxFeePerGas // "-"),
          ($tx.type // "-"),
          ($tx.input | if . == "0x" then "no" else "yes" end)
        ]
      | @tsv;
    (rows("pending"), rows("queued"))
  ' | awk -F'\t' 'BEGIN {
      printf "%-8s %-44s %-8s %-66s %-44s %-12s %-12s %-6s %s\n", "STATE", "FROM", "NONCE", "HASH", "TO", "VALUE", "FEE", "TYPE", "DATA";
      printf "%-8s %-44s %-8s %-66s %-44s %-12s %-12s %-6s %s\n", "-----", "----", "-----", "----", "--", "-----", "---", "----", "----";
    }
    {
      printf "%-8s %-44s %-8s %-66s %-44s %-12s %-12s %-6s %s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9
    }'
}

show_raw() {
  require_txpool || return 1
  rpc txpool_content | jq
}

show_from() {
  local addr="$1"

  if [[ "$TXPOOL_AVAILABLE" -eq 1 ]]; then
    rpc txpool_contentFrom "$addr" | jq
  else
    show_address_summary "$addr"
  fi
}

watch_chain() {
  while true; do
    print_header
    show_network_status
    if [[ "$RPC_AVAILABLE" -eq 1 ]]; then
      echo
      show_recent_blocks 5
    fi
    if [[ "$TXPOOL_AVAILABLE" -eq 1 ]]; then
      echo
      show_status || true
    fi
    sleep "$REFRESH_SECS"
  done
}

change_defaults_menu() {
  while true; do
    print_header
    echo "Change defaults"
    echo
    echo "1) Set default address"
    echo "2) Set default tx hash"
    echo "3) Set default block reference"
    echo "4) Set refresh seconds"
    echo "5) Set RPC URL"
    echo "6) Back"
    echo
    read -r -p "Choose: " opt
    case "$opt" in
      1)
        read -r -p "Enter address: " DEFAULT_ADDRESS
        ;;
      2)
        read -r -p "Enter tx hash: " DEFAULT_TX_HASH
        ;;
      3)
        read -r -p "Enter block number/hash/latest: " DEFAULT_BLOCK
        ;;
      4)
        read -r -p "Enter refresh seconds: " REFRESH_SECS
        ;;
      5)
        read -r -p "Enter RPC URL: " RPC_URL
        BLOCKCHAIN_ID=""
        refresh_network_metadata
        ;;
      6)
        break
        ;;
      *)
        echo "Invalid option"
        pause
        ;;
    esac
  done
}

menu() {
  while true; do
    print_header
    echo "1) Show network status"
    echo "2) Show recent blocks"
    echo "3) Show block details"
    echo "4) Show block transactions"
    echo "5) Show deployed contracts"
    echo "6) Explore an address"
    echo "7) Explore one tx by hash"
    echo "8) Show receipt for a tx hash"
    echo "9) Watch chain live"
    echo "10) Show txpool status"
    echo "11) Show txpool inspect summary"
    echo "12) List all pending/queued txs"
    echo "13) Show raw txpool JSON"
    echo "14) Change default variables"
    echo "0) Exit"
    echo
    read -r -p "Choose an option: " choice
    echo

    case "$choice" in
      1)
        print_header
        show_network_status
        pause
        ;;
      2)
        print_header
        show_recent_blocks 10
        pause
        ;;
      3)
        print_header
        local_block="$DEFAULT_BLOCK"
        read -r -p "Block number/hash/latest [${local_block:-latest}]: " input_block
        if [[ -n "${input_block:-}" ]]; then
          local_block="$input_block"
        fi
        show_block_details "${local_block:-latest}"
        pause
        ;;
      4)
        print_header
        local_block="$DEFAULT_BLOCK"
        read -r -p "Block number/hash/latest [${local_block:-latest}]: " input_block
        if [[ -n "${input_block:-}" ]]; then
          local_block="$input_block"
        fi
        show_block_transactions "${local_block:-latest}"
        pause
        ;;
      5)
        print_header
        show_deployments
        pause
        ;;
      6)
        print_header
        local_addr="$DEFAULT_ADDRESS"
        read -r -p "Address [${local_addr:-none}]: " input_addr
        if [[ -n "${input_addr:-}" ]]; then
          local_addr="$input_addr"
        fi
        if [[ -z "$local_addr" ]]; then
          echo "[ERROR] No address provided"
        else
          show_from "$local_addr"
        fi
        pause
        ;;
      7)
        print_header
        local_hash="$DEFAULT_TX_HASH"
        read -r -p "TX hash [${local_hash:-none}]: " input_hash
        if [[ -n "${input_hash:-}" ]]; then
          local_hash="$input_hash"
        fi
        if [[ -z "$local_hash" ]]; then
          echo "[ERROR] No tx hash provided"
        else
          show_tx "$local_hash"
        fi
        pause
        ;;
      8)
        print_header
        local_hash="$DEFAULT_TX_HASH"
        read -r -p "TX hash [${local_hash:-none}]: " input_hash
        if [[ -n "${input_hash:-}" ]]; then
          local_hash="$input_hash"
        fi
        if [[ -z "$local_hash" ]]; then
          echo "[ERROR] No tx hash provided"
        else
          show_receipt "$local_hash"
        fi
        pause
        ;;
      9)
        watch_chain
        ;;
      10)
        print_header
        show_status
        pause
        ;;
      11)
        print_header
        show_inspect
        pause
        ;;
      12)
        print_header
        show_list
        pause
        ;;
      13)
        print_header
        show_raw
        pause
        ;;
      14)
        change_defaults_menu
        ;;
      0)
        echo "Bye."
        exit 0
        ;;
      *)
        echo "Invalid option"
        pause
        ;;
    esac
  done
}

main() {
  need_bin cast
  need_bin jq
  print_header
  menu
}

main "$@"
