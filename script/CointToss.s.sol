// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {CoinToss} from "../src/CoinToss.sol";

contract CoinTossScript is Script {
    CoinToss public coinToss;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        coinToss = new CoinToss(
            CoinToss.GameInitialization({
                side: true,
                randomnessManager: address(0x456), // Mock address for randomness manager
                maxStaleness: 1 hours
            })
        );

        vm.stopBroadcast();
    }
}
