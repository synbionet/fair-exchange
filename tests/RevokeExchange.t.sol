// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BionetExchange} from "../src/BionetExchange.sol";
import {IExchange} from "../src/interfaces/IExchange.sol";
import {BionetTestBase} from "./BionetTestBase.sol";

contract RevokeExchange is BionetTestBase {
    function test_fuzz_pricing_terms(
        uint96 p,
        uint96 sd,
        uint96 bd
    ) public {
        _doRevoke(p, sd, bd);
    }

    function test_expired_is_a_cancel_fee() public {
        uint256 price = 2 ether;
        uint256 sellerDep = 0.2 ether;
        uint256 buyerDep = 0.2 ether;
        address e = createExchange([uint256(1), price, sellerDep, buyerDep]);
        assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        // fast forward in time
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(seller);
        IExchange(e).revoke();
        vm.stopPrank();

        // Note: this is a cancel fee because of expiring
        assertEscrowBalances(e, price, sellerDep + buyerDep);
        assertTrue(BionetExchange(e).isAvailableToWithdraw());
    }

    function test_seller_can_trigger_expire() public {
        uint256 price = 2 ether;
        uint256 sellerDep = 0.2 ether;
        uint256 buyerDep = 0.2 ether;
        address e = createExchange([uint256(1), price, sellerDep, buyerDep]);
        assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        // fast forward in time
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(seller);
        IExchange(e).triggerTimer();
        vm.stopPrank();

        // Note: this is a cancel fee because of expiring
        assertEscrowBalances(e, price, sellerDep + buyerDep);
        assertTrue(BionetExchange(e).isAvailableToWithdraw());
    }

    function _doRevoke(
        uint256 price,
        uint256 sellerDep,
        uint256 buyerDep
    ) internal returns (address e) {
        e = createExchange([uint256(1), price, sellerDep, buyerDep]);
        assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        vm.startPrank(seller);
        IExchange(e).revoke();
        vm.stopPrank();

        assertEscrowBalances(e, price + buyerDep + sellerDep, 0);
        assertTrue(BionetExchange(e).isAvailableToWithdraw());
    }
}
