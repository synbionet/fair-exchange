// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import {FundsLib} from "../src/libs/FundsLib.sol";
import {BionetTestBase} from "./BionetTestBase.sol";
import {CANCEL_REVOKE_FEE, WEEK} from "../src/BionetConstants.sol";

import {MockAsset} from "./mocks/MockAsset.sol";

/**
 */
contract RedeemTest is BionetTestBase {
    function test_good_redeem() public {}

    function test_cant_redeem_on_expire() public {}
}
