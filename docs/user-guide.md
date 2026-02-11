# User Guide

This guide explains how to interact with the platform once it is deployed.

## 1) Connect Wallet

- Open the frontend or Remix
- Ensure MetaMask is on Sepolia

## 2) Fund the Treasury (Owner)

Before players can place bets, the treasury must be funded.

- Call `fundETH()` and send ETH
- Confirm contract balance increases

## 3) Configure Bet Limits (Owner)

Enable ETH wagers and set a safe range:

```
setTokenConfig(
  0x0000000000000000000000000000000000000000,
  true,
  100000000000000,
  500000000000000
)
```

## 4) Dice Game

1. Call `playDice(token, stake, rollUnder)`
   - token = `0x000...0000` for ETH
   - stake must be within min/max
   - rollUnder between 2 and 99
2. Wait for VRF callback
3. Check `diceBets(diceId)` for result

## 5) Lottery Game

1. Owner creates a round with `createLottery`
2. Players buy tickets with `buyTickets`
3. Owner requests draw with `requestLotteryDraw`
4. VRF selects winner and pays pot

## 6) Troubleshooting

- **"token disabled"**: call `setTokenConfig` first
- **"bad ETH value"**: `msg.value` must equal stake/ticket cost
- **"insufficient liquidity"**: fund the treasury before betting
- **No VRF callback**: ensure contract is added as VRF consumer

