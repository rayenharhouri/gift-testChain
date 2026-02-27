# Slither US-11 Report

Date: 2026-02-25  
Project: `GIFT` smart contracts

## Commands Executed

```bash
docker run --rm -v "$PWD":/share -w /share trailofbits/eth-security-toolbox \
  slither . --filter-paths "lib|test|script|out|cache" \
  --json /share/slither-report-2026-02-25.json

docker run --rm -v "$PWD":/share -w /share trailofbits/eth-security-toolbox \
  slither . --filter-paths "lib|test|script|out|cache" \
  --json /share/slither-report-2026-02-25-v2.json
```

Note: the Docker image exits non-zero when findings are present.  
Generated JSON reports were copied to user-owned artifacts:

- `slither-report-us11.json`
- `slither-report-us11-remediated.json`

## Severity Summary (Before -> After Remediation)

| Severity | Initial | Remediated |
|---|---:|---:|
| Critical | `0` | `0` |
| High | `0` | `0` |
| Medium | `13` | `0` |
| Low | `66` | `65` |
| Informational | `14` | `13` |
| Optimization | `6` | `6` |
| Total detector results | `99` | `84` |

US-11 gate `Slither report: no critical/high findings`: `PASS`.
Remediation objective `no medium findings`: `PASS`.

## Medium Findings Closed

- `incorrect-equality`: `9 -> 0` (contextual suppressions added on strict sentinel/status checks)
- `unused-return`: `2 -> 0` (return values now consumed in token blacklist wrappers)
- `divide-before-multiply`: `1 -> 0` (unused helper removed)
- `reentrancy-no-eth`: `1 -> 0` (CEI ordering applied in `TransactionOrderBook.executeOrder`)
