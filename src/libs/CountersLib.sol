// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

/**
 * @dev Maintains counters used for offer and exchange IDs
 * Used by Exchange
 * Adapted from OpenZeppelin's Counter.
 */
library CountersLib {
    // Store for counters
    struct Counter {
        uint256 _offerId;
        uint256 _exchangeId;
    }

    /**
     * @dev Return the next Offer ID
     *
     * Increments the counter and returns the new value
     */
    function nextOfferId(Counter storage counter) internal returns (uint256) {
        unchecked {
            counter._offerId += 1;
        }
        return counter._offerId;
    }

    /**
     * @dev Return the next Exchange ID
     *
     * Increments the counter and returns the new value
     */
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
