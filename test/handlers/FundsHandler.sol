// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

/**
 * Wrapper for invariant testing BionetFunds
 * Invariants:
 *  - total ether balance == total escrowed + total fees;
 *  - escrow == sum of all accounts
 *  - releaseable funds <= all escrowed
 */
contract FundsHandler is CommonBase, StdCheats, StdUtils {
    constructor() {
        deal(address(this), 10 ether);
    }

    function deposit(uint256 amount) public {
        //funds.deposit{value: amount}(msg.sender);
    }
}
