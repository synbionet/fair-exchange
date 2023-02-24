// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

/// ...
abstract contract BionetExchangeStorage {
    enum State {
        Init,
        Expired,
        Committed,
        Revoked,
        Canceled,
        Redeemed,
        Completed,
        Disputed
    } // States of an exchange

    State currentState;

    uint256 public finalizedDate; // Date the contract was 'completed'

    // Fees and funds
    mapping(address => uint256) public balanceOf;
    uint256 public feeCollected;
    bool public isAvailableToWithdraw;

    // Parties
    address payable public buyer;
    address payable public seller;

    address factory; // Factory that create me...

    uint256 public totalEscrow; // balance of all escrow

    // Terms

    address public asset; // address of the IP NFT
    uint256 public assetTokeId; // specific tokenId the owner will transfer
    uint256 public price; // cost of the product (may be 0)
    uint256 public sellerDeposit; // how much the seller pays if they revoke (may be 0)
    uint256 public buyerPenalty; // amount required to pay by buyer in addition to the price (maybe 0)

    /// Timers

    uint256 public commitBy; // when the buyer must commit by
    uint256 public redeemBy; // when the buyer must redeem by
    uint256 public disputeBy; // when the buyer must dispute by

    // Default timer interval
    uint256 public constant ONE_WEEK = 7 days;
}
