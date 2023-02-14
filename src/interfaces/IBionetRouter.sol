// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

// Main UI interface to app
interface IBionetRouter {
    function createOffer(BionetTypes.Offer memory _offer)
        external
        returns (uint256);

    function voidOffer(uint256 _offerId) external;

    function commit(uint256 _offerId) external payable returns (uint256);

    function cancel(uint256 _exchangeId) external;

    function revoke(uint256 _exchangeId) external payable;

    function redeem(uint256 _exchangeId) external;

    function withdraw(uint256 _amount) external;

    function escrowBalance(address _account)
        external
        view
        returns (uint256 bal);
}
