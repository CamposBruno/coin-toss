// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {GameFactory} from "../src/GameFactory.sol";
import {CoinTossCloneable} from "../src/CoinTossCloneable.sol";
import {RandomnessManagerV1Cloneable} from "../src/randomness/RandomnessManagerV1Cloneable.sol";
import {VRFCoordinatorV2PlusMock} from "./mocks/VRFCoordinatorV2Plus.mock.sol";
import {LinkTokenMock} from "./mocks/LinkToken.mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract GameFactoryTest is Test {
    GameFactory factory;
    GameFactory factoryImpl;
    CoinTossCloneable coinTossImpl;
    RandomnessManagerV1Cloneable randomnessManagerImpl;
    VRFCoordinatorV2PlusMock vrfCoordinator;
    LinkTokenMock linkToken;
    
    address admin = address(0x123);
    address user = address(0x456);
    address configUpdater = address(0x789);
    
    bytes32 keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint256 defaultMaxStaleness = 1 hours;
    
    event GameDeployed(
        address indexed gameAddress,
        address indexed player1,
        bool side,
        address randomnessManager,
        uint256 maxStaleness,
        bytes32 salt
    );
    
    event VRFConfigurationUpdated(
        address indexed vrfCoordinatorV2Plus,
        address indexed linkTokenAddress,
        bytes32 keyHash
    );

    function setUp() public {
        // Deploy mock dependencies
        vrfCoordinator = new VRFCoordinatorV2PlusMock();
        linkToken = new LinkTokenMock();
        
        // Deploy implementation contracts
        coinTossImpl = new CoinTossCloneable();
        randomnessManagerImpl = new RandomnessManagerV1Cloneable();
        
        // Deploy factory implementation
        factoryImpl = new GameFactory();
        
        // Deploy factory proxy with initialization
        bytes memory initData = abi.encodeWithSelector(
            GameFactory.initialize.selector,
            address(vrfCoordinator),
            address(linkToken),
            keyHash,
            address(coinTossImpl),
            address(randomnessManagerImpl),
            defaultMaxStaleness,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(factoryImpl), initData);
        factory = GameFactory(address(proxy));
    }

    // ========== INITIALIZATION TESTS ==========
    
    function test_Initialize() public {
        // Check that the factory was initialized correctly
        (address vrfCoord, address linkAddr, bytes32 kHash) = factory.getVRFConfiguration();
        assertEq(vrfCoord, address(vrfCoordinator));
        assertEq(linkAddr, address(linkToken));
        assertEq(kHash, keyHash);
        assertEq(factory.getDefaultMaxStaleness(), defaultMaxStaleness);
        assertEq(factory.getCoinTossImplementation(), address(coinTossImpl));
        assertEq(factory.getRandomnessManagerImplementation(), address(randomnessManagerImpl));
        
        // Check admin roles
        assertTrue(factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.FACTORY_ADMIN_ROLE(), admin));
        assertTrue(factory.hasRole(factory.CONFIG_UPDATER_ROLE(), admin));
    }
    
    function test_InitializeWithInvalidParams() public {
        GameFactory newFactoryImpl = new GameFactory();
        
        // Test invalid VRF coordinator
        vm.expectRevert("Invalid VRF coordinator");
        new ERC1967Proxy(address(newFactoryImpl), abi.encodeWithSelector(
            GameFactory.initialize.selector,
            address(0),
            address(linkToken),
            keyHash,
            address(coinTossImpl),
            address(randomnessManagerImpl),
            defaultMaxStaleness,
            admin
        ));
        
        // Test invalid LINK token
        vm.expectRevert("Invalid LINK token");
        new ERC1967Proxy(address(newFactoryImpl), abi.encodeWithSelector(
            GameFactory.initialize.selector,
            address(vrfCoordinator),
            address(0),
            keyHash,
            address(coinTossImpl),
            address(randomnessManagerImpl),
            defaultMaxStaleness,
            admin
        ));
        
        // Test invalid key hash
        vm.expectRevert("Invalid key hash");
        new ERC1967Proxy(address(newFactoryImpl), abi.encodeWithSelector(
            GameFactory.initialize.selector,
            address(vrfCoordinator),
            address(linkToken),
            bytes32(0),
            address(coinTossImpl),
            address(randomnessManagerImpl),
            defaultMaxStaleness,
            admin
        ));
    }

    // ========== GAME CREATION TESTS ==========
    
    function test_CreateGame() public {
        vm.startPrank(user);
        
        bytes32 salt = keccak256("test_game_1");
        bool side = true; // heads
        uint256 maxStaleness = 2 hours;
        
        // Don't check exact event data since addresses are computed dynamically
        (address gameAddress, address randomnessManager) = factory.createGame(side, maxStaleness, salt);
        
        vm.stopPrank();
        
        // Verify game was created correctly
        assertTrue(gameAddress != address(0));
        assertTrue(randomnessManager != address(0));
        assertTrue(factory.isDeployedGame(gameAddress));
        assertEq(factory.getDeployedGamesCount(), 1);
        assertEq(factory.getDeployedGame(0), gameAddress);
        assertEq(factory.getRandomnessManager(salt), randomnessManager);
        
        // Check game initialization
        CoinTossCloneable game = CoinTossCloneable(gameAddress);
        assertTrue(game.isInitialized());
        
        CoinTossCloneable.PlayerDetails memory player1 = game.getPlayerDetails(true);
        assertEq(player1.player, user);
        assertEq(player1.side, side);
        
        // Check randomness manager initialization
        RandomnessManagerV1Cloneable rm = RandomnessManagerV1Cloneable(randomnessManager);
        assertTrue(rm.isInitialized());
        assertTrue(rm.hasRole(rm.RANDOMNESS_AGENT_ROLE(), gameAddress));
    }
    
    function test_CreateGameWithDefaultMaxStaleness() public {
        vm.startPrank(user);
        
        bytes32 salt = keccak256("test_game_default");
        bool side = false; // tails
        
        (address gameAddress,) = factory.createGame(side, 0, salt); // 0 means use default
        
        CoinTossCloneable.Game memory gameDetails = CoinTossCloneable(gameAddress).getGameDetails();
        assertEq(gameDetails.maxStaleness, defaultMaxStaleness);
        
        vm.stopPrank();
    }
    
    function test_CreateGameDeterministicAddress() public {
        bytes32 salt = keccak256("deterministic_test");
        bool side = true;
        uint256 maxStaleness = 2 hours;
        
        // Predict the address for the user who will create the game
        address predictedAddress = factory.predictGameAddressForSender(side, maxStaleness, salt, user);
        
        vm.prank(user);
        (address actualAddress,) = factory.createGame(side, maxStaleness, salt);
        
        assertEq(predictedAddress, actualAddress);
    }
    
    function test_CreateGameWithSameSaltReusesRandomnessManager() public {
        bytes32 salt = keccak256("same_salt");
        
        vm.startPrank(user);
        (,address rm1) = factory.createGame(true, 0, salt);
        vm.stopPrank();
        
        vm.startPrank(address(0x999));
        (,address rm2) = factory.createGame(false, 0, salt);
        vm.stopPrank();
        
        // Should reuse the same randomness manager
        assertEq(rm1, rm2);
    }
    
    function test_CreateGameWithInvalidStaleness() public {
        vm.startPrank(user);
        
        bytes32 salt = keccak256("invalid_staleness");
        
        // Test staleness too low
        vm.expectRevert("Max staleness too low");
        factory.createGame(true, 30 seconds, salt); // Below MIN_GAME_STALENESS
        
        // Test staleness too high
        vm.expectRevert("Max staleness too high");
        factory.createGame(true, 2 days, salt); // Above MAX_GAME_STALENESS
        
        vm.stopPrank();
    }

    // ========== CONFIGURATION UPDATE TESTS ==========
    
    function test_UpdateVRFConfiguration() public {
        vm.startPrank(admin);
        
        address newVrfCoordinator = address(0x111);
        address newLinkToken = address(0x222);
        bytes32 newKeyHash = keccak256("new_key_hash");
        
        vm.expectEmit(true, true, false, true);
        emit VRFConfigurationUpdated(newVrfCoordinator, newLinkToken, newKeyHash);
        
        factory.updateVRFConfiguration(newVrfCoordinator, newLinkToken, newKeyHash);
        
        (address vrfCoord, address linkAddr, bytes32 kHash) = factory.getVRFConfiguration();
        assertEq(vrfCoord, newVrfCoordinator);
        assertEq(linkAddr, newLinkToken);
        assertEq(kHash, newKeyHash);
        
        vm.stopPrank();
    }
    
    function test_UpdateVRFConfigurationWithInvalidParams() public {
        vm.startPrank(admin);
        
        // Test invalid VRF coordinator
        vm.expectRevert("Invalid VRF coordinator");
        factory.updateVRFConfiguration(address(0), address(linkToken), keyHash);
        
        // Test invalid LINK token
        vm.expectRevert("Invalid LINK token");
        factory.updateVRFConfiguration(address(vrfCoordinator), address(0), keyHash);
        
        // Test invalid key hash
        vm.expectRevert("Invalid key hash");
        factory.updateVRFConfiguration(address(vrfCoordinator), address(linkToken), bytes32(0));
        
        vm.stopPrank();
    }
    
    function test_UpdateDefaultMaxStaleness() public {
        vm.startPrank(admin);
        
        uint256 newMaxStaleness = 2 hours;
        factory.updateDefaultMaxStaleness(newMaxStaleness);
        
        assertEq(factory.getDefaultMaxStaleness(), newMaxStaleness);
        
        vm.stopPrank();
    }
    
    function test_UpdateCoinTossImplementation() public {
        vm.startPrank(admin);
        
        CoinTossCloneable newImpl = new CoinTossCloneable();
        factory.updateCoinTossImplementation(address(newImpl));
        
        assertEq(factory.getCoinTossImplementation(), address(newImpl));
        
        vm.stopPrank();
    }

    // ========== ACCESS CONTROL TESTS ==========
    
    function test_UpdateVRFConfigurationUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        factory.updateVRFConfiguration(address(0x111), address(0x222), keccak256("test"));
    }
    
    function test_UpdateDefaultMaxStalenessUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        factory.updateDefaultMaxStaleness(2 hours);
    }
    
    function test_UpdateCoinTossImplementationUnauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        factory.updateCoinTossImplementation(address(0x111));
    }
    
    function test_ConfigUpdaterRole() public {
        // Grant CONFIG_UPDATER_ROLE to configUpdater
        vm.startPrank(admin);
        factory.grantRole(factory.CONFIG_UPDATER_ROLE(), configUpdater);
        vm.stopPrank();
        
        // Should be able to update VRF configuration
        vm.prank(configUpdater);
        factory.updateVRFConfiguration(address(0x111), address(0x222), keccak256("test"));
        
        // Should be able to update max staleness
        vm.prank(configUpdater);
        factory.updateDefaultMaxStaleness(2 hours);
        
        // Should NOT be able to update implementation (requires FACTORY_ADMIN_ROLE)
        vm.prank(configUpdater);
        vm.expectRevert();
        factory.updateCoinTossImplementation(address(0x111));
    }

    // ========== UPGRADEABILITY TESTS ==========
    
    function test_UpgradeFactory() public {
        // Deploy new implementation
        GameFactory newImpl = new GameFactory();
        
        vm.prank(admin);
        factory.upgradeToAndCall(address(newImpl), "");
        
        // Factory should still work after upgrade
        (address vrfCoord,,) = factory.getVRFConfiguration();
        assertEq(vrfCoord, address(vrfCoordinator));
    }
    
    function test_UpgradeFactoryUnauthorized() public {
        GameFactory newImpl = new GameFactory();
        
        vm.prank(user);
        vm.expectRevert();
        factory.upgradeToAndCall(address(newImpl), "");
    }

    // ========== VIEW FUNCTION TESTS ==========
    
    function test_GetDeployedGamesCount() public {
        assertEq(factory.getDeployedGamesCount(), 0);
        
        vm.startPrank(user);
        factory.createGame(true, 0, keccak256("game1"));
        assertEq(factory.getDeployedGamesCount(), 1);
        
        factory.createGame(false, 0, keccak256("game2"));
        assertEq(factory.getDeployedGamesCount(), 2);
        vm.stopPrank();
    }
    
    function test_GetDeployedGameOutOfBounds() public {
        vm.expectRevert("Index out of bounds");
        factory.getDeployedGame(0);
        
        vm.prank(user);
        factory.createGame(true, 0, keccak256("game1"));
        
        vm.expectRevert("Index out of bounds");
        factory.getDeployedGame(1);
    }

    // ========== INTEGRATION TESTS ==========
    
    function test_FullGameWorkflow() public {
        // Create a game
        vm.startPrank(user);
        bytes32 salt = keccak256("full_workflow");
        (address gameAddress, address randomnessManager) = factory.createGame(true, 2 hours, salt);
        vm.stopPrank();
        
        // Wait for minimum staleness and join game
        vm.warp(block.timestamp + CoinTossCloneable(gameAddress).MIN_GAME_STALENESS());
        
        address player2 = address(0x888);
        vm.prank(player2);
        CoinTossCloneable(gameAddress).joinGame();
        
        // Verify the game state
        CoinTossCloneable.Game memory gameDetails = CoinTossCloneable(gameAddress).getGameDetails();
        assertEq(gameDetails.player1.player, user);
        assertEq(gameDetails.player2.player, player2);
        assertTrue(gameDetails.player1.side != gameDetails.player2.side); // Opposite sides
        assertFalse(gameDetails.isCompleted);
        
        // Verify randomness manager has the game as agent
        RandomnessManagerV1Cloneable rm = RandomnessManagerV1Cloneable(randomnessManager);
        assertTrue(rm.hasRole(rm.RANDOMNESS_AGENT_ROLE(), gameAddress));
    }
    
    function test_MultipleGamesWithDifferentSalts() public {
        vm.startPrank(user);
        
        // Create multiple games with different salts
        (address game1,) = factory.createGame(true, 0, keccak256("game1"));
        (address game2,) = factory.createGame(false, 0, keccak256("game2"));
        (address game3,) = factory.createGame(true, 0, keccak256("game3"));
        
        vm.stopPrank();
        
        // Verify all games are tracked
        assertEq(factory.getDeployedGamesCount(), 3);
        assertTrue(factory.isDeployedGame(game1));
        assertTrue(factory.isDeployedGame(game2));
        assertTrue(factory.isDeployedGame(game3));
        
        // Verify games have different addresses
        assertTrue(game1 != game2);
        assertTrue(game2 != game3);
        assertTrue(game1 != game3);
    }
}