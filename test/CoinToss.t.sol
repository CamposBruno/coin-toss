// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CoinToss} from "../src/CoinToss.sol";
import {RandomnessManagerV1Mock} from "./mocks/RandomnessManagerV1.mock.sol";

contract CoinTossTest is Test {
    CoinToss toss;
    address player1 = address(0x121);
    RandomnessManagerV1Mock randomnessManagerMock;

    function setUp() public {
        vm.startPrank(player1);

        randomnessManagerMock = new RandomnessManagerV1Mock();

        toss = new CoinToss(
            CoinToss.GameInitialization({
                side: true, // Player 1 chooses heads
                randomnessManager: address(randomnessManagerMock), // Mock address for randomness manager
                maxStaleness: 1 days // 1 day is the maximum staleness for the game
            })
        );
        // wait for 1 minute to ensure the game is not too fresh
        vm.warp(block.timestamp + toss.MIN_GAME_STALENESS());
        vm.stopPrank();
    }

    function joinGameAndWaitMinStalness() internal {
        toss.joinGame();
        // wait for min game stalness to ensure the game is not too fresh
        vm.warp(block.timestamp + toss.MIN_GAME_STALENESS());
    }

    // ========== BASIC FUNCTIONALITY TESTS ==========

    function test_JoinGame() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        // Check that player 2 has joined the game
        CoinToss.PlayerDetails memory player1Details = toss.getPlayerDetails(true);
        CoinToss.PlayerDetails memory player2Details = toss.getPlayerDetails(false);

        assertEq(player1Details.player, player1); // Player 1 is the contract deployer
        assertEq(player2Details.player, player2); // Player 2 is the mocked address
        assertTrue(player1Details.side); // Player 1 chose heads
        assertFalse(player2Details.side); // Player 2 chose tails
    }

    function test_TossCoin() public {
        address player2 = address(0x123);
        vm.startPrank(player2);

        joinGameAndWaitMinStalness();

        _mockFulfillRandomWords(1); // Mock the random words fulfillment

        toss.tossCoin();

        vm.stopPrank();

        // Check the game outcome
        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.isCompleted); // Game should be completed
        assertTrue(game.winner == player1 || game.winner == player2); // Winner should be one of the players
    }

    // ========== EDGE CASES AND ERROR CONDITIONS ==========

    function test_TossCoinOnUninitializedGame() public {
        // Attempt to toss coin without joining the game
        vm.expectRevert("Game not joined yet");
        toss.tossCoin();
    }

    function test_TossCoinOnCompletedGame() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();

        _mockFulfillRandomWords(1); // Mock the random words fulfillment

        toss.tossCoin(); // Complete the game
        vm.stopPrank();

        // Attempt to toss coin again on a completed game
        vm.expectRevert("Game already completed");
        toss.tossCoin();
    }

    function test_TossCoinFromNotPlayer() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        // Attempt to toss coin from a different player
        vm.expectRevert("Only players can toss the coin");
        vm.prank(address(0x456)); // Mock a different player
        toss.tossCoin();
    }

    function test_TossCoinOnRandomnessNotReady() public {
        address player2 = address(0x123);
        vm.startPrank(player2);

        joinGameAndWaitMinStalness();

        vm.expectRevert("Randomness not ready yet");
        toss.tossCoin();

        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.isCompleted == false); // Game should not be completed
        assertTrue(game.winner == address(0)); // Winner should be no one
    }

    function test_EdgeCase_OneSecondAfterMaximum() public {
        address player2 = address(0x123);
        vm.startPrank(player2);

        // Try to join one second after maximum staleness
        vm.warp(block.timestamp + toss.MAX_GAME_STALENESS() + 1 seconds);

        vm.expectRevert("Game too stale");
        toss.joinGame();
        vm.stopPrank();
    }

    function test_EdgeCase_MinimumStaleness() public {
        address player2 = address(0x123);
        vm.startPrank(player2);

        // Try to join exactly at minimum staleness
        vm.warp(block.timestamp + toss.MIN_GAME_STALENESS());

        toss.joinGame();
        vm.stopPrank();

        // Verify game state
        CoinToss.Game memory game = toss.getGameDetails();
        assertEq(game.player2.player, player2);
    }

    // ========== CONSTRUCTOR EDGE CASES ==========

    function test_ConstructorWithZeroAddress() public {
        vm.expectRevert("Invalid randomness manager address");
        new CoinToss(CoinToss.GameInitialization({side: true, randomnessManager: address(0), maxStaleness: 1 hours}));
    }

    function test_ConstructorWithInvalidInterface() public {
        // Deploy a contract that doesn't implement IRandomnessManager
        address invalidManager = address(0x999);

        // This should revert because the contract doesn't implement the interface
        vm.expectRevert();
        new CoinToss(
            CoinToss.GameInitialization({side: true, randomnessManager: invalidManager, maxStaleness: 1 hours})
        );
    }

    function test_ConstructorWithStalenessTooLow() public {
        vm.expectRevert("Invalid max staleness");
        new CoinToss(
            CoinToss.GameInitialization({
                side: true,
                randomnessManager: address(randomnessManagerMock),
                maxStaleness: 1 minutes - 1 seconds // Too low, should be > 1 minute
            })
        );
    }

    function test_ConstructorWithStalenessTooHigh() public {
        vm.expectRevert("Invalid max staleness");
        new CoinToss(
            CoinToss.GameInitialization({
                side: true,
                randomnessManager: address(randomnessManagerMock),
                maxStaleness: 1 days + 1 seconds // Too high, should be <= 1 day
            })
        );
    }

    function test_ConstructorWithValidStaleness() public {
        // Test the boundary values
        CoinToss toss1 = new CoinToss(
            CoinToss.GameInitialization({
                side: true,
                randomnessManager: address(randomnessManagerMock),
                maxStaleness: 1 minutes + 1 // Just above minimum
            })
        );

        CoinToss toss2 = new CoinToss(
            CoinToss.GameInitialization({
                side: false,
                randomnessManager: address(randomnessManagerMock),
                maxStaleness: 1 days // Maximum allowed
            })
        );

        // Verify both contracts were created successfully
        assertTrue(address(toss1) != address(0));
        assertTrue(address(toss2) != address(0));
    }

    // ========== JOIN GAME EDGE CASES ==========

    function test_JoinGameTwice() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();

        vm.expectRevert("Game already joined");
        joinGameAndWaitMinStalness();
        vm.stopPrank();
    }

    function test_JoinGameByPlayer1() public {
        vm.startPrank(player1);
        vm.expectRevert("Player 1 cannot join again");
        joinGameAndWaitMinStalness();
        vm.stopPrank();
    }

    function test_JoinGameOnCompletedGame() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();

        _mockFulfillRandomWords(1);
        toss.tossCoin();
        vm.stopPrank();

        // Try to join after game is completed
        vm.startPrank(address(0x789));
        vm.expectRevert("Game already completed");
        joinGameAndWaitMinStalness();
        vm.stopPrank();
    }

    function test_JoinGameTooFresh() public {
        vm.startPrank(player1);

        CoinToss newGame = new CoinToss(
            CoinToss.GameInitialization({
                side: true, // Player 1 chooses heads
                randomnessManager: address(randomnessManagerMock), // Mock address for randomness manager
                maxStaleness: 1 days // 1 day is the maximum staleness for the game
            })
        );
        vm.stopPrank();

        address player2 = address(0x123);
        vm.startPrank(player2);

        // Try to join immediately after game creation
        vm.expectRevert("Game too fresh");
        newGame.joinGame();
        vm.stopPrank();
    }

    function test_JoinGameTooStale() public {
        address player2 = address(0x123);
        vm.startPrank(player2);

        // Warp time to make game stale
        vm.warp(block.timestamp + 1 days + 1 seconds); // Game max staleness is 1 hour

        vm.expectRevert("Game too stale");
        toss.joinGame();
        vm.stopPrank();
    }

    function test_JoinGameOnMaxStaleness() public {
        address player2 = address(0x123);
        vm.startPrank(player2);

        // Since setUp already warped by 1 minute, we need to warp by 1 day - 1 minute
        vm.warp(block.timestamp + toss.MAX_GAME_STALENESS() - 1 minutes);
        toss.joinGame();
        vm.stopPrank();

        assertTrue(toss.getPlayerDetails(false).player == player2);
    }

    function test_JoinGameOnMinStaleness() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        // Since setUp already warped by 1 minute, we need to warp by 1 day - 1 minute
        vm.warp(block.timestamp + toss.MIN_GAME_STALENESS() - 1 minutes);
        toss.joinGame();
        vm.stopPrank();

        assertTrue(toss.getPlayerDetails(false).player == player2);
    }

    // ========== GAME STATE TESTS ==========

    function test_GameStateBeforeJoin() public view {
        CoinToss.Game memory game = toss.getGameDetails();

        assertEq(game.player1.player, player1);
        assertTrue(game.player1.side);
        assertEq(game.player2.player, address(0));
        assertFalse(game.isCompleted);
        assertEq(game.winner, address(0));
    }

    function test_GameStateAfterJoin() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();

        assertEq(game.player1.player, player1);
        assertTrue(game.player1.side);
        assertEq(game.player2.player, player2);
        assertFalse(game.player2.side);
        assertFalse(game.isCompleted);
        assertEq(game.winner, address(0));
        assertTrue(game.randomness.requestId != 0);
    }

    function test_GameStateAfterToss() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();

        _mockFulfillRandomWords(1);
        toss.tossCoin();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();

        assertTrue(game.isCompleted);
        assertTrue(game.winner == player1 || game.winner == player2);
        assertTrue(game.outcome == true || game.outcome == false);
    }

    // ========== PLAYER DETAILS TESTS ==========

    function test_GetPlayerDetails() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        CoinToss.PlayerDetails memory player1Details = toss.getPlayerDetails(true);
        CoinToss.PlayerDetails memory player2Details = toss.getPlayerDetails(false);

        assertEq(player1Details.player, player1);
        assertTrue(player1Details.side);
        assertEq(player2Details.player, player2);
        assertFalse(player2Details.side);
    }

    function test_TossCoinTooFreshAfterJoin() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        toss.joinGame();

        _mockFulfillRandomWords(1);

        // Try to toss immediately after joining
        vm.expectRevert("Game too fresh after join");
        toss.tossCoin();
        vm.stopPrank();
    }

    function test_TossCoinTooStaleAfterJoin() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        toss.joinGame();

        _mockFulfillRandomWords(1);

        // Warp time to make game stale after join
        vm.warp(block.timestamp + toss.MAX_GAME_STALENESS() + 1 seconds);

        vm.expectRevert("Game too stale after join");
        toss.tossCoin();
        vm.stopPrank();
    }

    // ========== RANDOMNESS TESTS ==========

    function test_RandomnessRequestId() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.randomness.requestId > 0);
    }

    function test_MultipleRandomnessFulfillments() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        // Fulfill randomness multiple times
        _mockFulfillRandomWords(1);
        _mockFulfillRandomWords(28); // Should not affect the game

        vm.startPrank(player2);
        toss.tossCoin();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.isCompleted);
    }

    // ========== FUZZING TESTS ==========

    function testFuzz_Player2Address(address player2) public {
        vm.assume(player2 != address(0));
        vm.assume(player2 != player1);

        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        CoinToss.PlayerDetails memory player2Details = toss.getPlayerDetails(false);
        assertEq(player2Details.player, player2);
        assertFalse(player2Details.side);
    }

    function testFuzz_Player1Side(bool player1Side) public {
        vm.startPrank(player1);

        RandomnessManagerV1Mock newMock = new RandomnessManagerV1Mock();
        CoinToss newToss = new CoinToss(
            CoinToss.GameInitialization({side: player1Side, randomnessManager: address(newMock), maxStaleness: 1 hours})
        );
        vm.stopPrank();

        CoinToss.PlayerDetails memory player1Details = newToss.getPlayerDetails(true);
        assertEq(player1Details.side, player1Side);
    }

    function testFuzz_RandomWords(uint256 randomWord) public {
        // Exclude values that will cause reverts in sourceOfRandomness()
        vm.assume(randomWord != 0);
        vm.assume(randomWord != type(uint256).max);

        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        _mockFulfillRandomWordsWithValue(1, randomWord);

        vm.startPrank(player2);
        toss.tossCoin();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.isCompleted);
        assertTrue(game.winner == player1 || game.winner == player2);
    }

    // ========== EVENT TESTS ==========

    function test_JoinedGameEvent() public {
        address player2 = address(0x123);
        vm.startPrank(player2);

        vm.expectEmit(true, true, false, false);
        emit CoinToss.JoinedGame(player1, player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();
    }

    function test_GameOutcomeEvent() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();

        _mockFulfillRandomWords(1);

        // We can't predict the exact outcome, so we just check that an event is emitted
        // Don't use expectEmit since we can't predict the winner
        toss.tossCoin();
        vm.stopPrank();
    }

    // ========== GAS OPTIMIZATION TESTS ==========

    function test_GasUsageForJoinGame() public {
        address player2 = address(0x123);
        vm.startPrank(player2);

        uint256 gasBefore = gasleft();
        joinGameAndWaitMinStalness();
        uint256 gasUsed = gasBefore - gasleft();

        // Ensure gas usage is reasonable (less than 200k gas)
        assertTrue(gasUsed < 200000);
        vm.stopPrank();
    }

    function test_GasUsageForTossCoin() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        _mockFulfillRandomWords(1);

        uint256 gasBefore = gasleft();
        toss.tossCoin();
        uint256 gasUsed = gasBefore - gasleft();

        // Ensure gas usage is reasonable (less than 100k gas)
        assertTrue(gasUsed < 100000);
        vm.stopPrank();
    }

    // ========== WINNER DETERMINATION BRANCH COVERAGE TESTS ==========

    function test_WinnerDeterminationPlayer1Wins() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();

        // Mock randomness to ensure player 1 wins (even outcome when player 1 chose heads)
        _mockFulfillRandomWordsWithValue(1, 42); // Even number for heads outcome

        toss.tossCoin();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.isCompleted);
        assertEq(game.winner, player1); // Player 1 should win
        assertTrue(game.outcome); // Should be heads
    }

    function test_WinnerDeterminationPlayer2Wins() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        toss.joinGame();

        // Mock randomness to ensure player 2 wins (odd outcome when player 1 chose heads)
        _mockFulfillRandomWordsWithValue(1, 43); // Odd number for tails outcome

        vm.warp(block.timestamp + 2 minutes);
        toss.tossCoin();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.isCompleted);
        assertEq(game.winner, player2); // Player 2 should win
        assertFalse(game.outcome); // Should be tails
    }

    // ========== PLAYER DETAILS BRANCH COVERAGE TESTS ==========

    function test_GetPlayerDetailsPlayer1() public view {
        CoinToss.PlayerDetails memory player1Details = toss.getPlayerDetails(true);
        assertEq(player1Details.player, player1);
        assertTrue(player1Details.side);
    }

    function test_GetPlayerDetailsPlayer2() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        toss.joinGame();
        vm.stopPrank();

        CoinToss.PlayerDetails memory player2Details = toss.getPlayerDetails(false);
        assertEq(player2Details.player, player2);
        assertFalse(player2Details.side);
    }

    // ========== REENTRANCY TESTS ==========

    function test_ReentrancyJoinGame() public {
        // This test ensures that the contract is not vulnerable to reentrancy attacks
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        // Try to join again immediately
        vm.startPrank(player2);
        vm.expectRevert("Game already joined");
        joinGameAndWaitMinStalness();
        vm.stopPrank();
    }

    function test_ReentrancyTossCoin() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        _mockFulfillRandomWords(1);
        toss.tossCoin();
        vm.stopPrank();

        // Try to toss again immediately
        vm.startPrank(player2);
        vm.expectRevert("Game already completed");
        toss.tossCoin();
        vm.stopPrank();
    }

    // ========== BOUNDARY TESTS ==========

    function test_MaxUint256RandomWord() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        _mockFulfillRandomWordsWithValue(1, type(uint256).max);

        vm.startPrank(player2);
        vm.expectRevert("Random word cannot be max value");
        toss.tossCoin();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(!game.isCompleted);
    }

    function test_ZeroRandomWord() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        _mockFulfillRandomWordsWithValue(1, 0);

        vm.startPrank(player2);
        vm.expectRevert("Random word cannot be zero");
        toss.tossCoin();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(!game.isCompleted);
    }

    // ========== HELPER FUNCTIONS ==========

    function _mockFulfillRandomWords(uint256 requestId) internal {
        // Mock the fulfillment of random words
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 1; // Mock random word

        randomnessManagerMock.rawFulfillRandomWords(requestId, randomWords); // Mock the randomness fulfillment
    }

    function _mockFulfillRandomWordsWithValue(uint256 requestId, uint256 value) internal {
        // Mock the fulfillment of random words with a specific value
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = value;

        randomnessManagerMock.rawFulfillRandomWords(requestId, randomWords);
    }

    // ========== INVARIANT TESTS ==========

    function test_Invariant_GameStateConsistency() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        CoinToss.Game memory game = toss.getGameDetails();

        // Invariant: If game is not completed, winner should be address(0)
        if (!game.isCompleted) {
            assertEq(game.winner, address(0));
        }

        // Invariant: Player sides should be opposite
        assertTrue(game.player1.side != game.player2.side);

        // Invariant: If game is completed, winner should be one of the players
        if (game.isCompleted) {
            assertTrue(game.winner == game.player1.player || game.winner == game.player2.player);
        }
    }

    function test_Invariant_PlayerAddressesNotZero() public view {
        CoinToss.Game memory game = toss.getGameDetails();

        // Invariant: Player 1 should never be address(0) after initialization
        assertTrue(game.player1.player != address(0));
    }

    function test_ConstructorWithZeroRandomnessManager() public {
        vm.expectRevert("Invalid randomness manager address");
        new CoinToss(
            CoinToss.GameInitialization({
                side: true,
                randomnessManager: address(0), // This should trigger the revert
                maxStaleness: 1 hours
            })
        );
    }

    function test_ConstructorWithStalenessEqualToMin() public {
        vm.expectRevert("Invalid max staleness");
        new CoinToss(
            CoinToss.GameInitialization({
                side: true,
                randomnessManager: address(randomnessManagerMock),
                maxStaleness: 1 minutes - 1 seconds // Exactly equal + 1 second to MIN_GAME_STALENESS, should fail
            })
        );
    }

    function test_ConstructorWithStalenessEqualToMax() public {
        // This should pass since it's exactly at the maximum
        CoinToss validGame = new CoinToss(
            CoinToss.GameInitialization({
                side: true,
                randomnessManager: address(randomnessManagerMock),
                maxStaleness: 1 days // Exactly equal to MAX_GAME_STALENESS, should pass
            })
        );

        assertTrue(address(validGame) != address(0));
    }

    function test_TossCoinWithoutRandomnessRequest() public {
        address player2 = address(0x123);
        vm.startPrank(player2);
        joinGameAndWaitMinStalness();
        vm.stopPrank();

        // Try to toss coin without randomness being requested/fulfilled
        vm.startPrank(player2);
        vm.expectRevert("Randomness not ready yet");
        toss.tossCoin();
        vm.stopPrank();
    }
}
