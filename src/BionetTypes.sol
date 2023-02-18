// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

/// @dev Common models used across the protocol
contract BionetTypes {
    /// Recognized states
    enum ExchangeState {
        Committed,
        Revoked,
        Canceled,
        Redeemed,
        Completed,
        Disputed
    }

    /// TODO:
    enum DisputeState {
        Retracted,
        Resolved
    }

    /// Information collected by an Offer
    struct Offer {
        uint256 id;
        address seller;
        uint256 price;
        uint256 quantityAvailable;
        address assetToken;
        uint256 assetTokenId;
        string metadataUri;
        bool voided;
    }

    /// Exchange information
    struct Exchange {
        uint256 id;
        uint256 offerId;
        address buyer;
        uint256 redeemBy;
        uint256 disputeBy;
        uint256 finalizedDate;
        ExchangeState state;
    }
}
