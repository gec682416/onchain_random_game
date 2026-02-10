// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "lib/forge-std/src/Script.sol";

import {RandomGamePlatform} from "../src/RandomGamePlatform.sol";

// Chainlink VRF v2.5 mock (brownie contracts)
// import {VRFCoordinatorV2_5Mock} from
//     "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LocalVRFCoordinatorMock as VRFCoordinatorV2_5Mock} from "../src/LocalVRFCoordinatorMock.sol";

contract DeployLocal is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        // ---------- configurable knobs ----------
        // VRF mock fee params (not super important for local)
        uint96 BASE_FEE = 0.25 ether;
        uint96 GAS_PRICE_LINK = 1e9;
        int256 MIN_REQ_CONF = 3;
        // Platform params
        bytes32 KEY_HASH = bytes32("local-gas-lane"); // mock accepts arbitrary keyHash
        uint16 REQ_CONF = 3;
        uint32 CALLBACK_GAS_LIMIT = 100_000; // IMPORTANT: must be large enough for callback logic
        bool NATIVE_PAYMENT = true;          // local: pay in native (ETH) in extraArgs

        uint256 HOUSE_EDGE_BPS = 200;        // 2%
        // Token config for ETH bets
        uint256 MIN_BET = 0.01 ether;
        uint256 MAX_BET = 10 ether;
        // Liquidity seeded into platform for payouts
        uint256 SEED_LIQUIDITY = 10 ether;

        // Subscription funding (mock tracks this balance; for local you can set any number)
        uint96 SUB_FUND = 10 ether;
        // ---------------------------------------

        vm.startBroadcast(pk);

        // 1) Deploy VRF v2.5 mock coordinator
        VRFCoordinatorV2_5Mock vrf = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, MIN_REQ_CONF);

        // 2) Create & fund subscription
        uint256 subId = vrf.createSubscription();
        // vrf.fundSubscription(subId, SUB_FUND);
        vrf.fundSubscriptionWithNative{value: SUB_FUND}(subId);

        // 3) Deploy your platform (owner = deployer)
        RandomGamePlatform platform = new RandomGamePlatform(
            address(vrf),
            KEY_HASH,
            subId,
            REQ_CONF,
            CALLBACK_GAS_LIMIT,
            NATIVE_PAYMENT,
            HOUSE_EDGE_BPS,
            vm.addr(pk)
        );

        // 4) Add platform as a consumer
        vrf.addConsumer(subId, address(platform));

        // 5) Enable ETH betting
        platform.setTokenConfig(address(0), true, MIN_BET, MAX_BET);

        // 6) Seed ETH liquidity for payouts
        platform.fundETH{value: SEED_LIQUIDITY}();

        vm.stopBroadcast();

        // ---------- prints ----------
        console2.log("Deployer:", vm.addr(pk));
        console2.log("VRFCoordinatorV2_5Mock:", address(vrf));
        console2.log("Subscription ID (uint256):", subId);
        console2.log("RandomGamePlatform:", address(platform));
        console2.log("Seeded liquidity (ETH):", SEED_LIQUIDITY);

        console2.log("ETH tokenConfig enabled/min/max:");
        (bool enabled, uint256 minBet, uint256 maxBet) = platform.tokenConfigs(address(0));
        console2.log("  enabled:", enabled);
        console2.log("  minBet :", minBet);
        console2.log("  maxBet :", maxBet);
    }
}