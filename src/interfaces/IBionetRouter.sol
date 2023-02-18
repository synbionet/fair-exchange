// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

/// @dev Main interface to the application.
///  - see implementation for details
interface IBionetRouter {
    function initialize(address _exchange) external;

    function getSellerDeposit(uint256 _price) external returns (uint256);

    function getExchange(uint256 _exchangeId)
        external
        view
        returns (bool, BionetTypes.Exchange memory);

    function getOffer(uint256 _exchangeId)
        external
        view
        returns (bool, BionetTypes.Offer memory);

    function getProtocolBalance() external view returns (uint256 bal);

    function createOffer(BionetTypes.Offer memory _offer)
        external
        payable
        returns (uint256);

    function voidOffer(uint256 _offerId) external;

    function commit(uint256 _offerId) external payable returns (uint256);

    function cancel(uint256 _exchangeId) external;

    function revoke(uint256 _exchangeId) external;

    function redeem(uint256 _exchangeId) external;

    function finalize(uint256 _exchangeId) external;

    function withdraw() external;

    function getEscrowBalance(address _account)
        external
        view
        returns (uint256 bal);
}
