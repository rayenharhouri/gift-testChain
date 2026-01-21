# Demo Scenarios (API -> On-chain Evidence)

This document provides visual, client-friendly scenarios showing each API call
and the corresponding on-chain state change or event. Use it as a script for
presentations and as a checklist for live demos.

## Roles Used in Demo
- GMO (admin)
- REFINER
- MINTER
- TRADER
- VAULT
- LSP
- AUDITOR (read-only)

## Pre-Demo Configuration
- Set balance updater so `GoldAssetToken.mint/burn` can credit/debit accounts:
  - `GoldAccountLedger.setBalanceUpdater(GoldAssetToken, true)`
- (Optional) Enable on-chain execution flow for orders:
  - `TransactionOrderBook.setExecutionOptions(true, true)`

## Scenario 1: Member Onboarding + Roles + Users

What we show: onboarding of an organization and its users.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client

    R1[POST /members/create]:::api --> MR[MemberRegistry]:::contract --> E1((MemberRegistered)):::event
    R2[POST /members/:gic/role]:::api --> MR --> E2((RoleAssigned)):::event
    R3[POST /users/create]:::api --> MR --> E3((UserRegistered)):::event
    R4[POST /users/link-member]:::api --> MR --> E4((UserLinkedToMember)):::event

    C --> R1
    C --> R2
    C --> R3
    C --> R4

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
```

On-chain evidence:
- `MemberRegistered`
- `RoleAssigned`
- `UserRegistered`
- `UserLinkedToMember`

## Scenario 2: Vault Site + Vault Setup

What we show: a VAULT member creates a vault site and vaults.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client

    R1[POST /vault-sites/create]:::api --> VSR[VaultSiteRegistry]:::contract --> E1((VaultSiteCreated)):::event
    R2[POST /vaults/create]:::api --> VR[VaultRegistry]:::contract --> E2((VaultCreated)):::event

    C --> R1
    C --> R2

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
```

On-chain evidence:
- `VaultSiteCreated`
- `VaultCreated`

## Scenario 3: Create IGAN Account

What we show: a member creates an IGAN account.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client
    R1[POST /accounts/create]:::api --> GAL[GoldAccountLedger]:::contract --> E1((AccountCreated)):::event
    C --> R1

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
```

On-chain evidence:
- `AccountCreated`

## Scenario 4: Mint Asset + Ledger Credit

What we show: a refiner or minter mints an asset and the ledger is credited.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client
    R1[POST /assets/register]:::api --> GAT[GoldAssetToken]:::contract --> E1((AssetMinted)):::event
    GAT --> U1[updateBalanceFromContract delta=1]:::chain --> GAL[GoldAccountLedger]:::contract --> E2((BalanceUpdated)):::event
    C --> R1

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
    classDef chain fill:#dbeafe,stroke:#60a5fa,color:#0f172a;
```

On-chain evidence:
- `AssetMinted`
- `BalanceUpdated` (credit)

## Scenario 5: Document Anchoring

What we show: upload a document, then register a document set (SOD).

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client
    R1[POST /documents/upload]:::api --> DR[DocumentRegistry]:::contract --> E1((DocumentRegistered)):::event
    R2[POST /documents/upload-set]:::api --> DR --> E2((DocumentSetRegistered)):::event
    C --> R1
    C --> R2

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
```

On-chain evidence:
- `DocumentRegistered`
- `DocumentSetRegistered`

## Scenario 6: Transaction Order Lifecycle

What we show: create, prepare, sign, execute.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client

    R1[POST /transactions/create]:::api --> TOB[TransactionOrderBook]:::contract --> E1((OrderCreated)):::event
    R2[POST /transactions/:ref/prepare]:::api --> TOB --> E2((OrderPrepared)):::event
    R3[POST /transactions/:ref/sign]:::api --> TOB --> E3((OrderSigned)):::event
    R4[POST /transactions/:ref/execute]:::api --> TOB --> E4((OrderExecuted)):::event

    C --> R1
    C --> R2
    C --> R3
    C --> R4

    TOB -.-> GAT[GoldAssetToken transfer]:::chain
    TOB -.-> GAL[GoldAccountLedger update]:::chain

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
    classDef chain fill:#dbeafe,stroke:#60a5fa,color:#0f172a;
```

On-chain evidence:
- `OrderCreated`
- `OrderPrepared`
- `OrderSigned`
- `OrderExecuted`
- Optional: `OwnershipUpdated` (transfer) + `BalanceUpdated` (ledger)

## Scenario 7: Custody Update + Transfer

What we show: custody metadata and transfer between owners.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client

    R1[PUT /assets/:token_id/custody]:::api --> GAT[GoldAssetToken]:::contract --> E1((CustodyChanged)):::event
    R2[POST /assets/transfer]:::api --> GAT --> E2((OwnershipUpdated)):::event

    C --> R1
    C --> R2

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
```

On-chain evidence:
- `CustodyChanged`
- `OwnershipUpdated`

## Scenario 8: Burn Asset + Ledger Debit

What we show: burn asset and ledger debit.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client
    R1[POST /assets/:token_id/burn]:::api --> GAT[GoldAssetToken]:::contract --> E1((AssetBurned)):::event
    GAT --> U1[updateBalanceFromContract delta=-1]:::chain --> GAL[GoldAccountLedger]:::contract --> E2((BalanceUpdated)):::event
    C --> R1

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
    classDef chain fill:#dbeafe,stroke:#60a5fa,color:#0f172a;
```

On-chain evidence:
- `AssetBurned`
- `BalanceUpdated` (debit)

## Optional Scenario: Compliance / Blacklist

What we show: block transfers for blacklisted addresses.

```mermaid
%%{init: {'theme':'base','themeVariables':{'primaryColor':'#eef2ff','primaryTextColor':'#0f172a','primaryBorderColor':'#6366f1','lineColor':'#6366f1','fontFamily':'\"Space Grotesk\", \"Segoe UI\", sans-serif'}}}%%
flowchart TB
    C[Client]:::client

    R1[POST /members/:gic/blacklist]:::api --> MR[MemberRegistry]:::contract --> E1((BlacklistUpdated)):::event
    R2[POST /assets/transfer]:::api --> GAT[GoldAssetToken]:::contract --> E2((Revert: Address blacklisted)):::warn

    C --> R1
    C --> R2

    classDef client fill:#0f172a,stroke:#0f172a,color:#ffffff;
    classDef api fill:#2563eb,stroke:#2563eb,color:#ffffff;
    classDef contract fill:#e2e8f0,stroke:#94a3b8,color:#0f172a;
    classDef event fill:#fff7ed,stroke:#fb923c,color:#9a3412;
    classDef warn fill:#fee2e2,stroke:#ef4444,color:#7f1d1d;
```

On-chain evidence:
- `BlacklistUpdated`
- Transfer reverted on-chain
