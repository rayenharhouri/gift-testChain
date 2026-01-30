#!/usr/bin/env bash
set -euo pipefail

# =======================
#   GIFT EVENT CONSOLE
# =======================

# ====== ENV (exported) ======
export RPC_URL="${RPC_URL:-http://127.0.0.1:9660/ext/bc/BemccRmcvVQe9bRztLHezN8yFfazG4mw6w2eBA2aJpGWpNq1L/rpc}"
export FROM_BLOCK="${FROM_BLOCK:-0}"
export TO_BLOCK="${TO_BLOCK:-latest}"

export ADDR_MEMBER_REGISTRY="${ADDR_MEMBER_REGISTRY:-0x346b8b3BBe5eEc00AC4a15395DbeA62fE832B784}"
export ADDR_DOCUMENT_REGISTRY="${ADDR_DOCUMENT_REGISTRY:-0xCE2E581aeA029134c42F6CB55dCd4a49e35dbEa9}"
export ADDR_GOLD_ASSET_TOKEN="${ADDR_GOLD_ASSET_TOKEN:-0xF12E5f80f945283D90F74f1592cE6F8Acd0F2f81}"
export ADDR_GOLD_ACCOUNT_LEDGER="${ADDR_GOLD_ACCOUNT_LEDGER:-0xCD33fFF8a07436868583A7785150620Ecc1F9728}"
export ADDR_TX_ORDER_BOOK="${ADDR_TX_ORDER_BOOK:-0x73e208c426E755Ad26c92f7481dCCa8A91C9BF50}"
export ADDR_VAULT_REGISTRY="${ADDR_VAULT_REGISTRY:-0x2107B2650f3dEb51B85092dAe44b20E20929788d}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1"; exit 1; }; }
need cast
need jq

# ====== COLORS ======
if [[ -t 1 ]]; then
  RED="$(tput setaf 1)"; GRN="$(tput setaf 2)"; YEL="$(tput setaf 3)"
  BLU="$(tput setaf 4)"; MAG="$(tput setaf 5)"; CYA="$(tput setaf 6)"
  BOLD="$(tput bold)"; DIM="$(tput dim)"; RST="$(tput sgr0)"
else
  RED=""; GRN=""; YEL=""; BLU=""; MAG=""; CYA=""; BOLD=""; DIM=""; RST=""
fi

hr() { printf "%s\n" "${DIM}────────────────────────────────────────────────────────────────────────────${RST}"; }

banner() {
  clear || true
  echo "${BOLD}${MAG}"
  cat <<'EOF'
   ██████╗ ██╗███████╗████████╗    ███████╗██╗   ██╗███████╗███╗   ██╗████████╗
  ██╔════╝ ██║██╔════╝╚══██╔══╝    ██╔════╝██║   ██║██╔════╝████╗  ██║╚══██╔══╝
  ██║  ███╗██║█████╗     ██║       █████╗  ██║   ██║█████╗  ██╔██╗ ██║   ██║
  ██║   ██║██║██╔══╝     ██║       ██╔══╝  ╚██╗ ██╔╝██╔══╝  ██║╚██╗██║   ██║
  ╚██████╔╝██║██║        ██║       ███████╗ ╚████╔╝ ███████╗██║ ╚████║   ██║
   ╚═════╝ ╚═╝╚═╝        ╚═╝       ╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═══╝   ╚═╝

                           E V E N T   T E S T I N G   C O N S O L E
EOF
  echo "${RST}"
  hr
  echo "${CYA}${BOLD}RPC${RST}: ${RPC_URL}"
  echo "${CYA}${BOLD}Blocks${RST}: FROM_BLOCK=${FROM_BLOCK}  TO_BLOCK=${TO_BLOCK}"
  hr
}

