// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RandomnessManagerV1, RandomnessManagerV1Initialization} from "../src/randomness/RandomnessManagerV1.sol";
import {VRFCoordinatorV2PlusMock} from "./mocks/VRFCoordinatorV2Plus.mock.sol";
import {LinkTokenMock} from "./mocks/LinkToken.mock.sol";

contract RandomnessManagerV1Test is Test {
    RandomnessManagerV1 randomnessManager;
    VRFCoordinatorV2PlusMock mockCoordinator;
    LinkTokenMock mockLink;
    address admin = address(this);
    address agent = address(0xBEEF);
    address consumer = address(0xCAFE);

    function setUp() public {
        mockCoordinator = new VRFCoordinatorV2PlusMock();
        mockLink = new LinkTokenMock();

        RandomnessManagerV1Initialization memory init = RandomnessManagerV1Initialization({
            vrfCoordinatorV2Plus: address(mockCoordinator),
            linkTokenAddress: address(mockLink),
            keyHash: bytes32("keyhash")
        });

        randomnessManager = new RandomnessManagerV1(init);
        randomnessManager.grantRole(randomnessManager.RANDOMNESS_AGENT_ROLE(), agent);
    }

    function test_requestRandomWords_and_getRandomWords() public {
        vm.startPrank(agent);
        uint256 reqId = randomnessManager.requestRandomWords(2);
        // Should revert if not fulfilled
        vm.expectRevert("Request not fulfilled");
        randomnessManager.getRandomWords(reqId);

        // Simulate fulfillment
        uint256[] memory words = new uint256[](2);
        words[0] = 42;
        words[1] = 99;
        vm.stopPrank();

        // Call fulfillRandomWords as contract (simulate VRF callback)
        vm.prank(address(mockCoordinator));
        randomnessManager.rawFulfillRandomWords(reqId, words);

        vm.startPrank(agent);
        uint256[] memory out = randomnessManager.getRandomWords(reqId);
        assertEq(out.length, 2);
        assertEq(out[0], 42);
        assertEq(out[1], 99);
        vm.stopPrank();
    }

    function test_requestRandomWords_reverts_for_non_agent() public {
        vm.expectRevert();
        randomnessManager.requestRandomWords(1);
    }

    function test_requestRandomWords_reverts_for_zero_words() public {
        vm.startPrank(agent);
        vm.expectRevert("Number of words must be greater than 0");
        randomnessManager.requestRandomWords(0);
        vm.stopPrank();
    }

    function test_getRandomWords_reverts_for_non_agent() public {
        vm.startPrank(agent);
        uint256 reqId = randomnessManager.requestRandomWords(1);
        vm.stopPrank();
        vm.expectRevert();
        randomnessManager.getRandomWords(reqId);
    }

    function test_fundSubscriptionWithLink() public {
        mockLink.mint(admin, 100 ether);
        mockLink.mint(address(randomnessManager), 0);
        mockLink.approve(address(randomnessManager), 100 ether);
        randomnessManager.fundSubscriptionWithLink(1 ether);
        // Check event, balances, etc. as needed
    }

    function test_fundSubscriptionWithNative() public {
        randomnessManager.setNativePayment(true);
        randomnessManager.fundSubscriptionWithNative{value: 1 ether}(1 ether);
        assertTrue(mockCoordinator.fundedWithNative());
    }

    function test_fundSubscription_dispatches_correctly() public {
        randomnessManager.setNativePayment(true);
        randomnessManager.fundSubscription{value: 1 ether}(1 ether);

        randomnessManager.setNativePayment(false);
        mockLink.mint(admin, 100 ether);
        mockLink.approve(address(randomnessManager), 100 ether);
        randomnessManager.fundSubscription(1 ether);
    }

    function test_addConsumer_and_removeConsumer() public {
        randomnessManager.addConsumer(consumer);
        assertEq(mockCoordinator.lastConsumer(), consumer);

        randomnessManager.removeConsumer(consumer);
        assertEq(mockCoordinator.lastRemovedConsumer(), consumer);
    }

    function test_createSubscription_and_cancelSubscription() public {
        // Cancel current subscription
        randomnessManager.cancelSubscription(admin);
        assertEq(mockCoordinator.lastCancelledTo(), admin);

        // Now create a new one
        randomnessManager.createSubscription();
        assertTrue(randomnessManager.subscriptionId() != 0);
    }

    function test_setters() public {
        randomnessManager.setKeyHash(bytes32("newkey"));
        assertEq(randomnessManager.keyHash(), bytes32("newkey"));

        randomnessManager.setCallbackGasLimit(123456);
        assertEq(randomnessManager.callbackGasLimit(), 123456);

        randomnessManager.setRequestConfirmations(7);
        assertEq(randomnessManager.requestConfirmations(), 7);

        randomnessManager.setNativePayment(false);
        assertEq(randomnessManager.nativePayment(), false);

        randomnessManager.setLinkTokenContract(address(0xDEAD));
        assertEq(address(randomnessManager.LINK()), address(0xDEAD));
    }

    function test_withdraw() public {
        mockLink.mint(address(randomnessManager), 10 ether);
        randomnessManager.withdraw(1 ether, admin);
        assertEq(mockLink.balances(admin), 1 ether);
    }

    function test_onlyAdmin_functions_revert_for_non_admin() public {
        vm.startPrank(address(0xBAD));
        vm.expectRevert();
        randomnessManager.fundSubscriptionWithLink(1 ether);
        vm.expectRevert();
        randomnessManager.fundSubscriptionWithNative(1 ether);
        vm.expectRevert();
        randomnessManager.fundSubscription(1 ether);
        vm.expectRevert();
        randomnessManager.addConsumer(consumer);
        vm.expectRevert();
        randomnessManager.removeConsumer(consumer);
        vm.expectRevert();
        randomnessManager.createSubscription();
        vm.expectRevert();
        randomnessManager.cancelSubscription(admin);
        vm.expectRevert();
        randomnessManager.setKeyHash(bytes32("fail"));
        vm.expectRevert();
        randomnessManager.setCallbackGasLimit(1);
        vm.expectRevert();
        randomnessManager.setRequestConfirmations(1);
        vm.expectRevert();
        randomnessManager.setNativePayment(true);
        vm.expectRevert();
        randomnessManager.setLinkTokenContract(address(0));
        vm.expectRevert();
        randomnessManager.withdraw(1 ether, admin);
        vm.stopPrank();
    }
}
