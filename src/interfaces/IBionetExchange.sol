// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

/**
 * @dev Interface to the Bionet Exchange
 *
 * Contain the core logic and state transistions for the Bionet.
 *
 */
interface IBionetExchange {
    /**
     * @dev Emitted when an offer is created
     *
     * @param offerId the offer id
     * @param seller the address of the seller
     * @param offer a copy of the offer
     */
    event OfferCreated(
        uint256 indexed offerId,
        address indexed seller,
        BionetTypes.Offer offer
    );

    /**
     * @dev Emitted when an offer is voided
     *
     */
    event OfferVoided(uint256 indexed offerId, address indexed seller);

    /**
     * @dev Emitted when a buyer commits to purchase
     */
    event ExchangeCreated(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed buyer
    );

    /**
     * @dev Emitted when a seller revokes
     */
    event ExchangeRevoked(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed seller
    );

    /**
     * @dev Emitted when a buyer cancels
     */
    event ExchangeCanceled(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed buyer,
        bool timerExpired
    );

    /**
     * @dev Emitted when a buyer redeems
     */
    event ExchangeRedeemed(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed seller,
        uint256 timestamp
    );

    /**
     * @dev Emitted when a buyer redeems
     */
    event ExchangeCompleted(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        uint256 timestamp
    );

    /**
     * @dev initialize with needed addresses
     */
    function initialize(
        address _router,
        address _funds,
        address _voucher
    ) external;

    /**
     * @dev Create an Offer
     */
    function createOffer(BionetTypes.Offer memory _offer)
        external
        returns (uint256);

    /**
     * @dev Seller can void the offer, removing it from future purchases.
     *
     * This does not effect existing exchanges against the offer.
     */
    function voidOffer(address _caller, uint256 _offerId) external;

    /**
     * @dev Commit to an Offer.
     *
     * This will tokenize the committment by issuing a voucher to the buyer
     */
    function commit(address _buyer, uint256 _offerId)
        external
        payable
        returns (uint256);

    /**
     * @dev Cancel an committment
     */
    function cancel(address _buyer, uint256 exchangeId) external;

    /**
     * @dev Seller can revoke the exchange IFF the exchange state == COMMITTED
     *
     * This will calculate payoffs and release funds as needed.
     */
    function revoke(address _seller, uint256 _exchangeId) external payable;

    /**
     * @dev Redeem a voucher
     */
    function redeem(address _buyer, uint256 exchangeId) external;

    /**
     * @dev Finalize an exchange
     */
    function finalize(address _buyer, uint256 exchangeId) external;

    /**
     * @dev Return an Offer
     */
    function getOffer(uint256 _offerId)
        external
        view
        returns (bool exists, BionetTypes.Offer memory offer);

    /**
     * @dev Return an Exchange
     */
    function getExchange(uint256 _exchangeId)
        external
        view
        returns (bool exists, BionetTypes.Exchange memory exchange);
}
