// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {RandomGamePlatform} from "../src/RandomGamePlatform.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract RandomGamePlatformTest is Test {
    uint96 private constant FUND_AMOUNT = 20 ether;
    uint96 private constant BASE_FEE = 0.002 ether;
    uint96 private constant GAS_PRICE_LINK = 40 gwei;
    int256 private constant WEI_PER_UNIT_LINK = 0.004 ether;

    bytes32 private constant GAS_LANE =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant CALLBACK_GAS_LIMIT = 500000;
    bool private constant NATIVE_PAYMENT = true;
    uint256 private constant HOUSE_EDGE_BPS = 200; // 2%

    RandomGamePlatform public platform;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    ERC20Mock public mockToken;

    address public owner;
    address public player1;
    address public player2;

    uint256 public subscriptionId;

    function setUp() public {
        owner = makeAddr("owner");
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");

        vm.deal(owner, 1000 ether);
        vm.deal(player1, 50 ether);
        vm.deal(player2, 50 ether);

        vm.startPrank(owner);
        vrfCoordinator = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK);
        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscriptionWithNative{value: FUND_AMOUNT}(subscriptionId);

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
        vrfCoordinator.addConsumer(subscriptionId, address(platform));

        mockToken = new ERC20Mock();
        mockToken.mint(player1, 10_000 ether);
        mockToken.mint(player2, 10_000 ether);

        platform.setTokenConfig(address(0), true, 0.01 ether, 5 ether);
        platform.setTokenConfig(address(mockToken), true, 1 ether, 10_000 ether);

        platform.fundETH{value: 200 ether}();
        mockToken.mint(owner, 10_000 ether);
        mockToken.approve(address(platform), 5_000 ether);
        platform.fundToken(address(mockToken), 5_000 ether);

        vm.stopPrank();
    }

    function test_Constructor_Config() public view {
        (address vrfCoord, bytes32 gasLane, uint64 subId, uint32 callbackGas) = platform.getVRFConfig();
        assertEq(vrfCoord, address(vrfCoordinator));
        assertEq(gasLane, GAS_LANE);
        assertEq(subId, uint64(subscriptionId));
        assertEq(callbackGas, CALLBACK_GAS_LIMIT);
        assertEq(platform.houseEdgeBps(), HOUSE_EDGE_BPS);
    }

    function test_CreateLottery_Success() public {
        uint256 startTime = block.timestamp + 1;
        uint256 endTime = startTime + 1 days;

        vm.prank(owner);
        platform.createLottery(address(0), 0.1 ether, startTime, endTime);

        (
            uint256 storedStart,
            uint256 storedEnd,
            address token,
            uint256 ticketPrice,
            uint256 pot,
            address winner,
            bool drawRequested,
            bool drawn,
            uint256 requestId
        ) = platform.lotteries(0);

        assertEq(storedStart, startTime);
        assertEq(storedEnd, endTime);
        assertEq(token, address(0));
        assertEq(ticketPrice, 0.1 ether);
        assertEq(pot, 0);
        assertEq(winner, address(0));
        assertFalse(drawRequested);
        assertFalse(drawn);
        assertEq(requestId, 0);
    }

    function test_CreateLottery_RevertWhen_TokenDisabled() public {
        vm.prank(owner);
        vm.expectRevert(bytes("token disabled"));
        platform.createLottery(address(0x1234), 1 ether, block.timestamp, block.timestamp + 1 days);
    }

    function test_BuyTickets_ETH_Success() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;

        vm.prank(owner);
        platform.createLottery(address(0), 0.1 ether, startTime, endTime);

        vm.prank(player1);
        platform.buyTickets{value: 0.3 ether}(0, 3);

        assertEq(platform.getLotteryEntryCount(0), 3);
        assertEq(platform.getLotteryEntry(0, 0), player1);

        (, , , , uint256 pot, , , , ) = platform.lotteries(0);
        assertEq(pot, 0.3 ether);
    }

    function test_BuyTickets_ERC20_Success() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;

        vm.prank(owner);
        platform.createLottery(address(mockToken), 100 ether, startTime, endTime);

        vm.startPrank(player1);
        mockToken.approve(address(platform), 500 ether);
        platform.buyTickets(0, 5);
        vm.stopPrank();

        assertEq(platform.getLotteryEntryCount(0), 5);
        (, , , , uint256 pot, , , , ) = platform.lotteries(0);
        assertEq(pot, 500 ether);
    }

    function test_RequestLotteryDraw_AndFulfill() public {
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 1 days;

        vm.prank(owner);
        platform.createLottery(address(0), 0.1 ether, startTime, endTime);

        vm.prank(player1);
        platform.buyTickets{value: 0.2 ether}(0, 2);

        vm.warp(endTime + 1);

        vm.prank(owner);
        platform.requestLotteryDraw(0);

        (, , , , , , bool drawRequested, bool drawn, uint256 requestId) = platform.lotteries(0);
        assertTrue(drawRequested);
        assertFalse(drawn);
        assertGt(requestId, 0);

        vrfCoordinator.fulfillRandomWords(requestId, address(platform));

        (, , , , uint256 pot, address winner, , bool resolved, ) = platform.lotteries(0);
        assertTrue(resolved);
        assertEq(pot, 0.2 ether);
        assertTrue(winner == player1);
    }

    function test_PlayDice_ETH_Win() public {
        vm.startPrank(player1);
        uint256 stake = 1 ether;
        uint8 rollUnder = 50;

        uint256 expectedPayout = platform.calcDicePayout(stake, rollUnder);
        platform.playDice{value: stake}(address(0), stake, rollUnder);
        vm.stopPrank();

        (, , , , , , , , uint256 requestId) = platform.diceBets(0);
        uint256 balanceBefore = player1.balance;

        uint256[] memory words = new uint256[](1);
        words[0] = 1; // roll = 1, win when rollUnder = 50
        vrfCoordinator.fulfillRandomWordsWithOverride(requestId, address(platform), words);

        (, , , , , bool resolved, bool win, uint8 roll, ) = platform.diceBets(0);
        assertTrue(resolved);
        assertTrue(win);
        assertEq(roll, 1);
        assertEq(player1.balance, balanceBefore + expectedPayout);
    }

    function test_PlayDice_RevertWhen_BetOutOfBounds() public {
        vm.prank(player1);
        vm.expectRevert(bytes("bet bounds"));
        platform.playDice{value: 0.001 ether}(address(0), 0.001 ether, 50);
    }

    function test_FundAndWithdraw_ETH() public {
        uint256 balanceBefore = owner.balance;

        vm.prank(owner);
        platform.withdraw(address(0), 1 ether, owner);

        assertEq(owner.balance, balanceBefore + 1 ether);
    }

    function testFuzz_PlayDice(uint256 stake, uint8 rollUnder) public {
        stake = bound(stake, 0.01 ether, 1 ether);
        rollUnder = uint8(bound(rollUnder, 2, 99));

        vm.prank(player1);
        platform.playDice{value: stake}(address(0), stake, rollUnder);

        (, , uint256 storedStake, uint8 storedRollUnder, , , , , ) = platform.diceBets(0);
        assertEq(storedStake, stake);
        assertEq(storedRollUnder, rollUnder);
    }
}
