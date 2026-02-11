# Deployment Guide (Step by Step)

This guide targets **Sepolia** and Chainlink VRF v2.5.

## 1) Prerequisites

- Sepolia ETH for gas
- Chainlink VRF subscription funded
- Foundry installed (optional if using Remix)

## 2) Prepare Environment

Create `.env` from `.env.example` and fill:

```
SEPOLIA_RPC_URL=<your RPC URL>
PRIVATE_KEY=0x<your private key>
SUBSCRIPTION_ID=<your VRF subscription id>
```

## 3) Deploy with Foundry (recommended)

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

Record the deployed contract address.

## 4) Add VRF Consumer

Open the Chainlink VRF subscription page and add the deployed contract as a consumer.

## 5) Configure Token Limits

Example for ETH (0.0001–0.0005 ETH):
```
setTokenConfig(
  0x0000000000000000000000000000000000000000,
  true,
  100000000000000,
  500000000000000
)
```

## 6) Fund the Treasury

Call `fundETH()` and send a value (e.g., 0.001 ETH).

## 7) Verify

- Confirm contract balance increased.
- Call `getVRFConfig()` to verify VRF settings.

---

# Remix Alternative

1) Compile `RandomGamePlatform.sol`
2) Deploy with constructor params:
   - vrfCoordinator: `0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625`
   - keyHash: `0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c`
   - subId: your VRF subscription id
   - requestConfirmations: `3`
   - callbackGasLimit: `500000`
   - nativePayment: `true`
   - houseEdgeBps_: `200`
   - initialOwner: your wallet address
3) Add contract as VRF consumer
4) Call `setTokenConfig` and `fundETH`

