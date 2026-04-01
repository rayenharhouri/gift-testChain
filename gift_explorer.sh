#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Avalanche Subnet-EVM local tx explorer (interactive menu)
# Requires: cast, jq
# ============================================================

# -----------------------------
# Hardcoded config
# -----------------------------
HOST="127.0.0.1"
PORT="9656"
BLOCKCHAIN_ID="2QAg6qzA1GMsBrEfwVZBdoWSa7vqsKcPPpX5JeAZPu3yUNs3ca"
RPC_URL="http://${HOST}:${PORT}/ext/bc/${BLOCKCHAIN_ID}/rpc"
REFRESH_SECS="2"
DEFAULT_ADDRESS=""
DEFAULT_TX_HASH=""

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

rpc() {
  local method="$1"
  shift || true
  cast rpc --rpc-url "$RPC_URL" "$method" "$@"
}

print_header() {
  clear
  cat <<'EOF'
   ██████╗ ██╗███████╗████████╗    ███████╗██╗  ██╗██████╗ ██╗      ██████╗ ██████╗ ███████╗██████╗
  ██╔════╝ ██║██╔════╝╚══██╔══╝    ██╔════╝╚██╗██╔╝██╔══██╗██║     ██╔═══██╗██╔══██╗██╔════╝██╔══██╗
  ██║  ███╗██║█████╗     ██║       █████╗   ╚███╔╝ ██████╔╝██║     ██║   ██║██████╔╝█████╗  ██████╔╝
  ██║   ██║██║██╔══╝     ██║       ██╔══╝   ██╔██╗ ██╔═══╝ ██║     ██║   ██║██╔══██╗██╔══╝  ██╔══██╗
  ╚██████╔╝██║██║        ██║       ███████╗██╔╝ ██╗██║     ███████╗╚██████╔╝██║  ██║███████╗██║  ██║
   ╚═════╝ ╚═╝╚═╝        ╚═╝       ╚══════╝╚═╝  ╚═╝╚═╝     ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝

                              P E N D I N G   T X   C O N S O L E
EOF
  echo
  echo "RPC URL       : $RPC_URL"
  echo "Blockchain ID : $BLOCKCHAIN_ID"
  echo "Refresh (watch): ${REFRESH_SECS}s"
  echo "============================================================"
  echo
}

check_txpool() {
  if ! rpc txpool_status >/dev/null 2>&1; then
    echo "[ERROR] txpool_status failed."
    echo "Possible reasons:"
    echo "  - wrong RPC URL"
    echo "  - wrong blockchain ID"
    echo "  - txpool namespace is not enabled on the node"
    echo
    return 1
  fi
  return 0
}

show_status() {
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
  rpc txpool_content | jq
}

show_from() {
  local addr="$1"
  rpc txpool_contentFrom "$addr" | jq
}

show_tx() {
  local hash="$1"
  rpc eth_getTransactionByHash "$hash" | jq
}

show_receipt() {
  local hash="$1"
  rpc eth_getTransactionReceipt "$hash" | jq
}

watch_mempool() {
  while true; do
    clear
    echo "Watching mempool - refresh every ${REFRESH_SECS}s"
    echo "RPC: $RPC_URL"
    echo
    show_status || true
    echo
    show_list || true
    sleep "$REFRESH_SECS"
  done
}

change_defaults_menu() {
  while true; do
    print_header
    echo "Change hardcoded/runtime defaults"
    echo
    echo "1) Set default address"
    echo "2) Set default tx hash"
    echo "3) Set refresh seconds"
    echo "4) Back"
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
        read -r -p "Enter refresh seconds: " REFRESH_SECS
        ;;
      4)
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
    echo "1) Show txpool status"
    echo "2) Show txpool inspect summary"
    echo "3) List all pending/queued txs"
    echo "4) Show raw txpool JSON"
    echo "5) Explore txs from an address"
    echo "6) Explore one tx by hash"
    echo "7) Show receipt for a tx hash"
    echo "8) Watch mempool live"
    echo "9) Change default variables"
    echo "0) Exit"
    echo
    read -r -p "Choose an option: " choice
    echo

    case "$choice" in
      1)
        print_header
        show_status
        pause
        ;;
      2)
        print_header
        show_inspect
        pause
        ;;
      3)
        print_header
        show_list
        pause
        ;;
      4)
        print_header
        show_raw
        pause
        ;;
      5)
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
      6)
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
          show_receipt "$local_hash"
        fi
        pause
        ;;
      8)
        watch_mempool
        ;;
      9)
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
  if ! check_txpool; then
    exit 1
  fi
  menu
}

main "$@"
