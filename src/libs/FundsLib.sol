// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "../BionetTypes.sol";

import {CANCEL_REVOKE_FEE, PROTOCOL_FEE} from "../BionetConstants.sol";

/**
 * Protocol fees and payoffs.
 */
library FundsLib {
    // Calculate the fee required
    function calculateFee(uint256 _price, uint256 _basisPoint)
        internal
        pure
        returns (uint256)
    {
        return (_price * _basisPoint) / 10_000;
    }

    // Determine the msg.value required by the caller for a given state
    function calculateCost(uint256 _price, BionetTypes.ExchangeState _state)
        internal
        pure
        returns (uint256 amount)
    {
        if (_state == BionetTypes.ExchangeState.Canceled) {
            // buyer pays
            amount = calculateFee(_price, CANCEL_REVOKE_FEE);
        } else if (_state == BionetTypes.ExchangeState.Revoked) {
            // seller pays
            amount = calculateFee(_price, CANCEL_REVOKE_FEE);
        }
    }
}
