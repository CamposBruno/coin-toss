// SPDX-License-Identifier: SEE LICENSE IN LICENSE
// An example of a consumer contract that also owns and manages the subscription
pragma solidity 0.8.24;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IRandomnessManager, IERC165} from "./IRandomnessManager.sol";

// Struct to hold the initialization parameters for the RandomnessManager
// This struct is used to initialize the contract with the necessary parameters
// such as the VRF Coordinator address, LINK token address, key hash, etc.
// It is used in the constructor to set up the contract correctly.
// This allows for a cleaner and more organized way to pass multiple parameters
// during contract deployment, making the code more maintainable and readable.
// It also helps to avoid long constructor signatures and makes it easier to
// add or remove parameters in the future without changing the constructor signature.
struct RandomnessManagerV1Initialization {
    address vrfCoordinatorV2Plus;
    address linkTokenAddress;
    bytes32 keyHash;
}

// struct to hold the request details
// This struct is used to store the details of each randomness request
// It includes the request ID, the random words generated, and flags for fulfillment and existence
// The request ID is used to uniquely identify each request, while the random words are the results
// fulfilled indicates whether the request has been fulfilled, and exists indicates whether the request is valid
// This struct is essential for managing the state of randomness requests in the contract
struct RandomnessRequest {
    uint256 requestId;
    uint256[] randomWords;
    bool fulfilled;
    bool exists;
}

/**
 * @title RandomnessManagerV1
 * @author Bruno Campos <https://github.com/CamposBruno>
 * @notice This is a contract that manages randomness requests using Chainlink VRF V2 Plus.
 * It allows for requesting random words, managing subscriptions, and handling randomness requests.
 * It uses AccessControl to manage roles and permissions.
 * It implements the IRandomnessManager interface.
 * If you are using this contract on testnet, request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
 */
