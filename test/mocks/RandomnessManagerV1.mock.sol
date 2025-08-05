// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {IRandomnessManager} from "../../src/randomness/IRandomnessManager.sol";
import {RandomnessRequest} from "../../src/randomness/RandomnessManagerV1.sol";

contract RandomnessManagerV1Mock is IRandomnessManager {

    uint256 private requestIdCounter;

    mapping (uint256 => RandomnessRequest) requests;
    /**
     * Requests random words from the VRF Coordinator.
     * @param numWords The number of random words to request.
     * @return requestId The ID of the request.
     * @dev This function can only be called by an account with the RANDOMNESS_AGENT_ROLE.
     */
    function requestRandomWords(
        uint16 numWords
    ) external override returns (uint256 requestId) {
        requestId = ++requestIdCounter;
        requests[requestId] = RandomnessRequest({
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
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal {
        requests[requestId].fulfilled = true;
        requests[requestId].randomWords = randomWords;
        emit RandomnessFulfilled(requestId);
    }

    /**
     * Gets the random words for a given request ID.
     * @param requestId The ID of the request.
     * @return randomWords The array of random words for the request.
     * @dev This function can only be called by an account with the RANDOMNESS_AGENT_ROLE.
     * It checks if the request exists and has been fulfilled before returning the random words.
     */
    function getRandomWords(
        uint256 requestId
    ) external view returns (uint256[] memory) {
        return requests[requestId].randomWords;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return interfaceId == type(IRandomnessManager).interfaceId;
    }

    function isRequestFulfilled(
        uint256 requestId
    ) external view override returns (bool fulfilled) {
        return requests[requestId].fulfilled;
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {        
        fulfillRandomWords(requestId, randomWords);
    }
}