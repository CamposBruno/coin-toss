// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {GameFactory} from "../src/GameFactory.sol";
import {CoinTossCloneable} from "../src/CoinTossCloneable.sol";
import {RandomnessManagerV1Cloneable} from "../src/randomness/RandomnessManagerV1Cloneable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title GameFactoryScript
 * @dev Deployment script for the complete GameFactory system
 * 
 * This script deploys:
 * 1. CoinTossCloneable implementation contract
 * 2. RandomnessManagerV1Cloneable implementation contract  
 * 3. GameFactory implementation contract
 * 4. GameFactory proxy with initialization
 * 
 * Environment variables needed:
 * - VRF_COORDINATOR_V2_PLUS: The Chainlink VRF V2 Plus coordinator address
 * - LINK_TOKEN: The LINK token contract address
 * - KEY_HASH: The VRF key hash for the specific network
 * - ADMIN_ADDRESS: The address that will have admin privileges
 * - DEFAULT_MAX_STALENESS: Default maximum staleness for games (in seconds)
 */
contract GameFactoryScript is Script {
    // Network configurations
    struct NetworkConfig {
        address vrfCoordinatorV2Plus;
        address linkToken;
        bytes32 keyHash;
        uint256 defaultMaxStaleness;
    }
    
    // Mainnet configuration
    function getMainnetConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            vrfCoordinatorV2Plus: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a, // Mainnet VRF Coordinator
            linkToken: 0x514910771AF9Ca656af840dff83E8264EcF986CA, // Mainnet LINK
            keyHash: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef, // Mainnet 200 gwei key hash
            defaultMaxStaleness: 1 days
        });
    }
    
    // Sepolia testnet configuration
    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            vrfCoordinatorV2Plus: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // Sepolia VRF Coordinator
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // Sepolia LINK
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // Sepolia 30 gwei key hash
            defaultMaxStaleness: 1 hours
        });
    }
    
    // Local/test configuration (using environment variables or defaults)
    function getLocalConfig() internal view returns (NetworkConfig memory) {
        address vrfCoordinator = vm.envOr("VRF_COORDINATOR_V2_PLUS", address(0x1234567890123456789012345678901234567890));
        address linkToken = vm.envOr("LINK_TOKEN", address(0x0987654321098765432109876543210987654321));
        bytes32 keyHash = vm.envOr("KEY_HASH", bytes32(0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae));
        uint256 defaultMaxStaleness = vm.envOr("DEFAULT_MAX_STALENESS", uint256(1 hours));
        
        return NetworkConfig({
            vrfCoordinatorV2Plus: vrfCoordinator,
            linkToken: linkToken,
            keyHash: keyHash,
            defaultMaxStaleness: defaultMaxStaleness
        });
    }
    
    function getNetworkConfig() internal view returns (NetworkConfig memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 1) {
            return getMainnetConfig();
        } else if (chainId == 11155111) {
            return getSepoliaConfig();
        } else {
            return getLocalConfig();
        }
    }
    
    function run() public {
        NetworkConfig memory config = getNetworkConfig();
        
        // Get admin address from environment or use deployer
        address admin = vm.envOr("ADMIN_ADDRESS", msg.sender);
        
        console.log("Deploying GameFactory system...");
        console.log("Chain ID:", block.chainid);
        console.log("Admin address:", admin);
        console.log("VRF Coordinator:", config.vrfCoordinatorV2Plus);
        console.log("LINK Token:", config.linkToken);
        console.log("Key Hash:", vm.toString(config.keyHash));
        console.log("Default Max Staleness:", config.defaultMaxStaleness);
        
        vm.startBroadcast();
        
        // 1. Deploy implementation contracts
        console.log("\n1. Deploying implementation contracts...");
        
        CoinTossCloneable coinTossImpl = new CoinTossCloneable();
        console.log("CoinTossCloneable implementation deployed at:", address(coinTossImpl));
        
        RandomnessManagerV1Cloneable randomnessManagerImpl = new RandomnessManagerV1Cloneable();
        console.log("RandomnessManagerV1Cloneable implementation deployed at:", address(randomnessManagerImpl));
        
        GameFactory factoryImpl = new GameFactory();
        console.log("GameFactory implementation deployed at:", address(factoryImpl));
        
        // 2. Deploy proxy with initialization
        console.log("\n2. Deploying GameFactory proxy...");
        
        bytes memory initData = abi.encodeWithSelector(
            GameFactory.initialize.selector,
            config.vrfCoordinatorV2Plus,
            config.linkToken,
            config.keyHash,
            address(coinTossImpl),
            address(randomnessManagerImpl),
            config.defaultMaxStaleness,
            admin
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(factoryImpl), initData);
        GameFactory factory = GameFactory(address(proxy));
        
        console.log("GameFactory proxy deployed at:", address(factory));
        
        // 3. Verify deployment
        console.log("\n3. Verifying deployment...");
        
        (address vrfCoord, address linkAddr, bytes32 kHash) = factory.getVRFConfiguration();
        console.log("VRF Configuration verified:");
        console.log("  VRF Coordinator:", vrfCoord);
        console.log("  LINK Token:", linkAddr);
        console.log("  Key Hash:", vm.toString(kHash));
        
        console.log("Default Max Staleness:", factory.getDefaultMaxStaleness());
        console.log("CoinToss Implementation:", factory.getCoinTossImplementation());
        console.log("RandomnessManager Implementation:", factory.getRandomnessManagerImplementation());
        
        // Check admin roles
        bool hasDefaultAdmin = factory.hasRole(factory.DEFAULT_ADMIN_ROLE(), admin);
        bool hasFactoryAdmin = factory.hasRole(factory.FACTORY_ADMIN_ROLE(), admin);
        bool hasConfigUpdater = factory.hasRole(factory.CONFIG_UPDATER_ROLE(), admin);
        
        console.log("Admin roles verified:");
        console.log("  DEFAULT_ADMIN_ROLE:", hasDefaultAdmin);
        console.log("  FACTORY_ADMIN_ROLE:", hasFactoryAdmin);
        console.log("  CONFIG_UPDATER_ROLE:", hasConfigUpdater);
        
        require(hasDefaultAdmin && hasFactoryAdmin && hasConfigUpdater, "Admin roles not properly assigned");
        
        vm.stopBroadcast();
        
        // 4. Output deployment summary
        console.log("\n=== DEPLOYMENT SUMMARY ===");
        console.log("GameFactory Proxy:", address(factory));
        console.log("GameFactory Implementation:", address(factoryImpl));
        console.log("CoinTossCloneable Implementation:", address(coinTossImpl));
        console.log("RandomnessManagerV1Cloneable Implementation:", address(randomnessManagerImpl));
        console.log("Admin Address:", admin);
        console.log("=============================");
        
        // 5. Example usage
        console.log("\n=== EXAMPLE USAGE ===");
        console.log("To create a new game:");
        console.log("factory.createGame(true, 2 hours, keccak256('my_game_salt'))");
        console.log("====================");
    }
}

