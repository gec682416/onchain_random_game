// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title RandomGamePlatform
 * @notice A verifiable on-chain random game platform integrating Chainlink VRF V2.5.
  * @dev Supports a time-based Lottery and a multiplier Dice game with ETH and ERC-20 wagers.
 *      Follows Checks-Effects-Interactions (CEI) and uses OpenZeppelin security modules.
 */
contract RandomGamePlatform is VRFConsumerBaseV2Plus, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Denominator for basis points calculations.
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @notice Dice sides (0-99).
    uint256 public constant DICE_SIDES = 100;

    /// @notice Maximum tickets purchasable per transaction to avoid gas blowup.
    uint256 public constant MAX_TICKETS_PER_BUY = 50;

    /// @notice Game types tracked per VRF request.
    enum GameType {
        Lottery,
        Dice
    }

    /// @notice Token configuration for wagering.
    struct TokenConfig {
        bool enabled;
        uint256 minBet;
        uint256 maxBet;
    }

    /// @notice Chainlink VRF configuration.
    struct VRFConfig {
        bytes32 keyHash;
        uint256 subId;
        uint16 requestConfirmations;
        uint32 callbackGasLimit;
        uint32 numWords;
        bool nativePayment;
    }

    /// @notice Lottery round data.
    struct Lottery {
        uint256 startTime;
        uint256 endTime;
        address token;
        uint256 ticketPrice;
        uint256 pot;
        address winner;
        bool drawRequested;
        bool drawn;
        uint256 requestId;
        address[] entries;
    }

    /// @notice Dice bet data.
    struct DiceBet {
        address player;
        address token;
        uint256 stake;
        uint8 rollUnder;
        uint256 potentialPayout;
        bool resolved;
        bool win;
        uint8 roll;
        uint256 requestId;
    }

    /// @notice VRF request metadata.
    struct RequestInfo {
        GameType game;
        uint256 id;
        bool exists;
    }

    /// @notice Current VRF configuration.
    VRFConfig public vrfConfig;

    /// @notice Return VRF configuration details for external tooling.
    function getVRFConfig()
        external
        view
        returns (
            address vrfCoordinator,
            bytes32 keyHash,
            uint64 subId,
            uint32 callbackGasLimit
        )
    {
        return (
            address(s_vrfCoordinator),
            vrfConfig.keyHash,
            uint64(vrfConfig.subId),
            vrfConfig.callbackGasLimit
        );
    }

    /// @notice Token configs mapped by token address (address(0) for ETH).
    mapping(address => TokenConfig) public tokenConfigs;

    /// @notice Funds reserved for pending payouts (address(0) for ETH).
    mapping(address => uint256) public lockedFunds;

    /// @notice House edge in basis points for Dice (e.g., 100 = 1%).
    uint256 public houseEdgeBps;

    /// @notice Lottery storage by id.
    mapping(uint256 => Lottery) public lotteries;

    /// @notice Dice bet storage by id.
    mapping(uint256 => DiceBet) public diceBets;

    /// @notice VRF request mapping to game.
    mapping(uint256 => RequestInfo) public requests;

    /// @notice Next lottery id.
    uint256 public nextLotteryId;

    /// @notice Next dice bet id.
    uint256 public nextDiceId;

    /// @notice Emitted when a lottery is created.
    event LotteryCreated(
        uint256 indexed lotteryId,
        address indexed token,
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Emitted when tickets are purchased.
    event TicketsPurchased(uint256 indexed lotteryId, address indexed buyer, uint256 count, uint256 cost);

    /// @notice Emitted when a lottery draw is requested.
    event LotteryDrawRequested(uint256 indexed lotteryId, uint256 indexed requestId);

    /// @notice Emitted when a lottery is drawn.
    event LotteryDrawn(uint256 indexed lotteryId, address indexed winner, uint256 pot, uint256 randomWord);

    /// @notice Emitted when a dice bet is placed.
    event DicePlayed(
        uint256 indexed diceId,
        address indexed player,
        address indexed token,
        uint256 stake,
        uint8 rollUnder,
        uint256 potentialPayout,
        uint256 requestId
    );

    /// @notice Emitted when a dice bet is resolved.
    event DiceResolved(
        uint256 indexed diceId,
        address indexed player,
        bool win,
        uint8 roll,
        uint256 payout
    );

    /// @notice Emitted when token config is updated.
    event TokenConfigUpdated(address indexed token, bool enabled, uint256 minBet, uint256 maxBet);

    /// @notice Emitted when house edge is updated.
    event HouseEdgeUpdated(uint256 oldBps, uint256 newBps);

    /// @notice Emitted when VRF config is updated.
    event VRFConfigUpdated(
        bytes32 keyHash,
        uint256 subId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bool nativePayment
    );

    /// @notice Emitted when funds are deposited.
    event Funded(address indexed sender, address indexed token, uint256 amount);

    /// @notice Emitted when funds are withdrawn.
    event Withdrawn(address indexed to, address indexed token, uint256 amount);

    /// @param vrfCoordinator Chainlink VRF V2.5 coordinator address.
    /// @param keyHash Chainlink VRF key hash.
    /// @param subId Chainlink subscription id.
    /// @param requestConfirmations VRF request confirmations.
    /// @param callbackGasLimit VRF callback gas limit.
    /// @param nativePayment Whether to pay VRF fees in native token.
    /// @param houseEdgeBps_ House edge in basis points for Dice.
    /// @param initialOwner Initial owner for Ownable.
    constructor(
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        bool nativePayment,
        uint256 houseEdgeBps_,
        address initialOwner
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        require(vrfCoordinator != address(0), "VRF coordinator required");
        require(initialOwner != address(0), "owner required");
        _setHouseEdge(houseEdgeBps_);

        // Transfer ownership to the specified initial owner
        if (initialOwner != msg.sender) {
            transferOwnership(initialOwner);
        }

        vrfConfig = VRFConfig({
            keyHash: keyHash,
            subId: subId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: 1,
            nativePayment: nativePayment
        });

        emit VRFConfigUpdated(
            keyHash,
            subId,
            requestConfirmations,
            callbackGasLimit,
            1,
            nativePayment
        );
    }

    /**
     * @notice Create a time-based lottery round.
     * @param token Token used for tickets (address(0) for ETH).
     * @param ticketPrice Ticket price in token units.
     * @param startTime Lottery start timestamp.
     * @param endTime Lottery end timestamp.
     */
    function createLottery(
        address token,
        uint256 ticketPrice,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner {
        require(ticketPrice > 0, "ticketPrice=0");
        require(startTime >= block.timestamp, "start in past");
        require(endTime > startTime, "invalid window");
        require(tokenConfigs[token].enabled, "token disabled");

        uint256 lotteryId = nextLotteryId++;
        Lottery storage lot = lotteries[lotteryId];
        lot.startTime = startTime;
        lot.endTime = endTime;
        lot.token = token;
        lot.ticketPrice = ticketPrice;

        emit LotteryCreated(lotteryId, token, ticketPrice, startTime, endTime);
    }

    /**
     * @notice Buy lottery tickets for an active round.
     * @param lotteryId Lottery id.
     * @param count Number of tickets to buy.
     */
    function buyTickets(uint256 lotteryId, uint256 count) external payable nonReentrant {
        require(count > 0 && count <= MAX_TICKETS_PER_BUY, "invalid count");

        Lottery storage lot = lotteries[lotteryId];
        require(block.timestamp >= lot.startTime, "not started");
        require(block.timestamp < lot.endTime, "ended");
        require(!lot.drawRequested && !lot.drawn, "draw requested");

        uint256 cost = lot.ticketPrice * count;

        // Effects
        lot.pot += cost;
        lockedFunds[lot.token] += cost;
        for (uint256 i = 0; i < count; i++) {
            lot.entries.push(msg.sender);
        }

        // Interactions
        _collectWager(lot.token, cost);

        emit TicketsPurchased(lotteryId, msg.sender, count, cost);
    }

    /**
     * @notice Request a lottery draw after it ends.
     * @param lotteryId Lottery id.
     */
    function requestLotteryDraw(uint256 lotteryId) external onlyOwner nonReentrant {
        Lottery storage lot = lotteries[lotteryId];
        require(block.timestamp >= lot.endTime, "not ended");
        require(!lot.drawRequested && !lot.drawn, "drawn");
        require(lot.entries.length > 0, "no entries");

        // Effects
        lot.drawRequested = true;

        // Interactions
        uint256 requestId = _requestRandomWords();
        lot.requestId = requestId;
        requests[requestId] = RequestInfo({game: GameType.Lottery, id: lotteryId, exists: true});

        emit LotteryDrawRequested(lotteryId, requestId);
    }

    /**
     * @notice Place a dice bet.
     * @param token Token used for wager (address(0) for ETH).
     * @param stake Wager amount.
     * @param rollUnder Win condition: roll must be < rollUnder (2-99).
     */
    function playDice(address token, uint256 stake, uint8 rollUnder) external payable nonReentrant {
        TokenConfig memory cfg = tokenConfigs[token];
        require(cfg.enabled, "token disabled");
        require(stake >= cfg.minBet && stake <= cfg.maxBet, "bet bounds");
        require(rollUnder >= 2 && rollUnder <= 99, "invalid rollUnder");

        uint256 potentialPayout = _calcDicePayout(stake, rollUnder);
        require(potentialPayout > 0, "payout=0");
        require(_canLock(token, stake, potentialPayout), "insufficient liquidity");

        uint256 diceId = nextDiceId++;

        // Effects
        diceBets[diceId] = DiceBet({
            player: msg.sender,
            token: token,
            stake: stake,
            rollUnder: rollUnder,
            potentialPayout: potentialPayout,
            resolved: false,
            win: false,
            roll: 0,
            requestId: 0
        });
        lockedFunds[token] += potentialPayout;

        // Interactions
        _collectWager(token, stake);
        uint256 requestId = _requestRandomWords();

        // Effects (requestId depends on interaction)
        diceBets[diceId].requestId = requestId;
        requests[requestId] = RequestInfo({game: GameType.Dice, id: diceId, exists: true});

        emit DicePlayed(diceId, msg.sender, token, stake, rollUnder, potentialPayout, requestId);
    }

    /**
     * @notice Fulfill VRF requests.
     * @param requestId VRF request id.
     * @param randomWords Random words provided by Chainlink.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override nonReentrant {
        RequestInfo memory req = requests[requestId];
        require(req.exists, "unknown request");

        // Effects
        delete requests[requestId];

        if (req.game == GameType.Lottery) {
            _resolveLottery(req.id, randomWords[0]);
        } else {
            _resolveDice(req.id, randomWords[0]);
        }
    }

    /**
     * @notice Update VRF configuration.
     * @param keyHash New key hash.
     * @param subId New subscription id.
     * @param requestConfirmations New confirmations count.
     * @param callbackGasLimit New callback gas limit.
     * @param nativePayment Whether to pay VRF fees in native token.
     */
    function setVRFConfig(
        bytes32 keyHash,
        uint256 subId,
        uint16 requestConfirmations,
        uint32 callbackGasLimit,
        bool nativePayment
    ) external onlyOwner {
        vrfConfig = VRFConfig({
            keyHash: keyHash,
            subId: subId,
            requestConfirmations: requestConfirmations,
            callbackGasLimit: callbackGasLimit,
            numWords: 1,
            nativePayment: nativePayment
        });

        emit VRFConfigUpdated(
            keyHash,
            subId,
            requestConfirmations,
            callbackGasLimit,
            1,
            nativePayment
        );
    }

    /**
     * @notice Update token config.
     * @param token Token address (address(0) for ETH).
     * @param enabled Whether the token is enabled for wagering.
     * @param minBet Minimum bet.
     * @param maxBet Maximum bet.
     */
    function setTokenConfig(
        address token,
        bool enabled,
        uint256 minBet,
        uint256 maxBet
    ) external onlyOwner {
        require(minBet <= maxBet, "min>max");
        tokenConfigs[token] = TokenConfig({enabled: enabled, minBet: minBet, maxBet: maxBet});
        emit TokenConfigUpdated(token, enabled, minBet, maxBet);
    }

    /**
     * @notice Update the house edge for Dice.
     * @param newBps New house edge in basis points.
     */
    function setHouseEdgeBps(uint256 newBps) external onlyOwner {
        _setHouseEdge(newBps);
    }

    /**
     * @notice Fund the contract with ERC-20 tokens.
     * @param token Token address.
     * @param amount Amount to deposit.
     */
    function fundToken(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "use ETH");
        require(amount > 0, "amount=0");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Funded(msg.sender, token, amount);
    }

    /**
     * @notice Fund the contract with ETH.
     */
    function fundETH() external payable {
        require(msg.value > 0, "amount=0");
        emit Funded(msg.sender, address(0), msg.value);
    }

    /**
     * @notice Withdraw available funds (excluding locked funds).
     * @param token Token address (address(0) for ETH).
     * @param amount Amount to withdraw.
     * @param to Recipient address.
     */
    function withdraw(address token, uint256 amount, address to) external onlyOwner nonReentrant {
        require(to != address(0), "to=0");
        require(amount > 0, "amount=0");
        uint256 available = _availableBalance(token);
        require(amount <= available, "insufficient available");

        _payout(token, to, amount);
        emit Withdrawn(to, token, amount);
    }

    /**
     * @notice Get a lottery entry count.
     * @param lotteryId Lottery id.
     * @return count Number of entries.
     */
    function getLotteryEntryCount(uint256 lotteryId) external view returns (uint256 count) {
        return lotteries[lotteryId].entries.length;
    }

    /**
     * @notice Get a lottery entry by index.
     * @param lotteryId Lottery id.
     * @param index Entry index.
     * @return entry Address of the entry.
     */
    function getLotteryEntry(uint256 lotteryId, uint256 index) external view returns (address entry) {
        return lotteries[lotteryId].entries[index];
    }

    /**
     * @notice Compute a dice payout (stake * fairMultiplier * (1 - houseEdge)).
     * @param stake Wager amount.
     * @param rollUnder Win condition.
     * @return payout Potential payout.
     */
    function calcDicePayout(uint256 stake, uint8 rollUnder) external view returns (uint256 payout) {
        return _calcDicePayout(stake, rollUnder);
    }

    /**
     * @notice Receive ETH deposits.
     */
    receive() external payable {
        emit Funded(msg.sender, address(0), msg.value);
    }

    // -------------------------
    // Internal helpers
    // -------------------------

    function _setHouseEdge(uint256 newBps) internal {
        require(newBps <= 1_000, "edge too high");
        uint256 old = houseEdgeBps;
        houseEdgeBps = newBps;
        emit HouseEdgeUpdated(old, newBps);
    }

    function _resolveLottery(uint256 lotteryId, uint256 randomWord) internal {
        Lottery storage lot = lotteries[lotteryId];
        require(lot.drawRequested && !lot.drawn, "lottery state");
        require(lot.entries.length > 0, "no entries");

        uint256 winnerIndex = randomWord % lot.entries.length;
        address winner = lot.entries[winnerIndex];
        uint256 pot = lot.pot;

        // Effects
        lot.winner = winner;
        lot.drawn = true;
        lockedFunds[lot.token] -= pot;

        // Interactions
        _payout(lot.token, winner, pot);

        emit LotteryDrawn(lotteryId, winner, pot, randomWord);
    }

    function _resolveDice(uint256 diceId, uint256 randomWord) internal {
        DiceBet storage bet = diceBets[diceId];
        require(!bet.resolved, "resolved");

        uint8 roll = uint8(randomWord % DICE_SIDES);
        bool win = roll < bet.rollUnder;
        uint256 payout = win ? bet.potentialPayout : 0;

        // Effects
        bet.resolved = true;
        bet.win = win;
        bet.roll = roll;
        lockedFunds[bet.token] -= bet.potentialPayout;

        // Interactions
        if (payout > 0) {
            _payout(bet.token, bet.player, payout);
        }

        emit DiceResolved(diceId, bet.player, win, roll, payout);
    }

    function _collectWager(address token, uint256 amount) internal {
        if (token == address(0)) {
            require(msg.value == amount, "bad ETH value");
        } else {
            require(msg.value == 0, "ETH not accepted");
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function _payout(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            (bool ok, ) = to.call{value: amount}("");
            require(ok, "ETH transfer failed");
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function _requestRandomWords() internal returns (uint256 requestId) {
        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: vrfConfig.keyHash,
            subId: vrfConfig.subId,
            requestConfirmations: vrfConfig.requestConfirmations,
            callbackGasLimit: vrfConfig.callbackGasLimit,
            numWords: vrfConfig.numWords,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: vrfConfig.nativePayment})
            )
        });

        return s_vrfCoordinator.requestRandomWords(req);
    }

    function _calcDicePayout(uint256 stake, uint8 rollUnder) internal view returns (uint256 payout) {
        // Fair multiplier = 100 / rollUnder. Apply house edge (bps) to reduce payout.
        uint256 numerator = stake * (BPS_DENOMINATOR - houseEdgeBps) * DICE_SIDES;
        uint256 denominator = uint256(rollUnder) * BPS_DENOMINATOR;
        return numerator / denominator;
    }

    function _availableBalance(address token) internal view returns (uint256) {
        uint256 bal = _tokenBalance(token);
        uint256 locked = lockedFunds[token];
        return bal > locked ? bal - locked : 0;
    }

    function _tokenBalance(address token) internal view returns (uint256) {
        if (token == address(0)) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    function _canLock(address token, uint256 stake, uint256 payout) internal view returns (bool) {
        uint256 locked = lockedFunds[token];
        if (token == address(0)) {
            // For ETH, msg.value is already in balance during execution.
            return address(this).balance >= locked + payout;
        }
        uint256 bal = IERC20(token).balanceOf(address(this));
        return bal + stake >= locked + payout;
    }
}
