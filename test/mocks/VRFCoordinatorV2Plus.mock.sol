// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RandomnessManagerV1, RandomnessManagerV1Initialization} from "../../src/randomness/RandomnessManagerV1.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

// --- Mock contracts (implement minimal interfaces for testing) ---
contract VRFCoordinatorV2PlusMock {
    uint256 public nextSubId = 1;
    uint256 public lastFundedAmount;
    address public lastConsumer;
    address public lastRemovedConsumer;
    address public lastCancelledTo;
    uint256 public lastCancelledSubId;
    bool public fundedWithNative;

    function createSubscription() external returns (uint256) {
        return nextSubId++;
    }

    function addConsumer(uint256, address consumer) external {
        lastConsumer = consumer;
    }

    function removeConsumer(uint256, address consumer) external {
        lastRemovedConsumer = consumer;
    }

    function cancelSubscription(uint256 subId, address to) external {
        lastCancelledSubId = subId;
        lastCancelledTo = to;
    }

    function fundSubscriptionWithNative(uint256) external payable {
        fundedWithNative = true;
        lastFundedAmount = msg.value;
    }

    function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata req) external pure returns (uint256) {
        (req);
        return uint256(keccak256("mockRequest"));
    }
}
