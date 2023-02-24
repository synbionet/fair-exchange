pragma solidity ^0.8.13;
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {BionetExchange} from "../../src/BionetExchange.sol";

import {InvariantBase} from "./InvariantBase.sol";
import {ExchangeHandler} from "./actors/ExchangeHandler.sol";

import "forge-std/Test.sol";

/// Invariant Tests:
///  * A: ether balance >= escrow balance
///  * B: fundAvailable == finalizedDate > 0
///  * C: total escrow >= seller + buyer deposits
///  * D: total withdraw <= totalEscrow
///
contract ExchangeInvariant is InvariantBase {
    ExchangeHandler handler;

    function setUp() public virtual override {
        super.setUp();

        handler = new ExchangeHandler(factory, 3, 5);
        targetContract(address(handler));
    }

    function invariant_exchange() external {
        for (uint256 i = 0; i < handler.numExchanges(); i++) {
            address e = handler.activeExchanges(i);
            assert_exchange_invariant_A(e);
            assert_exchange_invariant_B(e);
            assert_exchange_invariant_C(e);
            assert_exchange_invariant_D(e);
        }
    }

    function assert_exchange_invariant_A(address _exchange) public {
        uint256 ethBal = _exchange.balance;
        assertGe(
            ethBal,
            BionetExchange(_exchange).totalEscrow() -
                BionetExchange(_exchange).feeCollected(),
            "eth != escrow"
        );
    }

    function assert_exchange_invariant_B(address _exchange) public {
        bool aTw = BionetExchange(_exchange).isAvailableToWithdraw();
        bool fD = BionetExchange(_exchange).finalizedDate() > 0;
        assertEq(aTw, fD);
    }

    function assert_exchange_invariant_C(address _exchange) public {
        BionetExchange e = BionetExchange(_exchange);
        uint256 total = e.totalEscrow();
        uint256 bTotal = e.escrowBalance(e.buyer());
        uint256 sTotal = e.escrowBalance(e.seller());
        assertGe(total, sTotal + bTotal, "Total == both deposits");
    }

    function assert_exchange_invariant_D(address _exchange) public {
        BionetExchange e = BionetExchange(_exchange);
        uint256 totalE = e.totalEscrow();
        assertLe(handler.totalWithdrawn(), totalE, "Total withdrawn");
    }
}