help_screen() {
  echo "${BOLD}Commands:${RST}"
  echo "  ${GRN}<number>${RST}           run event by menu index"
  echo "  ${GRN}<EventName>${RST}        run event by name (case-insensitive)"
  echo "  ${GRN}rpc <url>${RST}          set RPC_URL"
  echo "  ${GRN}addr <KEY> <0x..>${RST}  set address (keys: MEMBER_REGISTRY, DOCUMENT_REGISTRY, GOLD_ASSET_TOKEN, GOLD_ACCOUNT_LEDGER, TX_ORDER_BOOK, VAULT_REGISTRY)"
  echo "  ${GRN}range <from> <to>${RST}  set FROM_BLOCK / TO_BLOCK (to can be 'latest')"
  echo "  ${GRN}show${RST}               show current config"
  echo "  ${GRN}clear${RST}              clear screen"
  echo "  ${GRN}help${RST}               show this help"
  echo "  ${GRN}q${RST} / ${GRN}quit${RST}          exit"
  hr
}

show_config() {
  echo "${BOLD}Config:${RST}"
  echo "  RPC_URL=$RPC_URL"
  echo "  FROM_BLOCK=$FROM_BLOCK"
  echo "  TO_BLOCK=$TO_BLOCK"
  echo "  ADDR_MEMBER_REGISTRY=$ADDR_MEMBER_REGISTRY"
  echo "  ADDR_DOCUMENT_REGISTRY=$ADDR_DOCUMENT_REGISTRY"
  echo "  ADDR_GOLD_ASSET_TOKEN=$ADDR_GOLD_ASSET_TOKEN"
  echo "  ADDR_GOLD_ACCOUNT_LEDGER=$ADDR_GOLD_ACCOUNT_LEDGER"
  echo "  ADDR_TX_ORDER_BOOK=$ADDR_TX_ORDER_BOOK"
  echo "  ADDR_VAULT_REGISTRY=$ADDR_VAULT_REGISTRY"
  hr
}

# ====== EVENT REGISTRY ======
declare -A EVT_ADDR EVT_SIG EVT_DECODE

# GoldAssetToken
EVT_ADDR[AssetMinted]="$ADDR_GOLD_ASSET_TOKEN"
EVT_SIG[AssetMinted]="AssetMinted(uint256,string,string,uint256,uint256,address,uint256)"
EVT_DECODE[AssetMinted]="uint256,string,string,uint256,uint256,address,uint256"

EVT_ADDR[AssetBurned]="$ADDR_GOLD_ASSET_TOKEN"
EVT_SIG[AssetBurned]="AssetBurned(uint256,string,address,address,uint256)"
EVT_DECODE[AssetBurned]="string,uint256"

EVT_ADDR[AssetStatusChanged]="$ADDR_GOLD_ASSET_TOKEN"
EVT_SIG[AssetStatusChanged]="AssetStatusChanged(uint256,uint8,uint8,string,address,uint256)"
EVT_DECODE[AssetStatusChanged]="uint8,uint8,string,uint256"

EVT_ADDR[CustodyChanged]="$ADDR_GOLD_ASSET_TOKEN"
EVT_SIG[CustodyChanged]="CustodyChanged(uint256,address,address,string,uint256)"
EVT_DECODE[CustodyChanged]="string,uint256"

EVT_ADDR[AssetTransferred]="$ADDR_GOLD_ASSET_TOKEN"
EVT_SIG[AssetTransferred]="AssetTransferred(uint256,address,address,uint256)"
EVT_DECODE[AssetTransferred]="uint256"

EVT_ADDR[WarrantLinked]="$ADDR_GOLD_ASSET_TOKEN"
EVT_SIG[WarrantLinked]="WarrantLinked(string,uint256,address,uint256)"
EVT_DECODE[WarrantLinked]="uint256"

EVT_ADDR[OwnershipUpdated]="$ADDR_GOLD_ASSET_TOKEN"
EVT_SIG[OwnershipUpdated]="OwnershipUpdated(uint256,address,address,string,uint256)"
EVT_DECODE[OwnershipUpdated]="string,uint256"

# TransactionOrderBook
EVT_ADDR[OrderCreated]="$ADDR_TX_ORDER_BOOK"
EVT_SIG[OrderCreated]="OrderCreated(string,string,uint8,string,string,uint256,string,uint256,uint8,uint256,uint256)"
EVT_DECODE[OrderCreated]="string,uint8,string,string,uint256,string,uint256,uint8,uint256,uint256"

