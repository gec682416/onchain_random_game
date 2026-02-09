// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {RandomGamePlatform} from "../src/RandomGamePlatform.sol";

/**
 * @title DeployScript
 * @notice 部署 RandomGamePlatform 合约的脚本
 * @dev 使用方法：
 *      forge script script/Deploy.s.sol:DeployScript --rpc-url <RPC_URL> --broadcast --verify
 */
contract DeployScript is Script {
    // Sepolia 测试网 VRF 配置
    address constant SEPOLIA_VRF_COORDINATOR = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    bytes32 constant SEPOLIA_GAS_LANE = 
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 constant CALLBACK_GAS_LIMIT = 500000;

    function run() external {
        // 从环境变量读取配置
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint64 subscriptionId = uint64(vm.envUint("SUBSCRIPTION_ID"));

        console2.log("Deploying RandomGamePlatform...");
        console2.log("Deployer:", vm.addr(deployerPrivateKey));
        console2.log("VRF Coordinator:", SEPOLIA_VRF_COORDINATOR);
        console2.log("Subscription ID:", subscriptionId);

        vm.startBroadcast(deployerPrivateKey);

        // 部署合约
        RandomGamePlatform platform = new RandomGamePlatform(
            SEPOLIA_VRF_COORDINATOR,
            SEPOLIA_GAS_LANE,
            subscriptionId,
            CALLBACK_GAS_LIMIT
        );

        console2.log("RandomGamePlatform deployed at:", address(platform));

        // 向平台资金池存入初始资金（可选）
        // platform.depositToPool{value: 10 ether}(address(0), 10 ether);
        // console2.log("Deposited 10 ETH to platform pool");

        vm.stopBroadcast();

        console2.log("\n=== Deployment Summary ===");
        console2.log("Contract Address:", address(platform));
        console2.log("Owner:", platform.owner());
        console2.log("VRF Subscription ID:", subscriptionId);
        console2.log("\nNext steps:");
        console2.log("1. Add this contract as a consumer in your VRF subscription");
        console2.log("2. Deposit funds to the platform pool using depositToPool()");
        console2.log("3. Verify contract on Etherscan (if --verify flag was used)");
    }
}

/**
 * @title DeployAndSetupScript
 * @notice 部署并完成初始设置
 */
contract DeployAndSetupScript is Script {
    address constant SEPOLIA_VRF_COORDINATOR = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    bytes32 constant SEPOLIA_GAS_LANE = 
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 constant CALLBACK_GAS_LIMIT = 500000;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint64 subscriptionId = uint64(vm.envUint("SUBSCRIPTION_ID"));

        vm.startBroadcast(deployerPrivateKey);

        // 部署
        RandomGamePlatform platform = new RandomGamePlatform(
            SEPOLIA_VRF_COORDINATOR,
            SEPOLIA_GAS_LANE,
            subscriptionId,
            CALLBACK_GAS_LIMIT
        );

        console2.log("Contract deployed at:", address(platform));

        // 初始设置
        platform.depositToPool{value: 10 ether}(address(0), 10 ether);
        console2.log("Deposited 10 ETH to platform pool");

        // 创建第一个抽奖（示例）
        platform.startLottery(0.1 ether, 7 days, address(0));
        console2.log("Started first lottery with 0.1 ETH ticket price");

        vm.stopBroadcast();

        console2.log("\n=== Setup Complete ===");
        console2.log("Contract:", address(platform));
        console2.log("Platform Pool (ETH):", platform.getPlatformPoolBalance(address(0)));
        console2.log("Current Lottery ID:", platform.getCurrentLotteryId());
    }
}
