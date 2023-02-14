// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

contract BionetTypes {
    enum ExchangeState {
        Committed,
        Revoked,
        Canceled,
        Redeemed,
        Completed,
        Disputed
    }

    enum DisputeState {
        Retracted,
        Resolved
    }

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