EVT_ADDR[OrderPrepared]="$ADDR_TX_ORDER_BOOK"
EVT_SIG[OrderPrepared]="OrderPrepared(string,uint256,uint256)"
EVT_DECODE[OrderPrepared]="uint256,uint256"

EVT_ADDR[OrderSigned]="$ADDR_TX_ORDER_BOOK"
EVT_SIG[OrderSigned]="OrderSigned(string,address,string,string,uint256,uint256,uint256)"
EVT_DECODE[OrderSigned]="string,string,uint256,uint256,uint256"

EVT_ADDR[OrderExecuted]="$ADDR_TX_ORDER_BOOK"
EVT_SIG[OrderExecuted]="OrderExecuted(string,uint256,uint256)"
EVT_DECODE[OrderExecuted]="uint256,uint256"

EVT_ADDR[OrderCancelled]="$ADDR_TX_ORDER_BOOK"
EVT_SIG[OrderCancelled]="OrderCancelled(string,string,uint256)"
EVT_DECODE[OrderCancelled]="string,uint256"

EVT_ADDR[OrderFailed]="$ADDR_TX_ORDER_BOOK"
EVT_SIG[OrderFailed]="OrderFailed(string,string,uint256)"
EVT_DECODE[OrderFailed]="string,uint256"

EVT_ADDR[OrderExpired]="$ADDR_TX_ORDER_BOOK"
EVT_SIG[OrderExpired]="OrderExpired(string,uint256)"
EVT_DECODE[OrderExpired]="uint256"

# DocumentRegistry
EVT_ADDR[DocumentRegistered]="$ADDR_DOCUMENT_REGISTRY"
EVT_SIG[DocumentRegistered]="DocumentRegistered(string,string,string,string,string,string,string,uint256,uint256)"
EVT_DECODE[DocumentRegistered]="string,string,string,string,string,uint256,uint256"

EVT_ADDR[DocumentSetRegistered]="$ADDR_DOCUMENT_REGISTRY"
EVT_SIG[DocumentSetRegistered]="DocumentSetRegistered(string,bytes32,string,string,uint256,uint256)"
EVT_DECODE[DocumentSetRegistered]="string,string,uint256,uint256"

EVT_ADDR[DocumentVerified]="$ADDR_DOCUMENT_REGISTRY"
EVT_SIG[DocumentVerified]="DocumentVerified(string,string,bool,uint256)"
EVT_DECODE[DocumentVerified]="string,bool,uint256"

EVT_ADDR[DocumentSuperseded]="$ADDR_DOCUMENT_REGISTRY"
EVT_SIG[DocumentSuperseded]="DocumentSuperseded(string,string,uint256)"
EVT_DECODE[DocumentSuperseded]="uint256"

EVT_ADDR[DocumentRevoked]="$ADDR_DOCUMENT_REGISTRY"
EVT_SIG[DocumentRevoked]="DocumentRevoked(string,string,uint256)"
EVT_DECODE[DocumentRevoked]="string,uint256"

# GoldAccountLedger
EVT_ADDR[AccountCreated]="$ADDR_GOLD_ACCOUNT_LEDGER"
EVT_SIG[AccountCreated]="AccountCreated(string,string,address,string,string,string,uint256,string,uint256)"
EVT_DECODE[AccountCreated]="string,string,string,uint256,string,uint256"

EVT_ADDR[BalanceUpdated]="$ADDR_GOLD_ACCOUNT_LEDGER"
EVT_SIG[BalanceUpdated]="BalanceUpdated(string,int256,uint256,string,uint256,uint256)"
EVT_DECODE[BalanceUpdated]="int256,uint256,string,uint256,uint256"

EVT_ADDR[BalanceUpdaterSet]="$ADDR_GOLD_ACCOUNT_LEDGER"
EVT_SIG[BalanceUpdaterSet]="BalanceUpdaterSet(address,bool,uint256)"
EVT_DECODE[BalanceUpdaterSet]="bool,uint256"

