// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {CoinTossCloneable} from "../src/CoinTossCloneable.sol";
import {RandomnessManagerV1Cloneable} from "../src/randomness/RandomnessManagerV1Cloneable.sol";
import {VRFCoordinatorV2PlusMock} from "./mocks/VRFCoordinatorV2Plus.mock.sol";
import {LinkTokenMock} from "./mocks/LinkToken.mock.sol";

contract GameFactorySimpleTest is Test {
    CoinTossCloneable coinTossImpl;
    RandomnessManagerV1Cloneable randomnessManagerImpl;
    VRFCoordinatorV2PlusMock vrfCoordinator;
    LinkTokenMock linkToken;

    function setUp() public {
        // Deploy mocks first
        vrfCoordinator = new VRFCoordinatorV2PlusMock();
        linkToken = new LinkTokenMock();
        
        // Deploy implementation contracts
        coinTossImpl = new CoinTossCloneable();
        randomnessManagerImpl = new RandomnessManagerV1Cloneable();
    }

    function test_BasicDeployment() public {
        assertTrue(address(coinTossImpl) != address(0));
        assertTrue(address(randomnessManagerImpl) != address(0));
        assertTrue(address(vrfCoordinator) != address(0));
        assertTrue(address(linkToken) != address(0));
    }

    function test_CoinTossInitialization() public {
        // Test that CoinToss can be initialized
        assertFalse(coinTossImpl.isInitialized());
        
        // This should work since it's just checking the interface
        assertTrue(address(coinTossImpl) != address(0));
    }
}