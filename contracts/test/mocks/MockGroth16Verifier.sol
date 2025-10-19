// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IGroth16Verifier} from "../../src/interfaces/IGroth16Verifier.sol";

/// @title MockGroth16Verifier
/// @notice Mock verifier for testing (always returns true)
/// @dev Replace with actual generated verifiers from snarkjs in production
contract MockGroth16Verifier is IGroth16Verifier {
    /// @notice Always returns true for testing
    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[] calldata
    ) external pure override returns (bool) {
        return true;
    }
}

/// @title MockFailingVerifier
/// @notice Mock verifier that always fails (for negative testing)
contract MockFailingVerifier is IGroth16Verifier {
    /// @notice Always returns false
    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[] calldata
    ) external pure override returns (bool) {
        return false;
    }
}
