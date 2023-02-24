// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BionetExchange} from "../src/BionetExchange.sol";
import {IExchange} from "../src/interfaces/IExchange.sol";
import {BionetTestBase} from "./BionetTestBase.sol";

contract CancelExchange is BionetTestBase {
    function test_fuzz_pricing_terms(
        uint96 p,
        uint96 sd,
        uint96 bd
    ) public {
        _doCancel(p, sd, bd);
    }

    function test_can_trigger_timer_with_buyer() public {
        uint256 tokenId = 1;
        uint256 price = 2 ether;
        uint256 sellerDep = 0.2 ether;
        uint256 buyerDep = 0.2 ether;

        address e = createExchange([tokenId, price, sellerDep, buyerDep]);
        assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        // fast forward in time
        vm.warp(block.timestamp + 10 days);

        // Timer is expired but outcome is the same
        vm.startPrank(buyer);
        IExchange(e).cancel();
        vm.stopPrank();

        assertEscrowBalances(e, price, sellerDep + buyerDep);
        assertTrue(BionetExchange(e).isAvailableToWithdraw());
    }

    function test_can_trigger_timer_with_seller() public {
        uint256 tokenId = 1;
        uint256 price = 2 ether;
        uint256 sellerDep = 0.2 ether;
        uint256 buyerDep = 0.2 ether;

        address e = createExchange([tokenId, price, sellerDep, buyerDep]);
        assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        // fast forward in time
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(seller);
        IExchange(e).triggerTimer();
        vm.stopPrank();

        assertEscrowBalances(e, price, sellerDep + buyerDep);
        assertTrue(BionetExchange(e).isAvailableToWithdraw());
    }

    function _doCancel(
        uint256 price,
        uint256 sellerDep,
        uint256 buyerDep
    ) internal returns (address e) {
        e = createExchange([uint256(1), price, sellerDep, buyerDep]);
        assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        vm.startPrank(buyer);
        IExchange(e).cancel();
        vm.stopPrank();

        assertEscrowBalances(e, price, sellerDep + buyerDep);
        assertTrue(BionetExchange(e).isAvailableToWithdraw());
    }
}
