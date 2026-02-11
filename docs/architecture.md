# Architecture

## System Design

The platform is a single on-chain protocol contract with two game modes (Lottery + Dice) and a shared treasury. Randomness comes from Chainlink VRF v2.5 and is consumed via asynchronous callbacks. The design focuses on deterministic state transitions, explicit balance accounting, and replay-safe request handling.

### Core Objectives

- **Provable fairness** using VRF randomness
- **Safe treasury management** with locked funds accounting
- **Clear separation of lifecycle stages** for each game
- **Minimal trusted roles** (owner-only administrative actions)

## Components

### 1) RandomGamePlatform (core contract)
- Owns the treasury and game state
- Tracks token configurations (min/max, enabled)
- Requests VRF randomness for lottery draws and dice resolution
- Resolves payouts on VRF callback

### 2) Chainlink VRF v2.5
- External randomness oracle
- Uses subscription model with consumer list
- Asynchronous callback to `fulfillRandomWords`

### 3) Players
- Submit wagers (ETH or ERC-20)
- Receive payouts when bets resolve

## State Model

### Lottery
- **Created**: start/end time set, no entries
- **Active**: users buy tickets
- **Draw Requested**: owner requests VRF
- **Drawn**: winner resolved and paid

### Dice
- **Placed**: user submits stake and rollUnder
- **Pending**: VRF request stored
- **Resolved**: roll determined, payout applied

## Balance & Risk Control

- **tokenConfigs**: per-token `enabled`, `minBet`, `maxBet`
- **lockedFunds**: amount reserved for pending payouts
- **_canLock**: ensures contract can cover potential payouts

## Component Interaction

### Dice Flow

1. Player calls `playDice(token, stake, rollUnder)` with `msg.value` equal to stake for ETH.
2. Contract validates token config and liquidity, records bet, and requests VRF.
3. VRF coordinator calls `fulfillRandomWords`.
4. Contract resolves the roll and pays out if the bet wins.

### Lottery Flow

1. Owner creates a round using `createLottery`.
2. Players buy tickets using `buyTickets`.
3. Owner calls `requestLotteryDraw` after end time.
4. VRF callback resolves winner and pays the pot.

## Trust & Permissions

- Owner role controls configuration and lottery draw requests.
- No privileged path can alter VRF outcomes.
- All randomness-sensitive actions occur on callback.

## Failure Handling

- VRF request failures are handled by re-requesting as needed.
- Invalid states are rejected via explicit `require` checks.

