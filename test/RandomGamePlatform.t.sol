// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "lib/forge-std/src/Test.sol";

import {RandomGamePlatform} from "../src/RandomGamePlatform.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RandomGamePlatformTest is Test {
    /*//////////////////////////////////////////////////////////////
                                常量
    //////////////////////////////////////////////////////////////*/

    uint96 constant BASE_FEE = 0.25 ether;
    uint96 constant GAS_PRICE_LINK = 1e9;
    int256 constant WEI_PER_UNIT_LINK = 1e18;
    bytes32 constant KEY_HASH =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    uint16 constant REQUEST_CONFIRMATIONS = 3;
    uint32 constant CALLBACK_GAS_LIMIT = 500_000;
    bool constant NATIVE_PAYMENT = false;
    uint256 constant HOUSE_EDGE_BPS = 200; // 2%

    /*//////////////////////////////////////////////////////////////
                              状态变量
    //////////////////////////////////////////////////////////////*/

    RandomGamePlatform platform;

    VRFCoordinatorV2_5Mock vrf;

    address owner;
    address player1;
    address player2;
    uint64 subId64;
    uint256 subId;

    /*//////////////////////////////////////////////////////////////
                                  setup
    //////////////////////////////////////////////////////////////*/

    // function setUp() public {
    //     owner = makeAddr("owner");
    //     player1 = makeAddr("player1");
    //     player2 = makeAddr("player2");

    //     vm.deal(owner, 100 ether);
    //     vm.deal(player1, 100 ether);
    //     vm.deal(player2, 100 ether);

    //     // deploy VRF mock
    //     vm.startPrank(owner);
    //     vrf = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, WEI_PER_UNIT_LINK);

    //     subId = vrf.createSubscription();
    //     vrf.fundSubscription(subId, 10 ether);

    //     // deploy platform
    //     platform = new RandomGamePlatform(
    //         address(vrf),
    //         KEY_HASH,
    //         subId,
    //         REQUEST_CONFIRMATIONS,
    //         CALLBACK_GAS_LIMIT,
    //         NATIVE_PAYMENT,
    //         HOUSE_EDGE_BPS,
    //         owner
    //     );

    //     vrf.addConsumer(subId, address(platform));

    //     // enable ETH wagering
    //     platform.setTokenConfig(address(0), true, 0.01 ether, 10 ether);

    //     // fund platform for dice payouts
    //     platform.fundETH{value: 20 ether}();

    //     vm.stopPrank();
    // }

    function setUp() public {
        owner = makeAddr("owner");
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");

        vm.deal(owner, 100 ether);
        vm.deal(player1, 100 ether);
        vm.deal(player2, 100 ether);
        vm.startPrank(owner);

        vrf = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE_LINK, 1e18);

        subId = vrf.createSubscription();
        vrf.fundSubscription(subId, 10 ether);

        platform = new RandomGamePlatform(
            address(vrf),
            KEY_HASH,
            subId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NATIVE_PAYMENT,
            HOUSE_EDGE_BPS,
            owner
        );

        vrf.addConsumer(subId, address(platform));
        platform.setTokenConfig(address(0), true, 0.01 ether, 10 ether);
        platform.fundETH{value: 100 ether}();
        vm.stopPrank();

    }
    /*//////////////////////////////////////////////////////////////
                        构造 & 配置测试
    //////////////////////////////////////////////////////////////*/

    function test_VRFConfig() public {
        (
            address coordinator,
            bytes32 keyHash,
            uint256 sid,
            uint16 confs,
            uint32 gasLimit,
            uint32 numWords,
            bool nativePay
        ) = platform.getVRFConfig();

        assertEq(coordinator, address(vrf));
        assertEq(keyHash, KEY_HASH);
        assertEq(sid, subId);
        assertEq(confs, REQUEST_CONFIRMATIONS);
        assertEq(gasLimit, CALLBACK_GAS_LIMIT);
        assertEq(numWords, 1);
        assertEq(nativePay, NATIVE_PAYMENT);
    }

    /*//////////////////////////////////////////////////////////////
                            Lottery 测试
    //////////////////////////////////////////////////////////////*/

    function test_Lottery_HappyPath_ETH() public {
        // create lottery
        vm.prank(owner);
        platform.createLottery(
            address(0),
            0.1 ether,
            block.timestamp,
            block.timestamp + 1 days
        );

        // buy tickets
        vm.prank(player1);
        platform.buyTickets{value: 0.3 ether}(0, 3);

        vm.prank(player2);
        platform.buyTickets{value: 0.2 ether}(0, 2);

        // move time forward
        vm.warp(block.timestamp + 2 days);

        // request draw
        vm.prank(owner);
        platform.requestLotteryDraw(0);

        // fulfill VRF
        uint256 requestId = 1;
        vrf.fulfillRandomWords(requestId, address(platform));

        (
            ,
            ,
            ,
            ,
            uint256 pot,
            address winner,
            ,
            bool drawn,
            uint256 entries
        ) = platform.getLotteryInfo(0);

        assertTrue(drawn);
        assertEq(pot, 0.5 ether);
        assertEq(entries, 5);
        assertTrue(winner == player1 || winner == player2);
    }

    /*//////////////////////////////////////////////////////////////
                            Dice 测试
    //////////////////////////////////////////////////////////////*/

    function test_Dice_WinPath_ETH() public {
        // player places bet
        vm.prank(player1);
        platform.playDice{value: 1 ether}(address(0), 1 ether, 50);

        uint256 balBefore = player1.balance;

        // VRF fulfill with roll < rollUnder
        uint256 requestId = 1;
        uint256[] memory words = new uint256[](1);
        words[0] = 10; // 10 % 100 = 10 < 50 → win

        vrf.fulfillRandomWordsWithOverride(requestId, address(platform), words);

        (, , , , uint256 payout, bool resolved, bool win, , ) = platform
            .getDiceInfo(0);

        assertTrue(resolved);
        assertTrue(win);
        assertEq(player1.balance, balBefore + payout);
    }

    function test_Dice_LosePath_ETH() public {
        vm.prank(player1);
        platform.playDice{value: 1 ether}(address(0), 1 ether, 10);

        uint256 balBefore = player1.balance;

        // roll >= rollUnder → lose
        uint256 requestId = 1;
        uint256[] memory words = new uint256[](1);
        words[0] = 99;

        vrf.fulfillRandomWordsWithOverride(requestId, address(platform), words);

        (, , , , , bool resolved, bool win, , ) = platform.getDiceInfo(0);

        assertTrue(resolved);
        assertFalse(win);
        assertEq(player1.balance, balBefore);
    }

    /*//////////////////////////////////////////////////////////////
                        Revert & 边界测试
    //////////////////////////////////////////////////////////////*/

    function test_Revert_CreateLottery_NotOwner() public {
        vm.prank(player1);
        vm.expectRevert();
        platform.createLottery(
            address(0),
            0.1 ether,
            block.timestamp,
            block.timestamp + 1 days
        );
    }

    function test_Revert_Dice_InvalidRollUnder() public {
        vm.prank(player1);
        vm.expectRevert();
        platform.playDice{value: 1 ether}(address(0), 1 ether, 1);
    }
}
