// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";
import {CommonBase} from "forge-std/Base.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {BionetFunds} from "../../src/BionetFunds.sol";

/**
 * Wrapper for invariant testing BionetFunds
 */
contract FundsHandler is CommonBase, StdCheats, StdUtils {
    //BionetFunds funds;

    constructor() {
        //funds = new BionetFunds(address(this), address(this));
    }
}
