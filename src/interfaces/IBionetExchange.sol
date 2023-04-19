// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

/// Core logic and state transistions for the Bionet.
///  - see implementation for the details of each function -
interface IBionetExchange {
    /// @dev Emitted when an offer is created
    /// @param offerId of the offer
    /// @param seller creating the offer
    /// @param offer model
    event OfferCreated(
        uint256 indexed offerId,
        address indexed seller,
        BionetTypes.Offer offer
    );

    /// @dev Emitted when a seller voids an offer
    /// @param offerId of the offer voided
    /// @param seller of the offer
    event OfferVoided(uint256 indexed offerId, address indexed seller);

    /// @dev Emitted when an exchange is created from a 'commit'
    /// @param offerId of the offer
    /// @param exchangeId the new exchange
    /// @param buyer committing to the exchange
    event ExchangeCreated(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed buyer
    );

    /// @dev Emitted when the seller revokes an exchange
    /// @param offerId of the offer
    /// @param exchangeId the new exchange
    /// @param seller revoking the exchange
    event ExchangeRevoked(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed seller
    );

    /// @dev Emitted when a buyer cancels or the protocol times out
    /// during the 'redeem' period.
    /// @param offerId of the offer
    /// @param exchangeId the new exchange
    /// @param buyer committing to the exchange
    /// @param timerExpired is true if this was a result of expiration
    event ExchangeCanceled(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed buyer,
        bool timerExpired
    );

    /// @dev Emitted when the buyer calls redeem
    /// @param offerId of the offer
    /// @param exchangeId the new exchange
    /// @param seller of the offer
    event ExchangeRedeemed(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        address indexed seller
    );

    /// @dev Emitted when the buyer finalizes the exchange or the
    /// dispute period times out.
    /// @param offerId of the offer
    /// @param exchangeId the new exchange
    /// @param timestamp of completion
    event ExchangeCompleted(
        uint256 indexed offerId,
        uint256 indexed exchangeId,
        uint256 timestamp
    );

    /// @dev Emitted on an Ether withdraw from the exchange.
    /// Usually happens at an end state in the protocol.
    /// @param account of the exchange withdraw from
    /// @param amount withdrawn
    event Withdraw(address indexed account, uint256 amount);

    /// @dev Emitted when a withdraw is attempted but ther are
    /// no funds available to withdraw.
    /// @param account of the exchange withdraw from
    /// @param amount withdrawn
    event FundsNotAvailable(address indexed account, uint256 amount);

    /// @dev Emitted when funds are released from escrow
    /// and available to withdraw.
    /// @param account the funds where released to
    /// @param amount released
    event ReleaseEscrow(address account, uint256 amount);

    /// @dev Emitted when the protocol collects a fee.
    /// @param exchangeId of the exchange generating the fee
    /// @param amount collected
    event FeeCollected(uint256 exchangeId, uint256 amount);

    function initialize(address _router, address _voucher) external;

    function createOffer(BionetTypes.Offer memory _offer)
        external
        payable
        returns (uint256);

    function voidOffer(address _caller, uint256 _offerId) external;

    function commit(address _buyer, uint256 _offerId)
        external
        payable
        returns (uint256);

    function cancel(address _buyer, uint256 exchangeId) external;

    function revoke(address _seller, uint256 _exchangeId) external;

    function redeem(address _buyer, uint256 exchangeId) external;

    function finalize(address _buyer, uint256 exchangeId) external;

    function withdraw(address _account) external;

    function getEscrowBalance(address _account) external view returns (uint256);

    function getAvailableToWithdrawEscrowBalance(address _account) external view returns (uint256);

    function getProtocolBalance() external view returns (uint256);

    function getOffer(uint256 _offerId)
        external
        view
        returns (bool, BionetTypes.Offer memory offer);

    function getExchange(uint256 _exchangeId)
        external
        view
        returns (bool, BionetTypes.Exchange memory exchange);
}
