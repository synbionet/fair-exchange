// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

/**
 * @dev Main interface to the application.
 *
 * Serves as a simple proxy.
 */
interface IBionetRouter {
    /**
     * @dev initialize with needed addresses
     */
    function initialize(address _exchange) external;

    /**
     * @dev estimate the seller's required deposit for
     * a given price
     */
    function estimateSellerDeposit(uint256 _price) external returns (uint256);

    /**
     * @dev Create a new offer.
     *
     * Called by the seller.
     */
    function createOffer(BionetTypes.Offer memory _offer)
        external
        payable
        returns (uint256);

    /**
     * @dev Void an existing offer
     *
     * Called by the seller to 'delist' and offering.
     */
    function voidOffer(uint256 _offerId) external;

    /**
     * @dev Commit to an offer.
     *
     * Called by the buyer.  Marked as 'payable' as the
     * buyer is expected to escrow funds for the purchase
     */
    function commit(uint256 _offerId) external payable returns (uint256);

    /**
     * @dev Cancel a committement to a purchase.
     *
     * Called by the buyer.
     */
    function cancel(uint256 _exchangeId) external;

    /**
     * @dev Revoke a committment to a sale
     *
     * Called by the seller. Marked as 'payable' as the seller
     * is expected to pay a penalty
     */
    function revoke(uint256 _exchangeId) external payable;

    /**
     * @dev Redeem a voucher representing a committment to a purchase
     *
     * Called by the buyer
     */
    function redeem(uint256 _exchangeId) external;

    /**
     * @dev Called to complete an exchange.
     *
     * This marks the exchanged as 'completed' and release funds to all parties.
     * - If the dispute timer is not expired, only the buyer can call this.
     * - If the timer is expired anyone can call this to finalize the exchange.
     */
    function finalize(uint256 _exchangeId) external;

    /**
     * @dev Withdraw funds that have been released from escrow
     *
     * Can be called by buyer or seller
     */
    function withdraw() external;

    /**
     * @dev Get the escrow balance of a given account
     */
    function escrowBalance(address _account)
        external
        view
        returns (uint256 bal);
}
