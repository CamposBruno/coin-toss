// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {IRandomnessManager} from "./randomness/IRandomnessManager.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
/**
 * @title CoinToss
 * @author CamposBruno <bhncampos@gmail.com>
 * @dev A simple coin toss game contract where two players can join and toss a coin.
 * The first player chooses heads or tails, and the second player automatically gets the opposite choice.
 * The game can be played by calling the tossCoin function, which simulates a coin toss
 * and determines the winner based on the result of the toss.
 * The winner is the player whose choice matches the result of the toss.
 * The game state can be queried using the getGameDetails function, and player details can be
 * retrieved using the getPlayerDetails function.
 * @notice This contract is designed to be simple and easy to use, with a focus on
 * providing a straightforward coin toss game experience. It is not intended for production use
 * and should be used for educational purposes only.
 * It is important to note that this contract does not implement any security measures or
 * anti-cheat mechanisms, so it should not be used in a real-world scenario where security and fairness are critical.
 */

contract CoinToss is ReentrancyGuard {
    // Structs to represent player details and game state
    // These structs are used to store player information and game status.
    // PlayerDetails struct contains the player's address and their choice of heads or tails.
    // Game struct contains the details of the game, including player information, outcome, and game status.
    // GameInitialization struct is used to initialize the game with the first player's choice.
    // These structs are important for organizing the data related to the game and players.
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
    // It contains player details, game status, and the winner.
    // This is stored in a single Game struct to keep track of the game state.
    Game private currentGame;

    // Minimum staleness to prevent immediate use
    uint256 public constant MIN_GAME_STALENESS = 1 minutes;
    // Maximum staleness to prevent games from being played for too long
    uint256 public constant MAX_GAME_STALENESS = 1 days;

    // Events to log important actions in the game
    // These events can be used to track the game state and player actions.
    // They are emitted when players join the game and when the game outcome is determined.
    // Events are important for off-chain applications to listen to and react to game state changes.
    // They provide a way to log significant actions in the contract without modifying the state.
    // This is useful for dApps and other applications that need to track game events.
    // The events are indexed to allow for efficient filtering and searching.
    // The JoinedGame event is emitted when a player joins the game, and the GameOutcome
    // event is emitted when the game outcome is determined after the toss.
    event JoinedGame(address indexed player1, address indexed player2);
    event GameOutcome(address indexed winner, bool outcome); // outcome: 0 for heads, 1 for tails

    /**
     * @param gameInit initializes the game with the first player's choice.
     * @notice This function is called when the contract is deployed to set up the initial game state.
     * It initializes the first player with their choice of heads or tails.
     * The first player is the one who deploys the contract, and they can choose heads or tails.
     * The game is not completed at this point, and the second player can join later.
     * @dev This function sets the player1 details and marks the game as not completed.
     * It is important to note that this function is called only once when the contract is deployed
     * and does not modify the state of the contract after that.
     */
    constructor(GameInitialization memory gameInit) {
        require(gameInit.randomnessManager != address(0), "Invalid randomness manager address");
        require(
            gameInit.maxStaleness >= MIN_GAME_STALENESS && gameInit.maxStaleness <= MAX_GAME_STALENESS,
            "Invalid max staleness"
        );

        Game storage game = currentGame; // Use storage to modify the game state
        IRandomnessManager randomnessManager = IRandomnessManager(gameInit.randomnessManager);

        game.player1 = PlayerDetails({
            player: msg.sender, // The deployer is player 1
            side: gameInit.side // player 1 chosen side
        });

        // check if the randomness manager implements the IRandomnessManager interface
        require(
            randomnessManager.supportsInterface(type(IRandomnessManager).interfaceId),
            "Invalid randomness manager interface"
        );

        game.randomness.manager = randomnessManager;
        game.initTimestamp = block.timestamp;
        game.maxStaleness = gameInit.maxStaleness;
    }

    /**
     * @dev Allows a second player to join the game.
     * @notice This function allows a second player to join the game after the first player has initialized it.
     * The second player will automatically choose the opposite side of the coin from the first player.
     * It can only be called by a player who is not already in the game.
     * @notice This function emits a JoinedGame event with the addresses of both players.
     * It is important to note that this function modifies the state of the contract, so it will cost gas to call.
     * It is intended to be called by the second player after the first player has initialized the game.
     */
    function joinGame() public nonReentrant {
        Game storage game = currentGame; // Use storage to modify the game state

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
        // Randomness is only requested once when the second player joins. this is to save randomness credits.
        // The request ID is stored in the game state to be used later for retrieving the random words.
        game.randomness.requestId = game.randomness.manager.requestRandomWords(1);
        game.joinTimestamp = block.timestamp;

        emit JoinedGame(currentGame.player1.player, currentGame.player2.player);
    }

    /**
     * @dev Simulates a coin toss and determines the winner.
     * @notice This function allows the players to toss the coin and determine the winner based on
     * the result of the toss. It can only be called by either player after both players have joined the game.
     * The result of the toss is determined by a simple pseudo-randomness mechanism based on the block timestamp.
     * The winner is determined based on whether the toss result matches the choice of player 1 or player 2.
     * If player 1 chose heads and the toss result is heads, player 1 wins; otherwise, player 2 wins.
     * The game is marked as completed after the toss, and the winner is recorded.
     * @notice This function emits a GameOutcome event with the winner's address and the toss result.
     * It is important to note that this function modifies the state of the contract, so it will cost gas to call.
     * It is intended to be called by the players after they have joined the game.
     * @dev This function does not return any value, but it emits an event with the outcome of the game.
     */
    function tossCoin() public nonReentrant {
        Game storage game = currentGame; // Use storage to modify the game state

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

        emit GameOutcome(winner.player, outcome); // Emit the outcome of the game
    }

    // DEPRECATED
    // Is not possible to join the game and toss the coin in one transaction because
    // the randomness request is made when the second player joins the game.
    // and the tossCoin function requires the randomness to be fulfilled,
    // which might take at least 3 blocks after the request.
    // /**
    //  * @dev Allows a player to join the game and toss the coin in one transaction.
    //  * @notice This function combines the joinGame and tossCoin functions into a single transaction.
    //  * It allows a player to join the game and immediately toss the coin without needing to call
    //  * the functions separately. This is useful for players who want to quickly join the game and
    //  * determine the outcome in one go.
    //  */
    // function joinGameAndTossCoin() external {
    //     joinGame();
    //     tossCoin();
    // }

    /**
     * @dev Generates a pseudo-random number based on the block timestamp.
     * @notice This function is used to generate a pseudo-random number for the coin toss.
     * It uses the block timestamp to create a random seed for the toss result.
     * Note: This is a simple pseudo-randomness mechanism and should not be used for
     * cryptographic purposes or in scenarios where security is critical.
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

    /**
     * @dev Returns the current game details.
     * @notice This function allows anyone to view the current game state, including player details and
     * whether the game is completed or not, and who the winner is if the game has been completed.
     * It is useful for players to check the status of the game and see who has joined.
     * It can also be used to verify the outcome of the game after it has been completed.
     * Note: This function does not modify the state of the contract, it only reads the current game state.
     * It is a view function, meaning it does not cost any gas to call.
     * @return Game the current game details including player information and game status.
     */
    function getGameDetails() external view returns (Game memory) {
        return currentGame; // Return the current game details
    }

    /**
     * @param isPlayer1 true for player 1, false for player 2
     * @return player details for the specified player
     * @notice This function allows anyone to retrieve the details of a specific player in the game.
     * It can be used to check the player addresses and their choices (heads or tails).
     * It is useful for verifying the players' choices and addresses after they have joined the game.
     * It does not modify the state of the contract, so it is a view function and does not cost gas to call.
     */
    function getPlayerDetails(bool isPlayer1) external view returns (PlayerDetails memory player) {
        return isPlayer1 ? currentGame.player1 : currentGame.player2;
    }
}
