// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {SimBase} from "../simulation/SimBase.sol";
import {RefundType} from "../src/BionetTypes.sol";

// Diamond address: 0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0

contract SimScript is Script, SimBase {
    function setUp() public {
        _setUpActors();
    }

    function _happyPathScenario() internal {
        uint256 sid = _sellerCreateService("exampleService", "ipfs://hello");
        uint256 eid = _sellerCreateOffer(sid);
        _buyerFundOffer(eid);
        _buyerCompleteExchange(eid);
    }

    function _disputeResolveScenario() internal {
        uint256 sid = _sellerCreateService("exampleService", "ipfs://hello");
        uint256 eid = _sellerCreateOffer(sid);
        _buyerFundOffer(eid);
        _buyerDispute(eid);
        _moderatorResolve(eid, RefundType.Full);
        _buyerAgreeToRefund(eid);
    }

    function run() public {
        _deployBaseContracts();
        _disputeResolveScenario();
    }
}
