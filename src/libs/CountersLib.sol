// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

library CountersLib {
    struct Counter {
        uint256 _offerId;
        uint256 _exchangeId;
    }

    function nextOfferId(Counter storage counter) internal returns (uint256) {
        unchecked {
            counter._offerId += 1;
        }
        return counter._offerId;
    }

    function nextExchangeId(Counter storage counter)
        internal
        returns (uint256)
    {
        unchecked {
            counter._exchangeId += 1;
        }
        return counter._exchangeId;
    }
}
