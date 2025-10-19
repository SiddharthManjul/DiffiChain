// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IStealthAddressRegistry
/// @notice ERC-5564 compliant stealth address registry
/// @dev Enables privacy-preserving payments using stealth addresses
interface IStealthAddressRegistry {
    /// @notice Emitted when a user publishes their stealth meta-address
    /// @param registrant The address registering the stealth meta-address
    /// @param spendingPubKey The public key for spending stealth payments
    /// @param viewingPubKey The public key for scanning stealth payments
    event StealthMetaAddressSet(
        address indexed registrant,
        bytes spendingPubKey,
        bytes viewingPubKey
    );

    /// @notice Emitted when a payment is announced to a stealth address
    /// @param ephemeralPubKey The ephemeral public key for this payment
    /// @param stealthAddress The generated stealth address (one-time use)
    /// @param caller The address that announced the payment
    /// @param metadata Additional encrypted metadata for the recipient
    event Announcement(
        bytes ephemeralPubKey,
        address indexed stealthAddress,
        address indexed caller,
        bytes metadata
    );

    /// @notice Register a stealth meta-address for receiving confidential payments
    /// @param spendingPubKey The spending public key (for deriving private keys)
    /// @param viewingPubKey The viewing public key (for scanning announcements)
    function registerStealthMetaAddress(
        bytes calldata spendingPubKey,
        bytes calldata viewingPubKey
    ) external;

    /// @notice Announce a payment to a stealth address
    /// @param ephemeralPubKey The ephemeral public key used for this payment
    /// @param stealthAddress The derived stealth address
    /// @param metadata Encrypted metadata (e.g., amount, note commitment)
    function announce(
        bytes calldata ephemeralPubKey,
        address stealthAddress,
        bytes calldata metadata
    ) external;

    /// @notice Get the stealth meta-address for a registrant
    /// @param registrant The address to query
    /// @return spendingPubKey The spending public key
    /// @return viewingPubKey The viewing public key
    function getStealthMetaAddress(address registrant)
        external
        view
        returns (bytes memory spendingPubKey, bytes memory viewingPubKey);

    /// @notice Check if an address has registered a stealth meta-address
    /// @param registrant The address to check
    /// @return registered True if registered
    function isRegistered(address registrant) external view returns (bool registered);
}
