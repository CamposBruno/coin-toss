// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {CoinToss} from "./CoinToss.sol";

/**
 * @title CoinTossFactory
 * @author Bruno Campos <bhncampos@gmail.com>
 * @dev Simple factory contract for deploying CoinToss games.
 * Players can deploy new games using the current implementation.
 * Owner can update the implementation.
 */
contract CoinTossFactory is Ownable {
    using Clones for address;

    // Events
    event ImplementationUpdated(
        address indexed newImplementation,
        uint256 indexed version
    );
    event GameDeployed(
        address indexed gameAddress,
        address indexed player1,
        uint256 indexed version
    );

    // State variables
    address public currentImplementation;
    uint256 public currentVersion;
    mapping(address => uint256) public gameVersions;
    mapping(address => bool) public deployedGames;
    address[] public allGames;

    constructor() Ownable(msg.sender) {
        // Deploy the initial implementation
        CoinToss initialImpl = new CoinToss();
        _setImplementation(address(initialImpl), 1);
    }

    /**
     * @dev Update the implementation (only owner)
     * @param newImplementation Address of the new implementation
     * @param version Version number for the new implementation
     */
    function updateImplementation(
        address newImplementation,
        uint256 version
    ) external onlyOwner {
        require(
            newImplementation != address(0),
            "Invalid implementation address"
        );
        require(
            version > currentVersion,
            "Version must be higher than current"
        );
        require(
            newImplementation.code.length > 0,
            "Implementation must be a contract"
        );

        _setImplementation(newImplementation, version);
    }

    /**
     * @dev Internal function to set implementation
     */
    function _setImplementation(
        address implementation,
        uint256 version
    ) internal {
        currentImplementation = implementation;
        currentVersion = version;
        emit ImplementationUpdated(implementation, version);
    }

    /**
     * @dev Deploy a new CoinToss game
     * @param side Player 1's choice (true for heads, false for tails)
     * @param randomnessManager Address of the randomness manager
     * @param maxStaleness Maximum time before game becomes stale
     * @return gameAddress Address of the deployed game
     */
    function deployGame(
        bool side,
        address randomnessManager,
        uint256 maxStaleness
    ) external returns (address gameAddress) {
        require(currentImplementation != address(0), "No implementation set");
        require(randomnessManager != address(0), "Invalid randomness manager");

        // Deploy minimal proxy
        gameAddress = currentImplementation.clone();

        // Initialize the game
        CoinToss(gameAddress).initialize(
            CoinToss.GameInitialization({
                player1: msg.sender,
                side: side,
                randomnessManager: randomnessManager,
                maxStaleness: maxStaleness
            })
        );

        // Record the game
        deployedGames[gameAddress] = true;
        gameVersions[gameAddress] = currentVersion;
        allGames.push(gameAddress);

        emit GameDeployed(gameAddress, msg.sender, currentVersion);
    }

    /**
     * @dev Get all deployed games
     */
    function getAllGames() external view returns (address[] memory) {
        return allGames;
    }

    /**
     * @dev Get games count
     */
    function getGamesCount() external view returns (uint256) {
        return allGames.length;
    }

    /**
     * @dev Check if a game is deployed by this factory
     */
    function isGameDeployed(address gameAddress) external view returns (bool) {
        return deployedGames[gameAddress];
    }

    /**
     * @dev Get the version of a specific game
     */
    function getGameVersion(
        address gameAddress
    ) external view returns (uint256) {
        return gameVersions[gameAddress];
    }
}
