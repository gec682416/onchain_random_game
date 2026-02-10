// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 引入必要的结构体定义
import {VRFV2PlusClient} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title LocalVRFCoordinatorMock
 * @notice 这是一个完全独立的本地 Mock，不再继承官方代码。
 * 它只包含我们需要的 4 个功能：创建订阅、充值、添加消费者、请求随机数（带自动回调）。
 */
contract LocalVRFCoordinatorMock {
    uint256 private s_currentSubId;
    uint256 private s_currentReqId;

    event SubscriptionCreated(uint256 indexed subId, address owner);
    event SubscriptionFunded(uint256 indexed subId, uint256 oldBalance, uint256 newBalance);
    event ConsumerAdded(uint256 indexed subId, address consumer);
    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bytes extraArgs,
        address sender
    );
    event RandomWordsFulfilled(uint256 indexed requestId, uint256 outputSeed, uint96 payment, bool success);

    // 构造函数：参数是为了兼容脚本里的 new 调用，实际上我们不需要这些参数
    constructor(uint96 _baseFee, uint96 _gasPriceLink, int256 _minReqConf) {}

    // 1. 创建订阅
    function createSubscription() external returns (uint256) {
        s_currentSubId++;
        emit SubscriptionCreated(s_currentSubId, msg.sender);
        return s_currentSubId;
    }

    // 2. 充值订阅 (Native ETH)
    function fundSubscriptionWithNative(uint256 subId) external payable {
        emit SubscriptionFunded(subId, 0, msg.value);
    }

    // 3. 添加消费者
    function addConsumer(uint256 subId, address consumer) external {
        emit ConsumerAdded(subId, consumer);
    }

    // 4. 请求随机数 (核心逻辑：收到请求 -> 立即自动回调)
    function requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest calldata req
    ) external returns (uint256 requestId) {
        s_currentReqId++;
        requestId = s_currentReqId;

        emit RandomWordsRequested(
            req.keyHash,
            requestId,
            100, // preSeed
            req.subId,
            req.requestConfirmations,
            req.callbackGasLimit,
            req.numWords,
            req.extraArgs,
            msg.sender
        );

        // fulfillRandomWordsWithOverride(requestId, msg.sender, req.numWords);
        
        return requestId;
    }

    // 内部帮助函数：模拟 Chainlink 节点生成随机数并推回给消费者
    function fulfillRandomWordsWithOverride(uint256 requestId, address consumer, uint32 numWords) public {
        uint256[] memory randomWords = new uint256[](numWords);
        
        // 生成伪随机数 (基于时间戳，本地测试够用了)
        for (uint256 i = 0; i < numWords; i++) {
            randomWords[i] = uint256(keccak256(abi.encode(requestId, i, block.timestamp)));
        }

        // 调用你的 Game 合约的回调入口
        VRFConsumerBaseV2Plus(consumer).rawFulfillRandomWords(requestId, randomWords);
        
        emit RandomWordsFulfilled(requestId, randomWords[0], 0, true);
    }
}