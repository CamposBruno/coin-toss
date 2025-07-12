// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CoinToss} from "../src/CoinToss.sol";

contract CoinTossTest is Test {

    function setUp() public {}

    function test_JoinGame() public {
        address player1 = address(0x121);

        vm.startPrank(player1);    
        CoinToss toss = new CoinToss(CoinToss.GameInitialization({
            side: true // Player 1 chooses heads
        }));
        vm.stopPrank();

        address player2 = address(0x123);
        vm.startPrank(player2);
        toss.joinGame();        
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
        address player1 = address(0x121);        
        vm.startPrank(player1);    
        CoinToss toss = new CoinToss(CoinToss.GameInitialization({
            side: true // Player 1 chooses heads
        }));
        vm.stopPrank();

        address player2 = address(0x123);
        vm.startPrank(player2);
        
        toss.joinGame();
        toss.tossCoin();

        vm.stopPrank();

        // Check the game outcome
        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.isCompleted); // Game should be completed
        assertTrue(game.winner == player1 || game.winner == player2); // Winner should be one of the players
    }

    function test_TossCoinAndJoinGame() public {
        address player1 = address(0x121);        
        vm.startPrank(player1);    
        CoinToss toss = new CoinToss(CoinToss.GameInitialization({
            side: true // Player 1 chooses heads
        }));
        vm.stopPrank();

        address player2 = address(0x123);
        vm.startPrank(player2);
        toss.joinGameAndTossCoin();
        vm.stopPrank();

        // Check the game outcome
        CoinToss.Game memory game = toss.getGameDetails();
        assertTrue(game.isCompleted); // Game should be completed
        assertTrue(game.winner == player1 || game.winner == player2); // Winner should be one of the players
    }

    function test_TossCoinOnUninitializedGame() public {
        address player1 = address(0x121);        
        vm.startPrank(player1);    
        CoinToss toss = new CoinToss(CoinToss.GameInitialization({
            side: true // Player 1 chooses heads
        }));
        vm.stopPrank();
        // Attempt to toss coin without joining the game
        vm.expectRevert("Game not joined yet");
        toss.tossCoin();
    }

    function test_TossCoinOnCompletedGame() public {
        address player1 = address(0x121);        
        vm.startPrank(player1);    
        CoinToss toss = new CoinToss(CoinToss.GameInitialization({
            side: true // Player 1 chooses heads
        }));
        vm.stopPrank();

        address player2 = address(0x123);
        vm.startPrank(player2);
        toss.joinGame();
        toss.tossCoin(); // Complete the game
        vm.stopPrank();

        // Attempt to toss coin again on a completed game
        vm.expectRevert("Game already completed");
        toss.tossCoin();
    }

    function test_TossCoinFromNotPlayer() public {
        address player1 = address(0x121);        
        vm.startPrank(player1);    
        CoinToss toss = new CoinToss(CoinToss.GameInitialization({
            side: true // Player 1 chooses heads
        }));
        vm.stopPrank();

        address player2 = address(0x123);
        vm.startPrank(player2);
        toss.joinGame();
        vm.stopPrank();

        // Attempt to toss coin from a different player
        vm.expectRevert("Only players can toss the coin");
        vm.prank(address(0x456)); // Mock a different player
        toss.tossCoin();
    }
}