# MemberRegistry
EVT_ADDR[BlacklistUpdated]="$ADDR_MEMBER_REGISTRY"
EVT_SIG[BlacklistUpdated]="BlacklistUpdated(address,bool,address,uint256)"
EVT_DECODE[BlacklistUpdated]="bool,uint256"

EVT_ADDR[MemberRegistered]="$ADDR_MEMBER_REGISTRY"
EVT_SIG[MemberRegistered]="MemberRegistered(string,uint8,address,uint256)"
EVT_DECODE[MemberRegistered]="uint8,uint256"

EVT_ADDR[MemberApproved]="$ADDR_MEMBER_REGISTRY"
EVT_SIG[MemberApproved]="MemberApproved(string,address,uint256)"
EVT_DECODE[MemberApproved]="uint256"

EVT_ADDR[MemberSuspended]="$ADDR_MEMBER_REGISTRY"
EVT_SIG[MemberSuspended]="MemberSuspended(string,string,address,uint256)"
EVT_DECODE[MemberSuspended]="string,uint256"

EVT_ADDR[UserRegistered]="$ADDR_MEMBER_REGISTRY"
EVT_SIG[UserRegistered]="UserRegistered(string,bytes32,address,uint256)"
EVT_DECODE[UserRegistered]="bytes32,uint256"

EVT_ADDR[UserLinkedToMember]="$ADDR_MEMBER_REGISTRY"
EVT_SIG[UserLinkedToMember]="UserLinkedToMember(string,string,address,uint256)"
EVT_DECODE[UserLinkedToMember]="uint256"

EVT_ADDR[RoleAssigned]="$ADDR_MEMBER_REGISTRY"
EVT_SIG[RoleAssigned]="RoleAssigned(string,uint256,address,uint256)"
EVT_DECODE[RoleAssigned]="uint256,uint256"

EVT_ADDR[RoleRevoked]="$ADDR_MEMBER_REGISTRY"
EVT_SIG[RoleRevoked]="RoleRevoked(string,uint256,address,uint256)"
EVT_DECODE[RoleRevoked]="uint256,uint256"

# VaultRegistry
EVT_ADDR[VaultCreated]="$ADDR_VAULT_REGISTRY"
EVT_SIG[VaultCreated]="VaultCreated(string,string,string,string,uint256,uint8,address,uint256)"
EVT_DECODE[VaultCreated]="string,string,uint256,uint8,uint256"

EVT_ADDR[VaultStatusUpdated]="$ADDR_VAULT_REGISTRY"
EVT_SIG[VaultStatusUpdated]="VaultStatusUpdated(string,string,uint8,uint8,string,string,address,uint256)"
EVT_DECODE[VaultStatusUpdated]="uint8,uint8,string,string,uint256"

EVENTS=(
  AssetMinted AssetBurned AssetStatusChanged CustodyChanged AssetTransferred WarrantLinked OwnershipUpdated
  OrderCreated OrderPrepared OrderSigned OrderExecuted OrderCancelled OrderFailed OrderExpired
  DocumentRegistered DocumentSetRegistered DocumentVerified DocumentSuperseded DocumentRevoked
  AccountCreated BalanceUpdated BalanceUpdaterSet
  BlacklistUpdated MemberRegistered MemberApproved MemberSuspended UserRegistered UserLinkedToMember RoleAssigned RoleRevoked
  VaultCreated VaultStatusUpdated
)

print_menu() {
  local i=1
  echo "${BOLD}${YEL}Select an event:${RST}  ${DIM}(type number or name, 'help' for commands)${RST}"
  hr
  for e in "${EVENTS[@]}"; do
    printf " ${CYA}%2d${RST}) ${BOLD}%-20s${RST} ${DIM}%s${RST}\n" "$i" "$e" "${EVT_ADDR[$e]}"
    i=$((i+1))
  done
  hr
}

pretty_title() {
  local evt="$1"
  echo
  hr
  echo "${BOLD}${MAG}▶ $evt${RST}   ${DIM}${EVT_ADDR[$evt]}${RST}"
  echo "${DIM}${EVT_SIG[$evt]}${RST}"
  hr
}

