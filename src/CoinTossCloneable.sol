// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IRandomnessManager} from "./randomness/IRandomnessManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CoinTossCloneable
 * @author CamposBruno <bhncampos@gmail.com>
 * @dev A cloneable version of the CoinToss contract that can be deployed via factory clones.
 * This version uses an initializer function instead of a constructor to support the clone pattern.
 * 
 * The game mechanics remain the same:
 * - First player chooses heads or tails and initializes the game
 * - Second player joins and automatically gets the opposite choice
 * - Either player can toss the coin after randomness is fulfilled
 * - Winner is determined by matching the coin result with their choice
 */
contract CoinTossCloneable is ReentrancyGuard {
    // Structs remain the same as the original CoinToss
    struct PlayerDetails {
        address player;
        bool side; // true for heads, false for tails
    }

    struct GameRandomness {
        IRandomnessManager manager; // address of the randomness manager contract
        uint256 requestId; // ID of the randomness request
    }

    struct Game {
        PlayerDetails player1;
        PlayerDetails player2;
        GameRandomness randomness; // randomness manager and request ID
        uint256 randomnessRequestId; // request ID for the randomness request
        address winner; // address of the winner
        bool isCompleted; // true if the game is completed, false otherwise
        bool outcome; // true for heads, false for tails
        uint256 initTimestamp; // timestamp of the initialization of the game
        uint256 joinTimestamp; // timestamp of the join of the game
        uint256 maxStaleness; // maximum stalness for the game
        uint256 minStaleness; // minimum stalness for the game
    }

    struct GameInitialization {
        bool side; // true for heads, false for tails
        address randomnessManager; // address of the randomness manager contract
        uint256 maxStaleness; // maximum stalness for the game
    }

    // The current game state
    Game private currentGame;

    // Track if this clone has been initialized
    bool private _initialized;

    // Constants remain the same
    uint256 public constant MIN_GAME_STALENESS = 1 minutes;
    uint256 public constant MAX_GAME_STALENESS = 1 days;

    // Events remain the same
    event JoinedGame(address indexed player1, address indexed player2);
    event GameOutcome(address indexed winner, bool outcome);

    // Error for already initialized
    error AlreadyInitialized();
    error NotInitialized();

    /**
     * @dev Constructor is empty for cloneable contracts
     * The actual initialization happens in the initialize function
     */
    constructor() {
        // Empty constructor for cloneable pattern
    }

    /**
     * @dev Initializes the cloned contract with game parameters
     * @param gameInit The game initialization parameters
     * @param player1 The address of player 1 (the one creating the game)
     * @notice This function replaces the constructor for cloned contracts
     */
    function initialize(GameInitialization memory gameInit, address player1) external {
        if (_initialized) revert AlreadyInitialized();
        
        require(gameInit.randomnessManager != address(0), "Invalid randomness manager address");
        require(
            gameInit.maxStaleness >= MIN_GAME_STALENESS && gameInit.maxStaleness <= MAX_GAME_STALENESS,
            "Invalid max staleness"
        );
        require(player1 != address(0), "Invalid player1 address");

        Game storage game = currentGame;
        IRandomnessManager randomnessManager = IRandomnessManager(gameInit.randomnessManager);

        game.player1 = PlayerDetails({
            player: player1,
            side: gameInit.side
        });

        // check if the randomness manager implements the IRandomnessManager interface
        require(
            randomnessManager.supportsInterface(type(IRandomnessManager).interfaceId),
            "Invalid randomness manager interface"
        );

        game.randomness.manager = randomnessManager;
        game.initTimestamp = block.timestamp;
        game.maxStaleness = gameInit.maxStaleness;

        _initialized = true;
    }

    /**
     * @dev Modifier to ensure the contract is initialized
     */
    modifier onlyInitialized() {
        if (!_initialized) revert NotInitialized();
        _;
    }

    /**
     * @dev Allows a second player to join the game.
     * Same logic as original CoinToss contract
     */
    function joinGame() public nonReentrant onlyInitialized {
        Game storage game = currentGame;

        require(game.isCompleted == false, "Game already completed");
        require(game.player1.player != address(0), "Game not initialized yet");
        require(game.player1.player != msg.sender, "Player 1 cannot join again");
        require(game.player2.player == address(0), "Game already joined");
        require(block.timestamp - game.initTimestamp >= MIN_GAME_STALENESS, "Game too fresh");
        require(block.timestamp - game.initTimestamp <= game.maxStaleness, "Game too stale");

        game.player2 = PlayerDetails({
            player: msg.sender,
            side: !currentGame.player1.side // select opposite side
        });

        // Request 1 random word for the game
        game.randomness.requestId = game.randomness.manager.requestRandomWords(1);
        game.joinTimestamp = block.timestamp;

        emit JoinedGame(currentGame.player1.player, currentGame.player2.player);
    }

    /**
     * @dev Simulates a coin toss and determines the winner.
     * Same logic as original CoinToss contract
     */
    function tossCoin() public nonReentrant onlyInitialized {
        Game storage game = currentGame;

        require(!game.isCompleted, "Game already completed");
        require(game.player1.player != address(0), "Game not initialized yet");
        require(game.player2.player != address(0), "Game not joined yet");
        require(
            game.player1.player == msg.sender || game.player2.player == msg.sender, "Only players can toss the coin"
        );
        require(game.randomness.requestId != 0, "Randomness not Requested");
        require(game.randomness.manager.isRequestFulfilled(game.randomness.requestId), "Randomness not ready yet");
        require(block.timestamp - game.joinTimestamp >= MIN_GAME_STALENESS, "Game too fresh after join");
        require(block.timestamp - game.joinTimestamp <= game.maxStaleness, "Game too stale after join");

        // Simulate a coin toss
        bool outcome = (sourceOfRandomness() % 2 == 0);

        // Determine the winner based on the toss result
        PlayerDetails memory winner = outcome == game.player1.side ? game.player1 : game.player2;

        assert(outcome == winner.side); // Ensure the winner's choice matches the toss result

        game.outcome = outcome; // Store the result of the toss
        game.isCompleted = true; // Mark the game as completed
        game.winner = winner.player; // Set the winner

        emit GameOutcome(winner.player, outcome);
    }

    /**
     * @dev Generates randomness using VRF and additional entropy
     * Same logic as original CoinToss contract
     */
    function sourceOfRandomness() internal view returns (uint256) {
        GameRandomness storage randomness = currentGame.randomness;

        // Get the primary random word from VRF
        uint256[] memory randomWords = randomness.manager.getRandomWords(randomness.requestId);
        uint256 primaryRandomness = randomWords[0];

        // Additional entropy validation
        require(primaryRandomness != 0, "Random word cannot be zero");
        require(primaryRandomness != type(uint256).max, "Random word cannot be max value");

        // Add additional entropy sources for enhanced security
        uint256 additionalEntropy = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp, // current block timestamp as seconds since unix epoch
                    block.prevrandao, // random number provided by the beacon chain
                    msg.sender, // player address
                    randomness.requestId // request ID
                )
            )
        );

        // Combine primary randomness with additional entropy
        return uint256(keccak256(abi.encodePacked(primaryRandomness, additionalEntropy)));
    }

    // View functions remain the same
    function getGameDetails() external view onlyInitialized returns (Game memory) {
        return currentGame;
    }

    function getPlayerDetails(bool isPlayer1) external view onlyInitialized returns (PlayerDetails memory player) {
        return isPlayer1 ? currentGame.player1 : currentGame.player2;
    }

    function isInitialized() external view returns (bool) {
        return _initialized;
    }
}