# On-Chain Verifiable Random Game Platform

A Sepolia-focused, verifiably fair game platform powered by Chainlink VRF v2.5. The project delivers two core games (Lottery + Dice), supports ETH and ERC-20 wagering, and emphasizes transparent randomness, clean state transitions, and deterministic payout logic.

## Project Snapshot

- **Network target**: Ethereum Sepolia
- **Language**: Solidity 0.8.20
- **Framework**: Foundry
- **Randomness**: Chainlink VRF v2.5
- **Security modules**: OpenZeppelin (ReentrancyGuard, SafeERC20)

## What’s Implemented

### Games
- **Lottery (time-based draw)**
  - Create a round with start/end time
  - Users buy tickets during the active window
  - Owner requests a VRF draw after end time
  - Winner is determined on-chain via VRF

- **Dice (multiplier bet)**
  - User chooses `rollUnder` (2–99)
  - Payout scales by odds and house edge
  - VRF determines the roll and resolves the bet

### Treasury & Risk Controls
- Token-specific **min/max bet** limits
- **Locked funds** tracking to prevent over-commitment
- Explicit **funding** methods for ETH or ERC-20

### VRF Integration
- VRF config stored on-chain
- Request/fulfill lifecycle tracked per bet or draw

## Repository Layout

```
.
├── foundry.toml
├── remappings.txt
├── .env.example
├── src/
│   └── RandomGamePlatform.sol
├── test/
│   └── RandomGamePlatform.t.sol
├── script/
│   └── Deploy.s.sol
├── docs/
│   ├── architecture.md
│   ├── CHAINLINK_VRF_SETUP.md
│   ├── gas-optimization.md
│   └── security-analysis.md
└── frontend/
    └── (React UI)
```

## Core Contract Interface (Current)

### Lottery
- `createLottery(address token, uint256 ticketPrice, uint256 startTime, uint256 endTime)`
- `buyTickets(uint256 lotteryId, uint256 count)`
- `requestLotteryDraw(uint256 lotteryId)`
- `getLotteryEntryCount(uint256 lotteryId)`
- `getLotteryEntry(uint256 lotteryId, uint256 index)`

### Dice
- `playDice(address token, uint256 stake, uint8 rollUnder)`
- `diceBets(uint256 diceId)`
- `calcDicePayout(uint256 stake, uint8 rollUnder)`

### Admin & Treasury
- `setTokenConfig(address token, bool enabled, uint256 minBet, uint256 maxBet)`
- `setHouseEdgeBps(uint256 newBps)`
- `fundETH()`
- `fundToken(address token, uint256 amount)`
- `withdraw(address token, uint256 amount, address to)`

### VRF
- `getVRFConfig()`
- `setVRFConfig(bytes32 keyHash, uint256 subId, uint16 requestConfirmations, uint32 callbackGasLimit, bool nativePayment)`

## Quick Start (Local)

```bash
# Install deps
forge install

# Build
forge build

# Test
forge test -vv
```

## Sepolia Deployment (Foundry)

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

After deployment:
1) Add the contract as a **VRF consumer** in the Chainlink subscription.
2) Set token config (ETH) and fund the contract.

Example config (ETH):
```
setTokenConfig(
  0x0000000000000000000000000000000000000000,
  true,
  100000000000000,
  500000000000000
)
```

## Frontend (React)

The `frontend/` folder contains a React + ethers v6 UI for:
- wallet connection
- treasury funding
- token config
- dice and lottery flows

```bash
cd frontend
npm install
npm run dev
```

## Notes

- VRF subscriptions must be funded and include the contract as a consumer.
- Dice payouts require sufficient treasury balance to cover worst-case outcomes.
- All amounts are in Wei unless otherwise stated.

## License

MIT