decode_rows() {
  local evt="$1"
  local decode="${EVT_DECODE[$evt]}"
  local logs="$2"

  local count
  count="$(echo "$logs" | jq 'length')"
  echo "${GRN}${BOLD}LOGS:${RST} $count"
  echo

  echo "$logs" | jq -c '.[]' | while read -r row; do
    local data topics block tx idx
    data="$(echo "$row" | jq -r '.data')"
    topics="$(echo "$row" | jq -r '.topics | join(",")')"
    block="$(echo "$row" | jq -r '.blockNumber // .block_number // empty')"
    tx="$(echo "$row" | jq -r '.transactionHash // .txHash // .transaction_hash // empty')"
    idx="$(echo "$row" | jq -r '.logIndex // .index // .log_index // empty')"

    echo "${BOLD}${BLU}LOG${RST} ${DIM}(block:${block:-?} log:${idx:-?})${RST}"
    [[ -n "$tx" ]] && echo "tx:     $tx"
    echo "topics: $topics"
    echo "data:   $data"
    echo "${BOLD}${BLU}DECODE${RST}"
    if [[ "$data" == "0x" || -z "$data" ]]; then
      echo "(empty)"
    else
      cast abi-decode "f()($decode)" "$data"
    fi
    hr
  done
}

run_event() {
  local evt="$1"
  local addr="${EVT_ADDR[$evt]}"
  local sig="${EVT_SIG[$evt]}"

  pretty_title "$evt"

  local logs
  logs="$(cast logs --rpc-url "$RPC_URL" --address "$addr" \
    --from-block "$FROM_BLOCK" --to-block "$TO_BLOCK" \
    "$sig" --json)"

  echo "${BOLD}${BLU}RAW JSON${RST}"
  echo "$logs"
  echo
  echo "${BOLD}${BLU}DECODED${RST}"
  decode_rows "$evt" "$logs"
}

set_rpc() {
  local url="$1"
  export RPC_URL="$url"
  banner
}

set_range() {
  local f="$1" t="$2"
  export FROM_BLOCK="$f"
  export TO_BLOCK="$t"
  banner
}

