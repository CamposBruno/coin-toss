// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IRandomnessManager, IERC165} from "./IRandomnessManager.sol";

// Struct to hold the initialization parameters for the RandomnessManager
struct RandomnessManagerV1Initialization {
    address vrfCoordinatorV2Plus;
    address linkTokenAddress;
    bytes32 keyHash;
}

// struct to hold the request details
struct RandomnessRequest {
    uint256 requestId;
    uint256[] randomWords;
    bool fulfilled;
    bool exists;
}

/**
 * @title RandomnessManagerV1Cloneable
 * @author Bruno Campos <https://github.com/CamposBruno>
 * @notice A cloneable version of RandomnessManagerV1 that can be deployed via factory clones.
 * This version uses an initializer function instead of a constructor to support the clone pattern.
 * 
 * It manages randomness requests using Chainlink VRF V2 Plus and allows for requesting random words,
 * managing subscriptions, and handling randomness requests with AccessControl for roles and permissions.
 */
contract RandomnessManagerV1Cloneable is IRandomnessManager, VRFConsumerBaseV2Plus, AccessControl {
    bytes32 public constant RANDOMNESS_AGENT_ROLE = keccak256("RANDOMNESS_AGENT_ROLE");

    // Link token contract address
    LinkTokenInterface public LINK;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    bytes32 public keyHash;

    // A reasonable default is 100000, but this value could be different on other networks.
    uint32 public callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // The subscription ID for the VRF Coordinator
    uint256 public subscriptionId = 0;

    // Set to true if you want to pay with native currency, false for LINK
    bool public nativePayment = true;

    // mapping to store randomness requests
    mapping(uint256 => RandomnessRequest) private randomnessRequests;

    // Track if this clone has been initialized
    bool private _initialized;

    // Error for already initialized
    error AlreadyInitialized();
    error NotInitialized();

    // modifier to check if the subscription is active/inactive
    modifier subscriptionActive() {
        require(subscriptionId != 0, "Subscription not set");
        _;
    }

    modifier subscriptionInactive() {
        require(subscriptionId == 0, "Subscription already exists");
        _;
    }

    modifier onlyInitialized() {
        if (!_initialized) revert NotInitialized();
        _;
    }

    // Manager events for subscription management
    event SubscriptionCreated(uint256 indexed subscriptionId);
    event SubscriptionFunded(uint256 indexed subscriptionId, address token, uint256 amount);
    event SubscriptionConsumerAdded(uint256 indexed subscriptionId, address consumer);
    event SubscriptionConsumerRemoved(uint256 indexed subscriptionId, address consumer);
    event SubscriptionCancelled(uint256 indexed subscriptionId);

    /**
     * @dev Constructor for cloneable pattern - minimal initialization
     * We need to pass a valid address to VRFConsumerBaseV2Plus constructor
     * This will be overridden in initialize()
     */
    constructor() VRFConsumerBaseV2Plus(address(1)) {
        // Empty constructor for cloneable pattern
        // Using address(1) as a placeholder to avoid zero address validation
    }

    /**
     * @dev Initializes the cloned RandomnessManager contract
     * @param initialization The initialization parameters
     * @param admin The address that will have admin privileges
     */
    function initialize(
        RandomnessManagerV1Initialization memory initialization,
        address admin
    ) external {
        if (_initialized) revert AlreadyInitialized();
        
        require(initialization.vrfCoordinatorV2Plus != address(0), "Invalid VRF coordinator");
        require(initialization.linkTokenAddress != address(0), "Invalid LINK token");
        require(initialization.keyHash != bytes32(0), "Invalid key hash");
        require(admin != address(0), "Invalid admin address");

        // Set the VRF coordinator (this is a bit of a workaround since we can't call the parent constructor)
        s_vrfCoordinator = IVRFCoordinatorV2Plus(initialization.vrfCoordinatorV2Plus);
        
        LINK = LinkTokenInterface(initialization.linkTokenAddress);
        keyHash = initialization.keyHash;

        // Create a new subscription
        subscriptionId = s_vrfCoordinator.createSubscription();

        // add the contract as a consumer of the subscription
        s_vrfCoordinator.addConsumer(subscriptionId, address(this));

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        
        _initialized = true;

        emit SubscriptionCreated(subscriptionId);
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
        onlyInitialized
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
     */
    function getRandomWords(uint256 requestId)
        external
        view
        onlyRole(RANDOMNESS_AGENT_ROLE)
        onlyInitialized
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
    function isRequestFulfilled(uint256 requestId) public view override onlyInitialized returns (bool fulfilled) {
        return randomnessRequests[requestId].fulfilled;
    }

    /**
     * Funds the subscription with LINK tokens
     * @param amount The amount of LINK tokens to fund the subscription with.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function fundSubscription(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) onlyInitialized subscriptionActive {
        require(amount > 0, "Amount must be greater than 0");
        bool success = LINK.transferAndCall(address(s_vrfCoordinator), amount, abi.encode(subscriptionId));
        require(success, "Failed to fund subscription");
        emit SubscriptionFunded(subscriptionId, address(LINK), amount);
    }

    /**
     * Funds the subscription with native currency (ETH)
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function fundSubscriptionNative() external payable onlyRole(DEFAULT_ADMIN_ROLE) onlyInitialized subscriptionActive {
        require(msg.value > 0, "Must send ETH to fund subscription");
        s_vrfCoordinator.fundSubscriptionWithNative{value: msg.value}(subscriptionId);
        emit SubscriptionFunded(subscriptionId, address(0), msg.value);
    }

    /**
     * Adds a consumer to the subscription
     * @param consumer The address of the consumer to add to the subscription.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function addConsumer(address consumer) external onlyRole(DEFAULT_ADMIN_ROLE) onlyInitialized subscriptionActive {
        require(consumer != address(0), "Consumer address cannot be zero");
        s_vrfCoordinator.addConsumer(subscriptionId, consumer);
        emit SubscriptionConsumerAdded(subscriptionId, consumer);
    }

    /**
     * Removes a consumer from the subscription
     * @param consumer The address of the consumer to remove from the subscription.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function removeConsumer(address consumer) external onlyRole(DEFAULT_ADMIN_ROLE) onlyInitialized subscriptionActive {
        require(consumer != address(0), "Consumer address cannot be zero");
        s_vrfCoordinator.removeConsumer(subscriptionId, consumer);
        emit SubscriptionConsumerRemoved(subscriptionId, consumer);
    }

    /**
     * Cancels the subscription and transfers remaining funds to the specified address
     * @param to The address to transfer the remaining funds to.
     * @dev This function can only be called by an account with the DEFAULT_ADMIN_ROLE.
     */
    function cancelSubscription(address to) external onlyRole(DEFAULT_ADMIN_ROLE) onlyInitialized subscriptionActive {
        require(to != address(0), "Recipient address cannot be zero");
        s_vrfCoordinator.cancelSubscription(subscriptionId, to);
        subscriptionId = 0; // Reset subscription ID after cancellation
        emit SubscriptionCancelled(subscriptionId);
    }

    /**
     * @dev This function returns the subscription details.
     * @return balance The LINK balance of the subscription.
     * @return nativeBalance The native balance of the subscription.
     * @return reqCount The number of requests made by the subscription.
     * @return subOwner The owner of the subscription.
     * @return consumers The list of consumers for the subscription.
     */
    function getSubscriptionDetails()
        external
        view
        onlyInitialized
        subscriptionActive
        returns (uint96 balance, uint96 nativeBalance, uint64 reqCount, address subOwner, address[] memory consumers)
    {
        return s_vrfCoordinator.getSubscription(subscriptionId);
    }

    // Utility functions
    function isInitialized() external view returns (bool) {
        return _initialized;
    }

    function getSubscriptionId() external view onlyInitialized returns (uint256) {
        return subscriptionId;
    }

    // Required by IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, IERC165) returns (bool) {
        return interfaceId == type(IRandomnessManager).interfaceId || super.supportsInterface(interfaceId);
    }
}