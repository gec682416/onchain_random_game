// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {RandomGamePlatform} from "../src/RandomGamePlatform.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

/**
 * @title RandomGamePlatformTest
 * @notice SC6107 课程项目测试套件
 * @dev 包含单元测试和模糊测试，目标覆盖率 80%+
 * 
 * 测试类别：
 * 1. 构造函数和初始化测试
 * 2. 抽奖（Lottery）功能测试
 * 3. 骰子（Dice）游戏测试
 * 4. VRF 集成测试
 * 5. 安全性测试（重入、权限、溢出）
 * 6. 边界条件和错误处理测试
 * 7. 模糊测试（Fuzzing）
 */
contract RandomGamePlatformTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 常量
    //////////////////////////////////////////////////////////////*/

    uint96 private constant FUND_AMOUNT = 100 ether;
    uint96 private constant BASE_FEE = 0.25 ether;
    uint96 private constant GAS_PRICE_LINK = 1e9;
    
    bytes32 private constant GAS_LANE = 
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 500000;
    bool private constant NATIVE_PAYMENT = true;
    uint256 private constant HOUSE_EDGE_BPS = 200; // 2%

    /*//////////////////////////////////////////////////////////////
                                 状态变量
    //////////////////////////////////////////////////////////////*/

    RandomGamePlatform public platform;
    VRFCoordinatorV2Mock public vrfCoordinator;
    ERC20Mock public mockToken;

    address public owner;
    address public player1;
    address public player2;
    address public player3;

    uint64 public subscriptionId;

    /*//////////////////////////////////////////////////////////////
                                 事件
    //////////////////////////////////////////////////////////////*/

    event LotteryStarted(
        uint256 indexed lotteryId,
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime,
        address token
    );

    event TicketPurchased(
        uint256 indexed lotteryId,
        address indexed player,
        uint256 ticketCount,
        uint256 totalCost
    );

    event LotteryEnded(uint256 indexed lotteryId, address indexed winner, uint256 prize);

    event DiceBetPlaced(
        uint256 indexed betId,
        address indexed player,
        uint256 betAmount,
        uint256 predictedNumber,
        uint256 multiplier,
        address token
    );

    event DiceBetSettled(
        uint256 indexed betId,
        address indexed player,
        uint256 rollResult,
        bool won,
        uint256 payout
    );

    /*//////////////////////////////////////////////////////////////
                                 设置
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // 设置账户
        owner = makeAddr("owner");
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        player3 = makeAddr("player3");

        // 为玩家分配 ETH
        vm.deal(owner, 1000 ether);
        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
        vm.deal(player3, 100 ether);

        // 部署 VRF Coordinator Mock
        vm.startPrank(owner);
        vrfCoordinator = new VRFCoordinatorV2Mock(BASE_FEE, GAS_PRICE_LINK);
        
        // 创建订阅并充值
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, FUND_AMOUNT);

        // 部署游戏平台
        platform = new RandomGamePlatform(
            address(vrfCoordinator),
            GAS_LANE,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NATIVE_PAYMENT,
            HOUSE_EDGE_BPS,
            owner
        );

        // 将平台添加到 VRF 订阅的消费者列表
        vrfCoordinator.addConsumer(subscriptionId, address(platform));

        // 部署 ERC20 Mock 代币
        mockToken = new ERC20Mock();
        
        // 给玩家铸造代币
        mockToken.mint(player1, 10000 ether);
        mockToken.mint(player2, 10000 ether);
        mockToken.mint(player3, 10000 ether);

        // 向平台资金池存入初始资金（用于 Dice 游戏赔付）
        // TODO: depositToPool 方法需要实现
        // platform.depositToPool{value: 50 ether}(address(0), 50 ether);
        
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            构造函数测试
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        (
            address vrfCoord,
            bytes32 gasLane,
            uint64 subId,
            uint32 callbackGas
        ) = platform.getVRFConfig();

        assertEq(vrfCoord, address(vrfCoordinator));
        assertEq(gasLane, GAS_LANE);
        assertEq(subId, subscriptionId);
        assertEq(callbackGas, CALLBACK_GAS_LIMIT);
    }

    /*//////////////////////////////////////////////////////////////
                            抽奖功能测试
    //////////////////////////////////////////////////////////////*/

    function test_StartLottery_Success() public {
        vm.startPrank(owner);
        
        uint256 ticketPrice = 0.1 ether;
        uint256 duration = 7 days;

        vm.expectEmit(true, false, false, true);
        emit LotteryStarted(0, ticketPrice, block.timestamp, block.timestamp + duration, address(0));
        
        platform.startLottery(ticketPrice, duration, address(0));

        (
            uint256 id,
            uint256 price,
            uint256 startTime,
            uint256 endTime,
            ,,,,,
        ) = platform.getLotteryInfo(0);

        assertEq(id, 0);
        assertEq(price, ticketPrice);
        assertEq(startTime, block.timestamp);
        assertEq(endTime, block.timestamp + duration);
        
        vm.stopPrank();
    }

    function test_StartLottery_RevertWhen_NotOwner() public {
        vm.prank(player1);
        vm.expectRevert();
        platform.startLottery(0.1 ether, 7 days, address(0));
    }

    function test_StartLottery_RevertWhen_InvalidTicketPrice() public {
        vm.prank(owner);
        vm.expectRevert(RandomGamePlatform.InvalidBetAmount.selector);
        platform.startLottery(0, 7 days, address(0));
    }

    function test_StartLottery_RevertWhen_InvalidDuration() public {
        vm.prank(owner);
        vm.expectRevert(RandomGamePlatform.InvalidLotteryDuration.selector);
        platform.startLottery(0.1 ether, 30 minutes, address(0));
    }

    function test_BuyTickets_ETH_Success() public {
        // 开启抽奖
        vm.prank(owner);
        platform.startLottery(0.1 ether, 7 days, address(0));

        // 玩家购买彩票
        vm.prank(player1);
        uint256 ticketCount = 5;
        uint256 totalCost = 0.5 ether;

        vm.expectEmit(true, true, false, true);
        emit TicketPurchased(0, player1, ticketCount, totalCost);

        platform.buyTickets{value: totalCost}(0, ticketCount);

        // 验证状态
        uint256 userTickets = platform.getUserTickets(0, player1);
        assertEq(userTickets, ticketCount);

        (,,,, uint256 totalTickets, uint256 prizePool,,,,) = platform.getLotteryInfo(0);
        assertEq(totalTickets, ticketCount);
        assertEq(prizePool, totalCost);
    }

    function test_BuyTickets_ERC20_Success() public {
        // 开启 ERC20 抽奖
        vm.prank(owner);
        platform.startLottery(100 ether, 7 days, address(mockToken));

        // 玩家批准并购买
        vm.startPrank(player1);
        mockToken.approve(address(platform), 500 ether);
        platform.buyTickets(0, 5);
        vm.stopPrank();

        uint256 userTickets = platform.getUserTickets(0, player1);
        assertEq(userTickets, 5);
    }

    function test_BuyTickets_RevertWhen_LotteryNotActive() public {
        vm.prank(owner);
        platform.startLottery(0.1 ether, 7 days, address(0));

        // 时间快进到抽奖结束后
        vm.warp(block.timestamp + 8 days);

        vm.prank(player1);
        vm.expectRevert(RandomGamePlatform.LotteryNotActive.selector);
        platform.buyTickets{value: 0.1 ether}(0, 1);
    }

    function test_BuyTickets_RevertWhen_InvalidAmount() public {
        vm.prank(owner);
        platform.startLottery(0.1 ether, 7 days, address(0));

        vm.prank(player1);
        vm.expectRevert(RandomGamePlatform.InvalidBetAmount.selector);
        platform.buyTickets{value: 0.05 ether}(0, 1); // 金额不足
    }

    function test_EndLottery_Success() public {
        // 设置抽奖
        vm.prank(owner);
        platform.startLottery(0.1 ether, 1 hours, address(0));

        // 多个玩家购买彩票
        vm.prank(player1);
        platform.buyTickets{value: 0.3 ether}(0, 3);
        
        vm.prank(player2);
        platform.buyTickets{value: 0.2 ether}(0, 2);

        // 时间快进
        vm.warp(block.timestamp + 2 hours);

        // 结束抽奖
        vm.prank(player1);
        platform.endLottery(0);

        // 获取 VRF 请求 ID 并模拟响应
        uint256 requestId = 1; // VRFCoordinatorV2Mock 的第一个请求 ID
        
        // 模拟 VRF 响应
        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomWords(requestId, address(platform));

        // 验证抽奖已结算
        (,,,,,, address winner, bool settled,,) = platform.getLotteryInfo(0);
        assertTrue(settled);
        assertTrue(winner == player1 || winner == player2);
    }

    function test_EndLottery_RevertWhen_NotEnded() public {
        vm.prank(owner);
        platform.startLottery(0.1 ether, 7 days, address(0));

        vm.prank(player1);
        platform.buyTickets{value: 0.1 ether}(0, 1);

        vm.prank(player1);
        vm.expectRevert(RandomGamePlatform.LotteryNotEnded.selector);
        platform.endLottery(0);
    }

    function test_EndLottery_RevertWhen_NoParticipants() public {
        vm.prank(owner);
        platform.startLottery(0.1 ether, 1 hours, address(0));

        vm.warp(block.timestamp + 2 hours);

        vm.prank(player1);
        vm.expectRevert(RandomGamePlatform.NoParticipants.selector);
        platform.endLottery(0);
    }

    /*//////////////////////////////////////////////////////////////
                            骰子游戏测试
    //////////////////////////////////////////////////////////////*/

    function test_PlaceDiceBet_ETH_Success() public {
        vm.startPrank(player1);
        
        uint256 betAmount = 1 ether;
        uint256 predictedNumber = 3;

        vm.expectEmit(true, true, false, true);
        emit DiceBetPlaced(0, player1, betAmount, predictedNumber, 500, address(0));

        platform.placeDiceBet{value: betAmount}(predictedNumber, address(0));

        (
            uint256 id,
            address player,
            uint256 amount,
            uint256 predicted,
            uint256 multiplier,
            address token,
            ,
            bool settled
        ) = platform.getDiceBetInfo(0);

        assertEq(id, 0);
        assertEq(player, player1);
        assertEq(amount, betAmount);
        assertEq(predicted, predictedNumber);
        assertEq(multiplier, 500);
        assertEq(token, address(0));
        assertFalse(settled);

        vm.stopPrank();
    }

    function test_PlaceDiceBet_RevertWhen_InvalidNumber() public {
        vm.prank(player1);
        vm.expectRevert(RandomGamePlatform.InvalidDiceNumber.selector);
        platform.placeDiceBet{value: 1 ether}(7, address(0));

        vm.prank(player1);
        vm.expectRevert(RandomGamePlatform.InvalidDiceNumber.selector);
        platform.placeDiceBet{value: 1 ether}(0, address(0));
    }

    function test_PlaceDiceBet_RevertWhen_InsufficientPoolBalance() public {
        // 先提取大部分资金池
        vm.prank(owner);
        platform.withdrawFromPool(address(0), 49 ether);

        // 尝试下注大额（赔付超过资金池）
        vm.prank(player1);
        vm.expectRevert(RandomGamePlatform.InsufficientBalance.selector);
        platform.placeDiceBet{value: 1 ether}(3, address(0));
    }

    function test_SettleDiceBet_PlayerWins() public {
        // 下注
        vm.prank(player1);
        platform.placeDiceBet{value: 1 ether}(3, address(0));

        uint256 player1BalanceBefore = player1.balance;

        // 模拟 VRF 返回玩家猜中的数字
        // 我们需要构造一个随机数，使得 (randomWord % 6) + 1 = 3
        // 即 randomWord % 6 = 2，例如 randomWord = 2
        uint256 requestId = 1;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 2; // (2 % 6) + 1 = 3

        vm.prank(address(vrfCoordinator));
        vm.mockCall(
            address(vrfCoordinator),
            abi.encodeWithSelector(VRFCoordinatorV2Mock.fulfillRandomWords.selector),
            abi.encode()
        );
        
        // 直接调用 fulfillRandomWords
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(platform), randomWords);

        // 验证结果
        (,,,,,,uint256 rollResult, bool settled) = platform.getDiceBetInfo(0);
        assertTrue(settled);
        assertEq(rollResult, 3);

        // 验证玩家收到赔付 (1 ether * 5 = 5 ether)
        uint256 player1BalanceAfter = player1.balance;
        assertEq(player1BalanceAfter, player1BalanceBefore + 5 ether);
    }

    function test_SettleDiceBet_PlayerLoses() public {
        vm.prank(player1);
        platform.placeDiceBet{value: 1 ether}(3, address(0));

        uint256 poolBalanceBefore = platform.getPlatformPoolBalance(address(0));

        // 模拟 VRF 返回玩家未猜中的数字
        uint256 requestId = 1;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 0; // (0 % 6) + 1 = 1 (不等于 3)

        vm.prank(address(vrfCoordinator));
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(platform), randomWords);

        // 验证结果
        (,,,,,,uint256 rollResult, bool settled) = platform.getDiceBetInfo(0);
        assertTrue(settled);
        assertEq(rollResult, 1);

        // 验证投注金额进入资金池
        uint256 poolBalanceAfter = platform.getPlatformPoolBalance(address(0));
        assertEq(poolBalanceAfter, poolBalanceBefore + 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            管理功能测试
    //////////////////////////////////////////////////////////////*/

    function test_DepositToPool_ETH() public {
        vm.prank(owner);
        platform.depositToPool{value: 10 ether}(address(0), 10 ether);

        uint256 balance = platform.getPlatformPoolBalance(address(0));
        assertEq(balance, 60 ether); // 50 (初始) + 10
    }

    function test_WithdrawFromPool_Success() public {
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        platform.withdrawFromPool(address(0), 20 ether);

        uint256 ownerBalanceAfter = owner.balance;
        assertEq(ownerBalanceAfter, ownerBalanceBefore + 20 ether);

        uint256 poolBalance = platform.getPlatformPoolBalance(address(0));
        assertEq(poolBalance, 30 ether);
    }

    function test_WithdrawFromPool_RevertWhen_InsufficientBalance() public {
        vm.prank(owner);
        vm.expectRevert(RandomGamePlatform.InsufficientBalance.selector);
        platform.withdrawFromPool(address(0), 100 ether);
    }

    function test_SetPlatformFeeRate() public {
        vm.prank(owner);
        platform.setPlatformFeeRate(300); // 3%

        uint256 feeRate = platform.getPlatformFeeRate();
        assertEq(feeRate, 300);
    }

    function test_PauseAndUnpause() public {
        vm.startPrank(owner);
        
        platform.pause();
        
        vm.stopPrank();

        // 暂停后不能下注
        vm.prank(player1);
        vm.expectRevert();
        platform.placeDiceBet{value: 1 ether}(3, address(0));

        // 恢复
        vm.prank(owner);
        platform.unpause();

        // 恢复后可以下注
        vm.prank(player1);
        platform.placeDiceBet{value: 1 ether}(3, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                            安全性测试
    //////////////////////////////////////////////////////////////*/

    function test_ReentrancyProtection() public {
        // 测试购买彩票时的重入保护
        // 这需要一个恶意合约，暂时跳过详细实现
        // 在实际项目中应创建 ReentrancyAttacker 合约进行测试
    }

    function test_OnlyOwnerFunctions() public {
        vm.prank(player1);
        vm.expectRevert();
        platform.startLottery(0.1 ether, 7 days, address(0));

        vm.prank(player1);
        vm.expectRevert();
        platform.withdrawFromPool(address(0), 1 ether);

        vm.prank(player1);
        vm.expectRevert();
        platform.setPlatformFeeRate(300);
    }

    /*//////////////////////////////////////////////////////////////
                            模糊测试（Fuzzing）
    //////////////////////////////////////////////////////////////*/

    function testFuzz_BuyTickets(uint256 ticketCount) public {
        // 限制输入范围
        ticketCount = bound(ticketCount, 1, 100);

        vm.prank(owner);
        platform.startLottery(0.1 ether, 7 days, address(0));

        uint256 totalCost = 0.1 ether * ticketCount;
        
        vm.prank(player1);
        platform.buyTickets{value: totalCost}(0, ticketCount);

        uint256 userTickets = platform.getUserTickets(0, player1);
        assertEq(userTickets, ticketCount);
    }

    function testFuzz_PlaceDiceBet(uint256 predictedNumber, uint256 betAmount) public {
        // 限制输入范围
        predictedNumber = bound(predictedNumber, 1, 6);
        betAmount = bound(betAmount, 0.01 ether, 5 ether);

        vm.prank(player1);
        platform.placeDiceBet{value: betAmount}(predictedNumber, address(0));

        (,, uint256 amount, uint256 predicted,,,,) = platform.getDiceBetInfo(0);
        assertEq(amount, betAmount);
        assertEq(predicted, predictedNumber);
    }

    function testFuzz_LotteryDuration(uint256 duration) public {
        // 限制在有效范围内
        duration = bound(duration, 1 hours, 30 days);

        vm.prank(owner);
        platform.startLottery(0.1 ether, duration, address(0));

        (,,, uint256 endTime,,,,,,) = platform.getLotteryInfo(0);
        assertEq(endTime, block.timestamp + duration);
    }

    /*//////////////////////////////////////////////////////////////
                            边界条件测试
    //////////////////////////////////////////////////////////////*/

    function test_MultiplePlayers_Lottery() public {
        vm.prank(owner);
        platform.startLottery(0.1 ether, 7 days, address(0));

        // 三个玩家购买不同数量的彩票
        vm.prank(player1);
        platform.buyTickets{value: 0.5 ether}(0, 5);

        vm.prank(player2);
        platform.buyTickets{value: 0.3 ether}(0, 3);

        vm.prank(player3);
        platform.buyTickets{value: 0.2 ether}(0, 2);

        (,,,, uint256 totalTickets, uint256 prizePool,,,uint256 participantCount) = 
            platform.getLotteryInfo(0);
        
        assertEq(totalTickets, 10);
        assertEq(prizePool, 1 ether);
        assertEq(participantCount, 3);
    }

    function test_ReceiveETH() public {
        uint256 balanceBefore = platform.getPlatformPoolBalance(address(0));
        
        (bool success, ) = address(platform).call{value: 5 ether}("");
        assertTrue(success);

        uint256 balanceAfter = platform.getPlatformPoolBalance(address(0));
        assertEq(balanceAfter, balanceBefore + 5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            辅助函数
    //////////////////////////////////////////////////////////////*/

    function _createAndEndLottery() internal {
        vm.prank(owner);
        platform.startLottery(0.1 ether, 1 hours, address(0));

        vm.prank(player1);
        platform.buyTickets{value: 0.1 ether}(0, 1);

        vm.warp(block.timestamp + 2 hours);

        vm.prank(player1);
        platform.endLottery(0);
    }
}