set_addr() {
  local key="$1" val="$2"
  case "${key^^}" in
    MEMBER_REGISTRY) export ADDR_MEMBER_REGISTRY="$val" ;;
    DOCUMENT_REGISTRY) export ADDR_DOCUMENT_REGISTRY="$val" ;;
    GOLD_ASSET_TOKEN) export ADDR_GOLD_ASSET_TOKEN="$val" ;;
    GOLD_ACCOUNT_LEDGER) export ADDR_GOLD_ACCOUNT_LEDGER="$val" ;;
    TX_ORDER_BOOK) export ADDR_TX_ORDER_BOOK="$val" ;;
    VAULT_REGISTRY) export ADDR_VAULT_REGISTRY="$val" ;;
    *) echo "invalid key"; return 0 ;;
  esac

  # refresh registry pointers (so future lookups reflect new addrs)
  EVT_ADDR[AssetMinted]="$ADDR_GOLD_ASSET_TOKEN"
  EVT_ADDR[AssetBurned]="$ADDR_GOLD_ASSET_TOKEN"
  EVT_ADDR[AssetStatusChanged]="$ADDR_GOLD_ASSET_TOKEN"
  EVT_ADDR[CustodyChanged]="$ADDR_GOLD_ASSET_TOKEN"
  EVT_ADDR[AssetTransferred]="$ADDR_GOLD_ASSET_TOKEN"
  EVT_ADDR[WarrantLinked]="$ADDR_GOLD_ASSET_TOKEN"
  EVT_ADDR[OwnershipUpdated]="$ADDR_GOLD_ASSET_TOKEN"

  EVT_ADDR[OrderCreated]="$ADDR_TX_ORDER_BOOK"
  EVT_ADDR[OrderPrepared]="$ADDR_TX_ORDER_BOOK"
  EVT_ADDR[OrderSigned]="$ADDR_TX_ORDER_BOOK"
  EVT_ADDR[OrderExecuted]="$ADDR_TX_ORDER_BOOK"
  EVT_ADDR[OrderCancelled]="$ADDR_TX_ORDER_BOOK"
  EVT_ADDR[OrderFailed]="$ADDR_TX_ORDER_BOOK"
  EVT_ADDR[OrderExpired]="$ADDR_TX_ORDER_BOOK"

  EVT_ADDR[DocumentRegistered]="$ADDR_DOCUMENT_REGISTRY"
  EVT_ADDR[DocumentSetRegistered]="$ADDR_DOCUMENT_REGISTRY"
  EVT_ADDR[DocumentVerified]="$ADDR_DOCUMENT_REGISTRY"
  EVT_ADDR[DocumentSuperseded]="$ADDR_DOCUMENT_REGISTRY"
  EVT_ADDR[DocumentRevoked]="$ADDR_DOCUMENT_REGISTRY"

  EVT_ADDR[AccountCreated]="$ADDR_GOLD_ACCOUNT_LEDGER"
  EVT_ADDR[BalanceUpdated]="$ADDR_GOLD_ACCOUNT_LEDGER"
  EVT_ADDR[BalanceUpdaterSet]="$ADDR_GOLD_ACCOUNT_LEDGER"

  EVT_ADDR[BlacklistUpdated]="$ADDR_MEMBER_REGISTRY"
  EVT_ADDR[MemberRegistered]="$ADDR_MEMBER_REGISTRY"
  EVT_ADDR[MemberApproved]="$ADDR_MEMBER_REGISTRY"
  EVT_ADDR[MemberSuspended]="$ADDR_MEMBER_REGISTRY"
  EVT_ADDR[UserRegistered]="$ADDR_MEMBER_REGISTRY"
  EVT_ADDR[UserLinkedToMember]="$ADDR_MEMBER_REGISTRY"
  EVT_ADDR[RoleAssigned]="$ADDR_MEMBER_REGISTRY"
  EVT_ADDR[RoleRevoked]="$ADDR_MEMBER_REGISTRY"

  EVT_ADDR[VaultCreated]="$ADDR_VAULT_REGISTRY"
  EVT_ADDR[VaultStatusUpdated]="$ADDR_VAULT_REGISTRY"

  banner
}

# ====== MAIN LOOP ======
banner
help_screen

while true; do
  print_menu
  printf "${BOLD}${GRN}gift>${RST} "
  IFS= read -r line || exit 0
  [[ -z "${line// }" ]] && continue

  cmd="${line%% *}"
  rest="${line#"$cmd"}"
  rest="${rest# }"

  case "${cmd,,}" in
    q|quit|exit) exit 0 ;;
    clear) banner; continue ;;
    help|\?) help_screen; continue ;;
    show) show_config; continue ;;
    rpc)
      [[ -z "$rest" ]] && { echo "rpc <url>"; continue; }
      set_rpc "$rest"
      continue
      ;;
    range)
      f="$(awk '{print $1}' <<<"$rest")"
      t="$(awk '{print $2}' <<<"$rest")"
      [[ -z "$f" || -z "$t" ]] && { echo "range <from> <to>"; continue; }
      set_range "$f" "$t"
      continue
      ;;
    addr)
      k="$(awk '{print $1}' <<<"$rest")"
      v="$(awk '{print $2}' <<<"$rest")"
      [[ -z "$k" || -z "$v" ]] && { echo "addr <KEY> <0x..>"; continue; }
      set_addr "$k" "$v"
      continue
      ;;
  esac

  # number selection
  if [[ "$cmd" =~ ^[0-9]+$ ]]; then
    n="$cmd"
    if (( n >= 1 && n <= ${#EVENTS[@]} )); then
      run_event "${EVENTS[$((n-1))]}"
    else
      echo "invalid"
    fi
    continue
  fi

  # name selection
  found=""
  for e in "${EVENTS[@]}"; do
    if [[ "${e,,}" == "${cmd,,}" ]]; then found="$e"; break; fi
  done

  if [[ -n "$found" ]]; then
    run_event "$found"
  else
    echo "invalid"
  fi
done
