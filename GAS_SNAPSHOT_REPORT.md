# Gas Snapshot Report

Made by Rayen Harhouri.

## Purpose
Provide a review-ready gas baseline for the smart contract test suite, with charted hotspots to support US-11 quality-gate review.

## Snapshot Context
- Snapshot date: `2026-02-20`
- Source file: `.gas-snapshot`
- Snapshot entries: `142` tests
- Generation command:
```bash
forge snapshot
forge snapshot --check
```
- Exclusions: none.

## Headline Metrics
| Metric | Value |
|---|---:|
| Total tests in snapshot | `142` |
| Total gas (all tests) | `48891994` |
| Average gas per test | `344309.82` |
| Median (P50) | `284139` |
| P90 | `633047` |
| P95 | `802289` |
| P99 | `1754113` |
| Min gas test | `11535` |
| Max gas test | `2326852` |

## Percentile Chart
Bars are normalized to the max test gas (`2326852`).

| Marker | Gas | Chart |
|---|---:|---|
| `Min` | 11535 | # |
| `P50` | 284139 | ## |
| `P90` | 633047 | ##### |
| `P95` | 802289 | ####### |
| `P99` | 1754113 | ############### |
| `Max` | 2326852 | #################### |

## Suite Contribution Chart (By Total Gas)
Bars are normalized to the highest suite total (`GoldAssetTokenTest`).

| Suite | Tests | Total Gas | Share | Avg/Test | Min | Max | Chart |
|---|---:|---:|---:|---:|---:|---:|---|
| `GoldAssetTokenTest` | 24 | 12950411 | 26.49% | 539600 | 11862 | 1002773 | #################### |
| `GoldAccountLedgerTest` | 20 | 6280559 | 12.85% | 314028 | 11535 | 591105 | ########## |
| `TransactionOrderBookAdditionalTest` | 10 | 5232232 | 10.70% | 523223 | 23364 | 2326852 | ######## |
| `VaultRegistryTest` | 18 | 4555267 | 9.32% | 253070 | 16689 | 907822 | ####### |
| `VaultSiteRegistryTest` | 19 | 4361792 | 8.92% | 229568 | 22143 | 1754113 | ####### |
| `DocumentRegistryTest` | 14 | 3971149 | 8.12% | 283654 | 15631 | 715999 | ###### |
| `MemberRegistryTest` | 14 | 3714219 | 7.60% | 265301 | 184727 | 421488 | ###### |
| `GoldAssetTokenAdditionalTest` | 9 | 2918131 | 5.97% | 324237 | 49199 | 444908 | ##### |
| `MemberRegistryAdditionalTest` | 9 | 1818707 | 3.72% | 202079 | 26456 | 260078 | ### |
| `IntegrationFlowTest` | 1 | 1510345 | 3.09% | 1510345 | 1510345 | 1510345 | ## |
| `TransactionOrderBookTest` | 2 | 1215636 | 2.49% | 607818 | 427909 | 787727 | ## |
| `GoldAccountLedgerAdditionalTest` | 2 | 363546 | 0.74% | 181773 | 16011 | 347535 | # |

## Top 10 Highest-Gas Tests
Bars are normalized to the highest single test gas.

| Test | Gas | Chart |
|---|---:|---|
| `TransactionOrderBookAdditionalTest:test_SetMemberRegistry_OnlyOwner_And_Updates()` | 2326852 | #################### |
| `VaultSiteRegistryTest:test_GetVaultSiteIds_Multiple()` | 1754113 | ############### |
| `IntegrationFlowTest:test_EndToEnd_Flow()` | 1510345 | ############# |
| `GoldAssetTokenTest:test_GetAssetsByOwner()` | 1002773 | ######### |
| `GoldAssetTokenTest:test_DuplicateSerialAllowed()` | 997143 | ######### |
| `VaultRegistryTest:test_GetVaultIdsBySite_Multiple()` | 907822 | ######## |
| `TransactionOrderBookAdditionalTest:test_UpdateOrderStatus_Executed_SetsExecutedAt()` | 834446 | ####### |
| `GoldAssetTokenTest:test_Reentrancy_SafeTransfer_DoesNotCorruptAssetOwner()` | 802289 | ####### |
| `TransactionOrderBookTest:test_PrepareSignFlow()` | 787727 | ####### |
| `DocumentRegistryTest:test_UploadDocumentBatch_Succeeds()` | 715999 | ###### |

## Gas Distribution Chart (By Test Count)
| Gas Bucket | Tests | Share | Chart |
|---|---:|---:|---|
| `250k-500k` | 46 | 32.39% | #################### |
| `<50k` | 36 | 25.35% | ################ |
| `500k-1M` | 34 | 23.94% | ############### |
| `100k-250k` | 13 | 9.15% | ###### |
| `50k-100k` | 9 | 6.34% | #### |
| `>=1M` | 4 | 2.82% | ## |

## Interpretation
- Main gas concentration is in large data-path tests (`GetVaultSiteIds_Multiple`, `GetAssetsByOwner`) and integration/order orchestration tests.
- `TransactionOrderBookAdditionalTest:test_SetMemberRegistry_OnlyOwner_And_Updates()` is the current peak and should be monitored for regressions.
- The distribution is healthy for unit-testing: most tests stay below `500k`, with a small high-gas tail reserved for integration-style flows.

## Refresh Procedure
```bash
forge snapshot
forge snapshot --check
```
Then update this file with the new numbers/charts.
