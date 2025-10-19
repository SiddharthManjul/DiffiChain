// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStealthAddressRegistry} from "../interfaces/IStealthAddressRegistry.sol";

/// @title StealthAddressRegistry
/// @notice ERC-5564 compliant stealth address registry
/// @dev Enables privacy-preserving payments using one-time stealth addresses
contract StealthAddressRegistry is IStealthAddressRegistry {
    // ============ State Variables ============

    /// @notice Stealth meta-address data
    struct StealthMetaAddress {
        bytes spendingPubKey;  // Public key for deriving stealth addresses
        bytes viewingPubKey;   // Public key for scanning announcements
        bool registered;
    }

    /// @notice Mapping of address => stealth meta-address
    mapping(address => StealthMetaAddress) private stealthMetaAddresses;

    /// @notice Counter for total announcements (for indexing)
    uint256 public totalAnnouncements;

    // ============ Errors ============

    error NotRegistered();
    error AlreadyRegistered();
    error InvalidPublicKey();
    error InvalidStealthAddress();

    // ============ Registration ============

    /// @notice Register a stealth meta-address for receiving confidential payments
    /// @param spendingPubKey The spending public key (secp256k1 compressed: 33 bytes)
    /// @param viewingPubKey The viewing public key (secp256k1 compressed: 33 bytes)
    function registerStealthMetaAddress(
        bytes calldata spendingPubKey,
        bytes calldata viewingPubKey
    ) external override {
        // Validate public key lengths (compressed secp256k1: 33 bytes)
        if (spendingPubKey.length != 33 || viewingPubKey.length != 33) {
            revert InvalidPublicKey();
        }

        // Check not already registered (can update by re-registering)
        // Allow updates by not checking if registered

        // Store stealth meta-address
        stealthMetaAddresses[msg.sender] = StealthMetaAddress({
            spendingPubKey: spendingPubKey,
            viewingPubKey: viewingPubKey,
            registered: true
        });

        emit StealthMetaAddressSet(msg.sender, spendingPubKey, viewingPubKey);
    }

    // ============ Announcement ============

    /// @notice Announce a payment to a stealth address
    /// @param ephemeralPubKey The ephemeral public key for this payment (33 bytes)
    /// @param stealthAddress The derived stealth address (one-time use)
    /// @param metadata Encrypted metadata (e.g., note commitment, amount hint)
    /// @dev Anyone can announce a payment (typically called by sender)
    function announce(
        bytes calldata ephemeralPubKey,
        address stealthAddress,
        bytes calldata metadata
    ) external override {
        // Validate ephemeral public key
        if (ephemeralPubKey.length != 33) {
            revert InvalidPublicKey();
        }

        // Validate stealth address
        if (stealthAddress == address(0)) {
            revert InvalidStealthAddress();
        }

        // Increment counter
        totalAnnouncements++;

        // Emit announcement event (recipients scan these to find their payments)
        emit Announcement(ephemeralPubKey, stealthAddress, msg.sender, metadata);
    }

    // ============ View Functions ============

    /// @notice Get the stealth meta-address for a registrant
    /// @param registrant The address to query
    /// @return spendingPubKey The spending public key
    /// @return viewingPubKey The viewing public key
    function getStealthMetaAddress(address registrant)
        external
        view
        override
        returns (bytes memory spendingPubKey, bytes memory viewingPubKey)
    {
        StealthMetaAddress storage metaAddr = stealthMetaAddresses[registrant];

        if (!metaAddr.registered) {
            revert NotRegistered();
        }

        return (metaAddr.spendingPubKey, metaAddr.viewingPubKey);
    }

    /// @notice Check if an address has registered a stealth meta-address
    /// @param registrant The address to check
    /// @return registered True if registered
    function isRegistered(address registrant) external view override returns (bool registered) {
        return stealthMetaAddresses[registrant].registered;
    }

    /// @notice Get both registration status and keys in one call (gas efficient)
    /// @param registrant The address to query
    /// @return registered Whether the address is registered
    /// @return spendingPubKey The spending public key (empty if not registered)
    /// @return viewingPubKey The viewing public key (empty if not registered)
    function getStealthMetaAddressBatch(address registrant)
        external
        view
        returns (
            bool registered,
            bytes memory spendingPubKey,
            bytes memory viewingPubKey
        )
    {
        StealthMetaAddress storage metaAddr = stealthMetaAddresses[registrant];

        return (
            metaAddr.registered,
            metaAddr.spendingPubKey,
            metaAddr.viewingPubKey
        );
    }
}