contract RandomnessManagerV1 is IRandomnessManager, VRFConsumerBaseV2Plus, AccessControl {
    bytes32 public constant RANDOMNESS_AGENT_ROLE = keccak256("RANDOMNESS_AGENT_ROLE");

    // Link token contract address
    LinkTokenInterface public LINK;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/vrf/v2-5/supported-networks
    // bytes32 public keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    bytes32 public keyHash;

    // A reasonable default is 100000, but this value could be different
    // on other networks.
    uint32 public callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // The subscription ID for the VRF Coordinator
    uint256 public subscriptionId = 0;

    // Set to true if you want to pay with native currency, false for LINK
    bool public nativePayment = true;

    // mapping to store randomness requests
    mapping(uint256 => RandomnessRequest) private randomnessRequests;

    // modifier to check if the subscription is active/inactive
    modifier subscriptionActive() {
        require(subscriptionId != 0, "Subscription not set");
        _;
    }

    modifier subscriptionInactive() {
        require(subscriptionId == 0, "Subscription already exists");
        _;
    }

    // Manager events for subscription management
    // These events are emitted when a subscription is created, funded, consumer added/removed, or cancelled.
    // They provide a way to track subscription changes and actions taken on the contract.
    // They can be used for logging and monitoring purposes, allowing users to see when subscriptions are
    // created, funded, or modified.
    // This is useful for debugging and auditing the contract's behavior.
    // The events are indexed to allow for efficient filtering and searching in event logs.
    event SubscriptionCreated(uint256 indexed subscriptionId);
    event SubscriptionFunded(uint256 indexed subscriptionId, address token, uint256 amount);
    event SubscriptionConsumerAdded(uint256 indexed subscriptionId, address consumer);
    event SubscriptionConsumerRemoved(uint256 indexed subscriptionId, address consumer);
    event SubscriptionCancelled(uint256 indexed subscriptionId);

    /*
     * Constructor that initializes the VRFConsumerBaseV2Plus with the VRF Coordinator address.
     * @param initialization The initialization parameters for the RandomnessManager.
     */
    constructor(RandomnessManagerV1Initialization memory initialization)
        VRFConsumerBaseV2Plus(initialization.vrfCoordinatorV2Plus)
    {
        LINK = LinkTokenInterface(initialization.linkTokenAddress);
        keyHash = initialization.keyHash;

        // Create a new subscription
        subscriptionId = s_vrfCoordinator.createSubscription();

        // add the contract as a consumer of the subscription
        s_vrfCoordinator.addConsumer(subscriptionId, address(this));

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * Requests random words from the VRF Coordinator.
     * @param numWords The number of random words to request.
     * @return requestId The ID of the request.
     * @dev This function can only be called by an account with the RANDOMNESS_AGENT_ROLE.
     */
    function requestRandomWords(uint16 numWords)
        external
        override
        onlyRole(RANDOMNESS_AGENT_ROLE)
        subscriptionActive
        returns (uint256 requestId)
    {
        require(numWords > 0, "Number of words must be greater than 0");

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: nativePayment}))
            })
        );

        randomnessRequests[requestId] = RandomnessRequest({
            requestId: requestId,
            randomWords: new uint256[](0), // Initialize with an empty array
            fulfilled: false,
            exists: true
        });

        emit RandomnessRequested(requestId, numWords);
    }

    /**
     * Callback function that is called by the VRF Coordinator when the random words are fulfilled.
     * @param requestId The ID of the request.
     * @param randomWords The array of random words returned by the VRF Coordinator.
     * @dev This function is called by the VRF Coordinator and should not be called directly.
     * It checks if the request exists and has not been fulfilled before updating the request state.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        require(randomnessRequests[requestId].exists, "Request does not exist");
        require(randomnessRequests[requestId].fulfilled == false, "Request already fulfilled");
        randomnessRequests[requestId].randomWords = randomWords;
        randomnessRequests[requestId].fulfilled = true;
        emit RandomnessFulfilled(requestId);
    }

    /**
     * Gets the random words for a given request ID.
     * @param requestId The ID of the request.
     * @return randomWords The array of random words for the request.
     * @dev This function can only be called by an account with the RANDOMNESS_AGENT_ROLE.
     * It checks if the request exists and has been fulfilled before returning the random words.
     */
    function getRandomWords(uint256 requestId)
        external
        view
        onlyRole(RANDOMNESS_AGENT_ROLE)
        returns (uint256[] memory randomWords)
    {
        require(randomnessRequests[requestId].exists, "Request does not exist");
        require(randomnessRequests[requestId].fulfilled, "Request not fulfilled");
        return randomnessRequests[requestId].randomWords;
    }

    /**
     * @dev This function returns fulfillment status.
     * @param requestId The ID of the request to check.
     * @return fulfilled A boolean indicating whether the request has been fulfilled.
     */
    function isRequestFulfilled(uint256 requestId) public view override returns (bool fulfilled) {
        return randomnessRequests[requestId].fulfilled;
    }

    /**
     * Funds the subscription with LINK tokens
     * @param amount The amount of LINK tokens to fund the subscription with.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It transfers the specified amount of LINK tokens or native currency to the VRF Coordinator.
     * IT assumes that the sender has approved this contract to spend their LINK tokens.
     */
    function fundSubscriptionWithLink(uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) subscriptionActive {
        // transfer LINK tokens from the sender to this contract
        // assuming the sender has approved this contract to spend their LINK tokens
        LINK.transferFrom(msg.sender, address(this), amount);

        // transfer LINK tokens from this contract to the VRF Coordinator
        LINK.transferAndCall(address(s_vrfCoordinator), amount, abi.encode(subscriptionId));
        emit SubscriptionFunded(subscriptionId, address(LINK), amount);
    }

    /**
     * Funds the subscription with native currency (e.g., ETH).
     * @param amount The amount of native currency to fund the subscription with.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function fundSubscriptionWithNative(uint256 amount)
        public
        payable
        onlyRole(DEFAULT_ADMIN_ROLE)
        subscriptionActive
    {
        require(msg.value == amount, "Incorrect native currency amount sent");

        s_vrfCoordinator.fundSubscriptionWithNative{value: amount}(subscriptionId);

        emit SubscriptionFunded(subscriptionId, address(0), amount);
    }

    /**
     * Funds the subscription with either LINK tokens or native currency.
     * @param amount The amount to fund the subscription with.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It checks the nativePayment flag to determine whether to fund with LINK or native currency.
     */
    function fundSubscription(uint256 amount) external payable onlyRole(DEFAULT_ADMIN_ROLE) subscriptionActive {
        if (nativePayment) {
            fundSubscriptionWithNative(amount);
        } else {
            fundSubscriptionWithLink(amount);
        }
    }

    /**
     * Adds a consumer contract to the subscription.
     * @param consumerAddress The address of the consumer contract to add.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It adds the specified consumer contract to the subscription.
     */
    function addConsumer(address consumerAddress) external onlyRole(DEFAULT_ADMIN_ROLE) subscriptionActive {
        // Add a consumer contract to the subscription.
        s_vrfCoordinator.addConsumer(subscriptionId, consumerAddress);
        emit SubscriptionConsumerAdded(subscriptionId, consumerAddress);
    }

    /**
     * Removes a consumer contract from the subscription.
     * @param consumerAddress The address of the consumer contract to remove.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It removes the specified consumer contract from the subscription.
     */
    function removeConsumer(address consumerAddress) external onlyRole(DEFAULT_ADMIN_ROLE) subscriptionActive {
        // Remove a consumer contract from the subscription.
        s_vrfCoordinator.removeConsumer(subscriptionId, consumerAddress);
        emit SubscriptionConsumerRemoved(subscriptionId, consumerAddress);
    }

    /**
     * Creates a new subscription.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It creates a new subscription and sets the subscriptionId to the newly created subscription ID.
     */
    function createSubscription() external onlyRole(DEFAULT_ADMIN_ROLE) subscriptionInactive {
        require(subscriptionId == 0, "Subscription already exists");
        // Create a new subscription and set the subscriptionId
        subscriptionId = s_vrfCoordinator.createSubscription();
        emit SubscriptionCreated(subscriptionId);
    }

    /**
     * Cancels the subscription and sends the remaining LINK to a specified wallet address.
     * @param receivingWallet The address to send the remaining LINK to.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It cancels the subscription and sets the subscriptionId to 0.
     */
    function cancelSubscription(address receivingWallet) external onlyRole(DEFAULT_ADMIN_ROLE) subscriptionActive {
        require(receivingWallet != address(0), "Receiving wallet cannot be zero address");
        // Cancel the subscription and send the remaining LINK to a wallet address.
        s_vrfCoordinator.cancelSubscription(subscriptionId, receivingWallet);
        subscriptionId = 0;
        emit SubscriptionCancelled(subscriptionId);
    }

    /**
     * set keyHash for the VRF Coordinator.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It updates the keyHash used for the VRF Coordinator.
     * @param newKeyHash The new key hash to set.
     */
    function setKeyHash(bytes32 newKeyHash) external onlyRole(DEFAULT_ADMIN_ROLE) {
        keyHash = newKeyHash;
    }

    /**
     * set callbackGasLimit for the VRF Coordinator.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It updates the callback gas limit used for the VRF Coordinator.
     * @param newCallbackGasLimit The new callback gas limit to set.
     */
    function setCallbackGasLimit(uint32 newCallbackGasLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        callbackGasLimit = newCallbackGasLimit;
    }

    /**
     * set requestConfirmations for the VRF Coordinator.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It updates the request confirmations used for the VRF Coordinator.
     * @param newRequestConfirmations The new request confirmations to set.
     */
    function setRequestConfirmations(uint16 newRequestConfirmations) external onlyRole(DEFAULT_ADMIN_ROLE) {
        requestConfirmations = newRequestConfirmations;
    }

    /**
     * set nativePayment for the VRF Coordinator.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It updates whether the subscription should be paid in native currency or LINK.
     * @param newNativePayment The new native payment setting to set.
     */
    function setNativePayment(bool newNativePayment) external onlyRole(DEFAULT_ADMIN_ROLE) {
        nativePayment = newNativePayment;
    }

    /**
     * setLinkTokenContract for the VRF Coordinator.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     * It updates the LINK token contract address used for the VRF Coordinator.
     * @param newLinkTokenContract The new LINK token contract address to set.
     */
    function setLinkTokenContract(address newLinkTokenContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        LINK = LinkTokenInterface(newLinkTokenContract);
    }

    /**
     * Withdraws LINK tokens from the contract to a specified address.
     * @param amount The amount of LINK tokens to withdraw.
     * @param to The address to send the withdrawn LINK tokens to.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function withdraw(uint256 amount, address to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        LINK.transfer(to, amount);
    }

    /**
     * @dev This function checks if the contract supports the specified interface.
     * It overrides the supportsInterface function from the IERC165 interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, IERC165)
        returns (bool)
    {
        return interfaceId == type(IRandomnessManager).interfaceId || super.supportsInterface(interfaceId);
    }
}
