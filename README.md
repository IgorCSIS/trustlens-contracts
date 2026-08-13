# TrustLens — Contracts

On-chain monetization layer for **TrustLens**, an AI-native smart-contract safety scanner.
Users pay a small fee (on **Base**, where fees are ~$0.02) to unlock a deep AI risk
report for a target contract. This repo holds the Solidity that gates access.

> **Milestone status:** M1 complete — `PaymentGate` written, fully tested (15/15,
> incl. fuzz), and verified end-to-end against a local node.

## What's here

| File | Purpose |
|------|---------|
| `src/PaymentGate.sol` | Pay-per-scan + time-pass payment gate. Emits `ScanPurchased` (backend listens for this) and `PassPurchased`. Owner sets prices and withdraws. |
| `test/PaymentGate.t.sol` | 15 tests: happy paths, reverts, access control, withdraw, 2 fuzz tests. |
| `script/Deploy.s.sol` | Deploy script with env-configurable prices and testnet defaults. |

## Product model

- **Pay-per-scan** — pay `scanPrice`, get one deep report for one target contract.
  The backend matches the on-chain `paymentId` to the report request.
- **Time pass** — pay `passPrice` for `passDuration` of unlimited scans. Backend
  checks `hasActivePass(user)`.

## Quickstart

```bash
# build + test
forge build
forge test -vv

# run a local chain and deploy against it (uses a public test key, local only)
anvil --silent &
forge script script/Deploy.s.sol:DeployPaymentGate \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

## Deploying to Base Sepolia (testnet)

1. Copy env: `cp .env.example .env` and fill in an RPC (the public
   `https://sepolia.base.org` works).
2. Get free testnet ETH from a Base Sepolia faucet for your own wallet.
3. **Import your key into an encrypted keystore** (recommended — never paste a raw
   key for anything you care about):
   ```bash
   cast wallet import deployer --interactive
   ```
4. Deploy:
   ```bash
   source .env
   forge script script/Deploy.s.sol:DeployPaymentGate \
     --rpc-url base_sepolia --account deployer --broadcast --verify -vvvv
   ```

> **Security note:** your private key lives only on your machine, in an encrypted
> keystore or your local `.env` (which is gitignored). It is never committed and
> never leaves your computer.

## Roadmap

- **M1 ✅** PaymentGate contract + tests + local deploy verified
- **M2** Backend: address → fetch source → Slither static analysis → raw findings
- **M3** AI reasoning layer → plain-English risk report + confidence score
- **M4** Frontend (Next.js + wagmi), wallet connect, wire paywall to M1
- **M5** Transaction-simulation layer (real honeypot / sellability check)
- **M6+** Safe execution: protected routing → pre-trade guard → scan-protect-execute
