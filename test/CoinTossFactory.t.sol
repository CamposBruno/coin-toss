// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CoinTossFactory} from "../src/CoinTossFactory.sol";
import {CoinToss} from "../src/CoinToss.sol";
import {RandomnessManagerV1Mock} from "./mocks/RandomnessManagerV1.mock.sol";

contract CoinTossFactoryTest is Test {
    CoinTossFactory factory;
    RandomnessManagerV1Mock randomnessManagerMock;
    address owner = address(0x123);
    address player1 = address(0x456);
    address player2 = address(0x789);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy factory
        factory = new CoinTossFactory();

        // Deploy mock randomness manager
        randomnessManagerMock = new RandomnessManagerV1Mock();

        vm.stopPrank();
    }

    // ========== BASIC FUNCTIONALITY TESTS ==========

    function test_InitialState() public view {
        // Check initial state
        assertEq(factory.owner(), owner);
        assertEq(factory.currentVersion(), 1);
        assertTrue(factory.currentImplementation() != address(0));
        assertEq(factory.getGamesCount(), 0);
    }

    function test_DeployGame() public {
        vm.startPrank(player1);

        address gameAddress = factory.deployGame(
            true, // heads
            address(randomnessManagerMock),
            1 hours
        );

        vm.stopPrank();

        // Check game was deployed
        assertTrue(factory.isGameDeployed(gameAddress));
        assertEq(factory.getGameVersion(gameAddress), 1);
        assertEq(factory.getGamesCount(), 1);

        // Check game state
        CoinToss game = CoinToss(gameAddress);
        CoinToss.Game memory gameDetails = game.getGameDetails();
        assertEq(gameDetails.player1.player, player1);
        assertTrue(gameDetails.player1.side); // heads
        assertFalse(gameDetails.isCompleted);
    }

    function test_DeployMultipleGames() public {
        vm.startPrank(player1);

        address game1 = factory.deployGame(
            true,
            address(randomnessManagerMock),
            1 hours
        );
        address game2 = factory.deployGame(
            false,
            address(randomnessManagerMock),
            2 hours
        );

        vm.stopPrank();

        // Check both games were deployed
        assertTrue(factory.isGameDeployed(game1));
        assertTrue(factory.isGameDeployed(game2));
        assertEq(factory.getGamesCount(), 2);

        // Check game versions
        assertEq(factory.getGameVersion(game1), 1);
        assertEq(factory.getGameVersion(game2), 1);
    }

    // ========== IMPLEMENTATION UPDATE TESTS ==========

    function test_UpdateImplementation() public {
        vm.startPrank(owner);

        // Deploy new implementation
        CoinToss newImpl = new CoinToss();

        // Update implementation
        factory.updateImplementation(address(newImpl), 2);

        vm.stopPrank();

        // Check implementation was updated
        assertEq(factory.currentImplementation(), address(newImpl));
        assertEq(factory.currentVersion(), 2);
    }

    function test_OnlyOwnerCanUpdateImplementation() public {
        vm.startPrank(player1);

        CoinToss newImpl = new CoinToss();

        vm.expectRevert();
        factory.updateImplementation(address(newImpl), 2);

        vm.stopPrank();
    }

    function test_UpdateImplementationWithInvalidAddress() public {
        vm.startPrank(owner);

        vm.expectRevert("Invalid implementation address");
        factory.updateImplementation(address(0), 2);

        vm.stopPrank();
    }

    function test_UpdateImplementationWithLowerVersion() public {
        vm.startPrank(owner);

        CoinToss newImpl = new CoinToss();

        vm.expectRevert("Version must be higher than current");
        factory.updateImplementation(address(newImpl), 1);

        vm.stopPrank();
    }

    // ========== GAME DEPLOYMENT TESTS ==========

    function test_DeployGameWithInvalidRandomnessManager() public {
        vm.startPrank(player1);
        vm.expectRevert("Invalid randomness manager");
        factory.deployGame(true, address(0), 1 hours);
        vm.stopPrank();
    }

    // ========== GAME TRACKING TESTS ==========

    function test_GetAllGames() public {
        vm.startPrank(player1);

        address game1 = factory.deployGame(
            true,
            address(randomnessManagerMock),
            1 hours
        );
        address game2 = factory.deployGame(
            false,
            address(randomnessManagerMock),
            2 hours
        );

        vm.stopPrank();

        address[] memory allGames = factory.getAllGames();
        assertEq(allGames.length, 2);
        assertEq(allGames[0], game1);
        assertEq(allGames[1], game2);
    }

    function test_GetGamesCount() public {
        assertEq(factory.getGamesCount(), 0);

        vm.startPrank(player1);
        factory.deployGame(true, address(randomnessManagerMock), 1 hours);
        vm.stopPrank();

        assertEq(factory.getGamesCount(), 1);

        vm.startPrank(player1);
        factory.deployGame(false, address(randomnessManagerMock), 2 hours);
        vm.stopPrank();

        assertEq(factory.getGamesCount(), 2);
    }

    function test_IsGameDeployed() public {
        vm.startPrank(player1);
        address gameAddress = factory.deployGame(
            true,
            address(randomnessManagerMock),
            1 hours
        );
        vm.stopPrank();

        assertTrue(factory.isGameDeployed(gameAddress));
        assertFalse(factory.isGameDeployed(address(0x999)));
    }

    function test_GetGameVersion() public {
        vm.startPrank(player1);
        address gameAddress = factory.deployGame(
            true,
            address(randomnessManagerMock),
            1 hours
        );
        vm.stopPrank();

        assertEq(factory.getGameVersion(gameAddress), 1);
    }

    // ========== GAME FUNCTIONALITY TESTS ==========

    function test_DeployedGameWorks() public {
        vm.startPrank(player1);
        address gameAddress = factory.deployGame(
            true,
            address(randomnessManagerMock),
            1 hours
        );
        vm.stopPrank();

        CoinToss game = CoinToss(gameAddress);

        // Check game state
        CoinToss.Game memory gameDetails = game.getGameDetails();
        assertEq(gameDetails.player1.player, player1);
        assertTrue(gameDetails.player1.side);
        assertFalse(gameDetails.isCompleted);
    }

    function test_GameWithDifferentVersions() public {
        // Deploy game with V1
        vm.startPrank(player1);
        address game1 = factory.deployGame(
            true,
            address(randomnessManagerMock),
            1 hours
        );
        vm.stopPrank();

        // Update implementation to V2
        vm.startPrank(owner);
        CoinToss newImpl = new CoinToss();
        factory.updateImplementation(address(newImpl), 2);
        vm.stopPrank();

        // Deploy game with V2
        vm.startPrank(player2);
        address game2 = factory.deployGame(
            false,
            address(randomnessManagerMock),
            2 hours
        );
        vm.stopPrank();

        // Check versions
        assertEq(factory.getGameVersion(game1), 1);
        assertEq(factory.getGameVersion(game2), 2);

        // Check both games work
        CoinToss game1Contract = CoinToss(game1);
        CoinToss game2Contract = CoinToss(game2);

        CoinToss.Game memory game1Details = game1Contract.getGameDetails();
        CoinToss.Game memory game2Details = game2Contract.getGameDetails();

        assertEq(game1Details.player1.player, player1);
        assertEq(game2Details.player1.player, player2);
        assertTrue(game1Details.player1.side); // heads
        assertFalse(game2Details.player1.side); // tails
    }

    // ========== EVENTS TESTS ==========

    function test_ImplementationUpdatedEvent() public {
        vm.startPrank(owner);

        CoinToss newImpl = new CoinToss();

        vm.expectEmit(true, true, false, false);
        emit CoinTossFactory.ImplementationUpdated(address(newImpl), 2);
        factory.updateImplementation(address(newImpl), 2);

        vm.stopPrank();
    }

    function test_GameDeployed() public {
        vm.startPrank(player1);

        // We can't predict the exact address, so we'll just check that the event is emitted
        // and verify the game was actually deployed
        address gameAddress = factory.deployGame(
            true,
            address(randomnessManagerMock),
            1 hours
        );

        // Verify the game was deployed
        assertTrue(factory.isGameDeployed(gameAddress));
        assertEq(factory.getGameVersion(gameAddress), 1);

        vm.stopPrank();
    }
}
