# TrustLens — Contracts

<p align="center">
  <img alt="Solidity" src="https://img.shields.io/badge/Solidity-0.8.24-363636?style=flat-square&labelColor=3E2230" />
  <img alt="Foundry" src="https://img.shields.io/badge/built_with-Foundry-000000?style=flat-square&labelColor=3E2230" />
  <img alt="Tests" src="https://img.shields.io/badge/tests-passing-3FCF8E?style=flat-square&labelColor=3E2230" />
  <img alt="Base" src="https://img.shields.io/badge/deployed-Base_Sepolia-0052FF?style=flat-square&labelColor=3E2230" />
</p>

The on-chain monetization layer for **TrustLens**, an AI smart-contract safety
scanner. `PaymentGate` gates access to the paid AI report: a user pays a small
fee on **Base** and the backend verifies the payment on-chain before returning a
report. Payments are built but currently dark (TrustLens is in free beta), so
this is the code that turns the product on when the time comes.

### Part of TrustLens · the first tool in the [SafuLens](https://x.com/SafuLens) suite
- **[Live app](https://trustlens-web.niftyai.workers.dev)** — try the scanner, no wallet or signup
- **[Frontend](https://github.com/IgorCSIS/trustlens-web)** — React + wagmi/viem
- **[Backend](https://github.com/IgorCSIS/trustlens-backend)** — FastAPI + Slither + Claude
- **Contracts** (this repo) — Foundry `PaymentGate`

**Deployed:** `PaymentGate` on Base Sepolia at [`0x93F37c9af6b4dB4c51DD3CD1a742a4D9AdC878Ca`](https://sepolia.basescan.org/address/0x93F37c9af6b4dB4c51DD3CD1a742a4D9AdC878Ca).

---

## What's here

| File | Purpose |
|------|---------|
| `src/PaymentGate.sol` | Pay-per-scan + monthly pass. `Ownable` + `ReentrancyGuard`, custom errors, exact-payment invariant. Emits `ScanPurchased` (the backend verifies this) and `PassPurchased`. |
| `test/PaymentGate.t.sol` | Unit + fuzz tests: happy paths, reverts, access control, withdraw, pass lifecycle. |
| `test/ProxyResolution.t.sol` | Base-fork test that locks the backend's proxy storage-slot resolution against live USDC. |
| `script/Deploy.s.sol` | Deploy script with env-configurable prices and testnet defaults. |

## Product model

- **Pay-per-scan** — pay `scanPrice`, get one deep report for one target. The
  backend matches the on-chain `paymentId` to the report request and consumes it
  once (anti-replay).
- **Monthly pass** — pay `passPrice` for `passDuration` of unlimited scans. The
  backend checks `hasActivePass(user)`.

## Quickstart

```bash
forge build
forge test -vv                          # unit + fuzz
forge test --match-contract ProxyResolution   # Base-fork slot test
```

## Deploy to Base Sepolia

```bash
cp .env.example .env          # set an RPC; the public https://sepolia.base.org works
cast wallet import deployer --interactive   # encrypted keystore, never a raw key
forge script script/Deploy.s.sol:DeployPaymentGate \
  --rpc-url base_sepolia --account deployer --broadcast --verify -vvvv
```

## Security posture

- The owner key controls prices and withdrawals. On a real mainnet deployment it
  should be a multisig (Safe), not a hot EOA, and the key must never live on the
  backend server.
- `withdraw` uses a checked `.call`, has a zero-address guard, and is
  `nonReentrant`.
- Private keys stay on your machine in an encrypted keystore or a gitignored
  `.env`. Nothing sensitive is committed (verified: no `.env` in history).
- Before this contract holds real funds: run Slither + Aderyn + Mythril, add
  Foundry invariant tests, and get a community review. It is unaudited today.

## License

[MIT](LICENSE)
