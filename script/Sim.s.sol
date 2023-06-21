// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Script.sol";

import {USDC} from "../src/mocks/USDC.sol";
import {SimBase} from "../simulation/SimBase.sol";
import {RefundType} from "../src/BionetTypes.sol";
import {SigUtils} from "../test/utils/SigUtils.sol";

contract SimScript is SimBase {
    // Addressed when using Simbase deploy()
    string constant DIA_ADDRESS = "0xA51c1fc2f0D1a1b8494Ed1FE312d7C3a78Ed91C0";
    string constant USD_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

    function setUp() public {
        _setUpActors();
        diamondAddress = vm.parseAddress(DIA_ADDRESS);
        address usdcAddress = vm.parseAddress(USD_ADDRESS);

        sigUtil = new SigUtils(USDC(usdcAddress).DOMAIN_SEPARATOR());
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
        _happyPathScenario();
        //_disputeResolveScenario();
    }
}
