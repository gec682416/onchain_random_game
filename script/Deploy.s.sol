// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {RandomGamePlatform} from "../src/RandomGamePlatform.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 subscriptionId = vm.envUint("SUBSCRIPTION_ID");

        // VRF Coordinator v2.5 
        address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
        // 30 gwei Key Hash
        bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
        uint256 s_subscriptionId;

        uint16 requestConfirmations = 3;
        uint32 callbackGasLimit = 500000;
        bool nativePayment = true;
        uint256 houseEdgeBps = 200;

        vm.startBroadcast(deployerPrivateKey);

        RandomGamePlatform platform = new RandomGamePlatform(
            vrfCoordinator,
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            nativePayment,
            houseEdgeBps,
            vm.addr(deployerPrivateKey) // Owner
        );

        console2.log("RandomGamePlatform deployed to:", address(platform));

        vm.stopBroadcast();
    }
}