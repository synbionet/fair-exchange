// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import {FundsLib} from "../src/libs/FundsLib.sol";
import {CANCEL_REVOKE_FEE, PROTOCOL_FEE} from "../src/BionetConstants.sol";

import "./helpers/BaseBionetTest.sol";

contract FundsTest is BaseBionetTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function testLib() public {
        uint256 price = 2 ether;

        assertEq(FundsLib.calculateFee(price, PROTOCOL_FEE), 0.06 ether);
        assertEq(FundsLib.calculateFee(price, CANCEL_REVOKE_FEE), 0.04 ether);

        assertEq(
            FundsLib.calculateCost(price, BionetTypes.ExchangeState.Revoked),
            0.04 ether
        );
        assertEq(
            FundsLib.calculateCost(price, BionetTypes.ExchangeState.Canceled),
            0.04 ether
        );
    }
}
