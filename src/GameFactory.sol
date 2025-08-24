// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {CoinTossCloneable} from "./CoinTossCloneable.sol";
import {RandomnessManagerV1Cloneable} from "./randomness/RandomnessManagerV1Cloneable.sol";
import {RandomnessManagerV1Initialization} from "./randomness/RandomnessManagerV1Cloneable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title GameFactory
 * @author CamposBruno <bhncampos@gmail.com>
 * @dev A factory contract for deploying CoinToss games using create2 clones.
 * This contract manages global configuration for VRF settings and deploys new game instances
 * as minimal proxy clones. It's upgradeable using UUPS pattern and uses ERC-7201 namespaced storage.
 * 
 * Features:
 * - Deploy CoinToss games using create2 deterministic addresses
 * - Manage global VRF configuration (coordinator, LINK token, key hash)
 * - Upgradeable using UUPS proxy pattern
 * - ERC-7201 namespaced storage layout
 * - Role-based access control for configuration updates
 */
contract GameFactory is Initializable, UUPSUpgradeable, AccessControlUpgradeable, ReentrancyGuardUpgradeable {
    using Clones for address;

    // ERC-7201 namespace for storage layout
    /// @custom:storage-location erc7201:tossit.storage.GameFactory
    struct GameFactoryStorage {
        // Global VRF Configuration
        address vrfCoordinatorV2Plus;
        address linkTokenAddress;
        bytes32 keyHash;
        
        // Game Configuration
        address coinTossImplementation;
        address randomnessManagerImplementation;
        uint256 defaultMaxStaleness;
        
        // Game tracking
        mapping(address => bool) deployedGames;
        address[] gameList;
        
        // Randomness manager instances
        mapping(bytes32 => address) randomnessManagers; // salt => manager address
    }

    // keccak256(abi.encode(uint256(keccak256("tossit.storage.GameFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant GameFactoryStorageLocation = 0xa8b7d5c4e1f9e2b6a3d8f0c1b4e7a2d5c8f1b4e7a0d3f6c9e2b5a8d1abcd1234;

    function _getGameFactoryStorage() private pure returns (GameFactoryStorage storage $) {
        assembly {
            $.slot := GameFactoryStorageLocation
        }
    }

    // Role definitions
    bytes32 public constant FACTORY_ADMIN_ROLE = keccak256("FACTORY_ADMIN_ROLE");
    bytes32 public constant CONFIG_UPDATER_ROLE = keccak256("CONFIG_UPDATER_ROLE");

    // Events
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
    
    event DefaultMaxStalenessUpdated(uint256 oldValue, uint256 newValue);
    event ImplementationUpdated(address indexed oldImplementation, address indexed newImplementation);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the GameFactory contract
     * @param _vrfCoordinatorV2Plus The Chainlink VRF V2 Plus coordinator address
     * @param _linkTokenAddress The LINK token contract address
     * @param _keyHash The key hash for VRF requests
     * @param _coinTossImplementation The implementation contract address for CoinToss games
     * @param _randomnessManagerImplementation The implementation contract address for RandomnessManager
     * @param _defaultMaxStaleness Default maximum staleness for games
     * @param _admin The address that will have admin role
     */
    function initialize(
        address _vrfCoordinatorV2Plus,
        address _linkTokenAddress,
        bytes32 _keyHash,
        address _coinTossImplementation,
        address _randomnessManagerImplementation,
        uint256 _defaultMaxStaleness,
        address _admin
    ) public initializer {
        require(_vrfCoordinatorV2Plus != address(0), "Invalid VRF coordinator");
        require(_linkTokenAddress != address(0), "Invalid LINK token");
        require(_keyHash != bytes32(0), "Invalid key hash");
        require(_coinTossImplementation != address(0), "Invalid CoinToss implementation");
        require(_randomnessManagerImplementation != address(0), "Invalid RandomnessManager implementation");
        require(_admin != address(0), "Invalid admin address");
        require(_defaultMaxStaleness >= CoinTossCloneable(payable(_coinTossImplementation)).MIN_GAME_STALENESS(), "Invalid max staleness");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        GameFactoryStorage storage $ = _getGameFactoryStorage();
        
        $.vrfCoordinatorV2Plus = _vrfCoordinatorV2Plus;
        $.linkTokenAddress = _linkTokenAddress;
        $.keyHash = _keyHash;
        $.coinTossImplementation = _coinTossImplementation;
        $.randomnessManagerImplementation = _randomnessManagerImplementation;
        $.defaultMaxStaleness = _defaultMaxStaleness;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(FACTORY_ADMIN_ROLE, _admin);
        _grantRole(CONFIG_UPDATER_ROLE, _admin);
    }

    /**
     * @dev Creates a new CoinToss game with deterministic address using create2
     * @param _side The first player's choice (true for heads, false for tails)
     * @param _maxStaleness Maximum time before game expires (0 for default)
     * @param _salt A unique salt for deterministic address generation
     * @return gameAddress The address of the newly deployed game
     * @return randomnessManager The address of the randomness manager for this game
     */
    function createGame(
        bool _side,
        uint256 _maxStaleness,
        bytes32 _salt
    ) external nonReentrant returns (address gameAddress, address randomnessManager) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        
        uint256 maxStaleness = _maxStaleness == 0 ? $.defaultMaxStaleness : _maxStaleness;
        
        require(maxStaleness >= CoinTossCloneable(payable($.coinTossImplementation)).MIN_GAME_STALENESS(), "Max staleness too low");
        require(maxStaleness <= CoinTossCloneable(payable($.coinTossImplementation)).MAX_GAME_STALENESS(), "Max staleness too high");

        // Deploy or get existing randomness manager for this salt
        randomnessManager = _getOrCreateRandomnessManager(_salt);

        // Create the game initialization struct
        CoinTossCloneable.GameInitialization memory gameInit = CoinTossCloneable.GameInitialization({
            side: _side,
            randomnessManager: randomnessManager,
            maxStaleness: maxStaleness
        });

        // Deploy the game using create2
        gameAddress = _deployGame(gameInit, _salt);

        // Grant randomness agent role to the new game
        RandomnessManagerV1Cloneable(randomnessManager).grantRole(
            RandomnessManagerV1Cloneable(randomnessManager).RANDOMNESS_AGENT_ROLE(),
            gameAddress
        );

        // Track the deployed game
        $.deployedGames[gameAddress] = true;
        $.gameList.push(gameAddress);

        emit GameDeployed(gameAddress, msg.sender, _side, randomnessManager, maxStaleness, _salt);
    }

    /**
     * @dev Predicts the address of a game that would be deployed with given parameters
     * @param _side The first player's choice
     * @param _maxStaleness Maximum time before game expires (0 for default)
     * @param _salt A unique salt for deterministic address generation
     * @return The predicted address of the game
     */
    function predictGameAddress(
        bool _side,
        uint256 _maxStaleness,
        bytes32 _salt
    ) external view returns (address) {
        return predictGameAddressForSender(_side, _maxStaleness, _salt, msg.sender);
    }
    
    function predictGameAddressForSender(
        bool _side,
        uint256 _maxStaleness,
        bytes32 _salt,
        address _sender
    ) public view returns (address) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        
        uint256 maxStaleness = _maxStaleness == 0 ? $.defaultMaxStaleness : _maxStaleness;
        address randomnessManager = _predictRandomnessManagerAddress(_salt);
        
        CoinTossCloneable.GameInitialization memory gameInit = CoinTossCloneable.GameInitialization({
            side: _side,
            randomnessManager: randomnessManager,
            maxStaleness: maxStaleness
        });

        bytes memory initData = abi.encode(gameInit, _sender);
        bytes32 combinedSalt = keccak256(abi.encodePacked(_salt, initData));
        
        return $.coinTossImplementation.predictDeterministicAddress(combinedSalt);
    }

    /**
     * @dev Internal function to deploy a game using create2
     */
    function _deployGame(
        CoinTossCloneable.GameInitialization memory _gameInit,
        bytes32 _salt
    ) internal returns (address) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        
        bytes memory initData = abi.encode(_gameInit, msg.sender);
        bytes32 combinedSalt = keccak256(abi.encodePacked(_salt, initData));
        
        address gameAddress = $.coinTossImplementation.cloneDeterministic(combinedSalt);
        
        // Initialize the cloned contract
        CoinTossCloneable(gameAddress).initialize(_gameInit, msg.sender);
        
        return gameAddress;
    }

    /**
     * @dev Gets or creates a randomness manager instance for the given salt
     */
    function _getOrCreateRandomnessManager(bytes32 _salt) internal returns (address) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        
        if ($.randomnessManagers[_salt] != address(0)) {
            return $.randomnessManagers[_salt];
        }

        // Deploy new randomness manager
        RandomnessManagerV1Initialization memory rmInit = RandomnessManagerV1Initialization({
            vrfCoordinatorV2Plus: $.vrfCoordinatorV2Plus,
            linkTokenAddress: $.linkTokenAddress,
            keyHash: $.keyHash
        });

        bytes32 rmSalt = keccak256(abi.encodePacked("RandomnessManager", _salt));
        
        address randomnessManager = $.randomnessManagerImplementation.cloneDeterministic(rmSalt);
        
        // Initialize the cloned randomness manager
        RandomnessManagerV1Cloneable(randomnessManager).initialize(rmInit, address(this));
        
        $.randomnessManagers[_salt] = randomnessManager;

        return randomnessManager;
    }

    /**
     * @dev Predicts the address of a randomness manager for the given salt
     */
    function _predictRandomnessManagerAddress(bytes32 _salt) internal view returns (address) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        
        if ($.randomnessManagers[_salt] != address(0)) {
            return $.randomnessManagers[_salt];
        }

        bytes32 rmSalt = keccak256(abi.encodePacked("RandomnessManager", _salt));
        return $.randomnessManagerImplementation.predictDeterministicAddress(rmSalt);
    }

    /**
     * @dev Updates the VRF configuration
     * @param _vrfCoordinatorV2Plus New VRF coordinator address
     * @param _linkTokenAddress New LINK token address
     * @param _keyHash New key hash
     */
    function updateVRFConfiguration(
        address _vrfCoordinatorV2Plus,
        address _linkTokenAddress,
        bytes32 _keyHash
    ) external onlyRole(CONFIG_UPDATER_ROLE) {
        require(_vrfCoordinatorV2Plus != address(0), "Invalid VRF coordinator");
        require(_linkTokenAddress != address(0), "Invalid LINK token");
        require(_keyHash != bytes32(0), "Invalid key hash");

        GameFactoryStorage storage $ = _getGameFactoryStorage();
        
        $.vrfCoordinatorV2Plus = _vrfCoordinatorV2Plus;
        $.linkTokenAddress = _linkTokenAddress;
        $.keyHash = _keyHash;

        emit VRFConfigurationUpdated(_vrfCoordinatorV2Plus, _linkTokenAddress, _keyHash);
    }

    /**
     * @dev Updates the default maximum staleness for games
     */
    function updateDefaultMaxStaleness(uint256 _newMaxStaleness) external onlyRole(CONFIG_UPDATER_ROLE) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        
        require(_newMaxStaleness >= CoinTossCloneable(payable($.coinTossImplementation)).MIN_GAME_STALENESS(), "Max staleness too low");
        require(_newMaxStaleness <= CoinTossCloneable(payable($.coinTossImplementation)).MAX_GAME_STALENESS(), "Max staleness too high");

        uint256 oldValue = $.defaultMaxStaleness;
        $.defaultMaxStaleness = _newMaxStaleness;

        emit DefaultMaxStalenessUpdated(oldValue, _newMaxStaleness);
    }

    /**
     * @dev Updates the CoinToss implementation contract
     */
    function updateCoinTossImplementation(address _newImplementation) external onlyRole(FACTORY_ADMIN_ROLE) {
        require(_newImplementation != address(0), "Invalid implementation");
        
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        address oldImplementation = $.coinTossImplementation;
        $.coinTossImplementation = _newImplementation;

        emit ImplementationUpdated(oldImplementation, _newImplementation);
    }

    // View functions
    function getVRFConfiguration() external view returns (address, address, bytes32) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        return ($.vrfCoordinatorV2Plus, $.linkTokenAddress, $.keyHash);
    }

    function getDefaultMaxStaleness() external view returns (uint256) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        return $.defaultMaxStaleness;
    }

    function getCoinTossImplementation() external view returns (address) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        return $.coinTossImplementation;
    }

    function getRandomnessManagerImplementation() external view returns (address) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        return $.randomnessManagerImplementation;
    }

    function isDeployedGame(address _game) external view returns (bool) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        return $.deployedGames[_game];
    }

    function getDeployedGamesCount() external view returns (uint256) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        return $.gameList.length;
    }

    function getDeployedGame(uint256 _index) external view returns (address) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        require(_index < $.gameList.length, "Index out of bounds");
        return $.gameList[_index];
    }

    function getRandomnessManager(bytes32 _salt) external view returns (address) {
        GameFactoryStorage storage $ = _getGameFactoryStorage();
        return $.randomnessManagers[_salt];
    }

    /**
     * @dev Required by UUPSUpgradeable
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(FACTORY_ADMIN_ROLE) {}
}