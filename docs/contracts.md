# Contract Documentation (NatSpec Overview)

This document summarizes all public/external functions from `RandomGamePlatform.sol`. The contract itself already includes NatSpec comments; use this as a quick reference.

## Admin / Configuration

### `setTokenConfig(address token, bool enabled, uint256 minBet, uint256 maxBet)`
Enables/disables a token and sets the bet range. `token=address(0)` represents ETH.

### `setHouseEdgeBps(uint256 newBps)`
Updates the dice house edge (in basis points). Capped at 10%.

### `setVRFConfig(bytes32 keyHash, uint256 subId, uint16 requestConfirmations, uint32 callbackGasLimit, bool nativePayment)`
Updates the VRF configuration used for all randomness requests.

### `withdraw(address token, uint256 amount, address to)`
Withdraws available (unlocked) funds to a recipient.

## Lottery

### `createLottery(address token, uint256 ticketPrice, uint256 startTime, uint256 endTime)`
Creates a time-based lottery round.

### `buyTickets(uint256 lotteryId, uint256 count)`
Buys lottery tickets for the active round. For ETH, `msg.value` must equal `ticketPrice * count`.

### `requestLotteryDraw(uint256 lotteryId)`
Requests a VRF draw after the lottery ends. Only owner.

### `getLotteryEntryCount(uint256 lotteryId)`
Returns the number of entries in a lottery.

### `getLotteryEntry(uint256 lotteryId, uint256 index)`
Returns the entry address at `index`.

### `lotteries(uint256 lotteryId)`
Public getter for round state (start/end, token, ticketPrice, pot, winner, request state).

## Dice

### `playDice(address token, uint256 stake, uint8 rollUnder)`
Places a dice bet. For ETH, `msg.value` must equal `stake`.

### `calcDicePayout(uint256 stake, uint8 rollUnder)`
Pure payout quote based on stake, odds, and house edge.

### `diceBets(uint256 diceId)`
Public getter for dice bet details (stake, rollUnder, payout, resolution).

## Treasury

### `fundETH()`
Deposits ETH into the contract treasury.

### `fundToken(address token, uint256 amount)`
Deposits ERC-20 tokens into the contract treasury.

### `lockedFunds(address token)`
Returns funds reserved for unresolved payouts.

### `tokenConfigs(address token)`
Returns token configuration (enabled, minBet, maxBet).

## VRF

### `getVRFConfig()`
Returns current VRF settings (coordinator, keyHash, subId, callbackGasLimit).

## Read-Only State

### `houseEdgeBps()`
Current house edge in basis points.

### `nextDiceId()`
Next dice bet ID to be created.

### `nextLotteryId()`
Next lottery ID to be created.

