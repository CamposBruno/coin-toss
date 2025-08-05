// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IRandomnessManager
 * @dev Interface for the Randomness Manager contract.
 * This contract is responsible for managing randomness requests and subscriptions.
 */
interface IRandomnessManager is IERC165 {
    function requestRandomWords(uint16 numWords) external returns (uint256 requestId);
    function isRequestFulfilled(uint256 requestId) external view returns (bool fulfilled);
    function getRandomWords(uint256 requestId) external view returns (uint256[] memory randomWords);

    event RandomnessRequested(uint256 indexed requestId, uint16 numWords);
    event RandomnessFulfilled(uint256 indexed requestId);
}