// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

import {CANCEL_REVOKE_FEE, PROTOCOL_FEE} from "../BionetConstants.sol";

/**
 * @dev Helper function for protocol fees and costs.
 */
library FundsLib {
    /**
     * @dev Calculage a fee (% of price) for a given price and basis point.
     *
     * A way of calculating a percentage in Solidity.  For example,
     * 200 basis points is 2%. Current percentage are in BionetConstants
     */
    function calculateFee(uint256 _price, uint256 _basisPoint)
        internal
        pure
        returns (uint256)
    {
        return (_price * _basisPoint) / 10_000;
    }

    /**
     * @dev Calculate the cost needed for a given state.  This is
     * currently used to calculate penalty fees the caller is required
     * to submit (mg.value) with a revoke or cancel.
     */
    function calculateCost(uint256 _price, BionetTypes.ExchangeState _state)
        internal
        pure
        returns (uint256 amount)
    {
        if (
            _state == BionetTypes.ExchangeState.Canceled ||
            _state == BionetTypes.ExchangeState.Revoked
        ) {
            amount = calculateFee(_price, CANCEL_REVOKE_FEE);
        }
    }

    function calculateSellerDeposit(uint256 _price)
        internal
        pure
        returns (uint256 amount)
    {
        amount = calculateFee(_price, CANCEL_REVOKE_FEE);
    }
}
