// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

interface IBionetExchange {
    event OfferCreated(
        uint256 indexed offerId,
        address indexed seller,
        BionetTypes.Offer offer
    );

    event OfferVoided(uint256 indexed offerId, address indexed seller);

    event OfferCommitted(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed buyer
    );

    event OfferRevoked(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed seller
    );

    event OfferCanceled(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed buyer,
        bool timerExpired
    );

    event OfferRedeemed(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed seller,
        uint256 timestamp
    );

    function createOffer(address _caller, BionetTypes.Offer memory _offer)
        external
        returns (uint256);

    /**
     * @notice Seller can void the offer, removing it from future purchases.
     * This does not effect existing exchanges against the offer.
     * @param _caller should be the seller
     * @param _offerId the offer id
     */
    function voidOffer(address _caller, uint256 _offerId) external;

    function commit(address _buyer, uint256 _offerId)
        external
        payable
        returns (uint256);

    function cancel(address _buyer, uint256 exchangeId) external;

    /**
     * @notice Seller can revoke the exchange IFF the exchange state == COMMITTED
     * This will calculate payoffs and release funds as needed.
     * @param _seller only the seller can revoke
     * @param _exchangeId the id of the exchange
     */
    function revoke(address _seller, uint256 _exchangeId) external payable;

    function redeem(address _buyer, uint256 exchangeId) external;

    function getOffer(uint256 _offerId)
        external
        view
        returns (bool exists, BionetTypes.Offer memory offer);

    function getExchange(uint256 _exchangeId)
        external
        view
        returns (bool exists, BionetTypes.Exchange memory exchange);
}