/**
 * @title GameFactoryUpgradeScript
 * @dev Script for upgrading the GameFactory implementation
 */
contract GameFactoryUpgradeScript is Script {
    function run() public {
        address factoryProxyAddress = vm.envAddress("FACTORY_PROXY_ADDRESS");
        
        console.log("Upgrading GameFactory at:", factoryProxyAddress);
        
        vm.startBroadcast();
        
        // Deploy new implementation
        GameFactory newImpl = new GameFactory();
        console.log("New implementation deployed at:", address(newImpl));
        
        // Upgrade the proxy
        GameFactory factory = GameFactory(factoryProxyAddress);
        factory.upgradeToAndCall(address(newImpl), "");
        
        console.log("GameFactory upgraded successfully");
        
        vm.stopBroadcast();
    }
}

/**
 * @title GameFactoryConfigScript
 * @dev Script for updating GameFactory configuration
 */
contract GameFactoryConfigScript is Script {
    function run() public {
        address factoryProxyAddress = vm.envAddress("FACTORY_PROXY_ADDRESS");
        
        console.log("Updating GameFactory configuration at:", factoryProxyAddress);
        
        vm.startBroadcast();
        
        GameFactory factory = GameFactory(factoryProxyAddress);
        
        // Example: Update VRF configuration
        address newVrfCoordinator = vm.envOr("NEW_VRF_COORDINATOR", address(0));
        address newLinkToken = vm.envOr("NEW_LINK_TOKEN", address(0));
        bytes32 newKeyHash = vm.envOr("NEW_KEY_HASH", bytes32(0));
        
        if (newVrfCoordinator != address(0) && newLinkToken != address(0) && newKeyHash != bytes32(0)) {
            factory.updateVRFConfiguration(newVrfCoordinator, newLinkToken, newKeyHash);
            console.log("VRF configuration updated");
        }
        
        // Example: Update default max staleness
        uint256 newMaxStaleness = vm.envOr("NEW_MAX_STALENESS", uint256(0));
        if (newMaxStaleness > 0) {
            factory.updateDefaultMaxStaleness(newMaxStaleness);
            console.log("Default max staleness updated to:", newMaxStaleness);
        }
        
        vm.stopBroadcast();
    }
}