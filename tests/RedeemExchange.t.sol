// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BionetExchange} from "../src/BionetExchange.sol";
import {IExchange} from "../src/interfaces/IExchange.sol";
import {BionetTestBase} from "./BionetTestBase.sol";

contract RedeemExchange is BionetTestBase {
    function test_expired_is_a_cancel() public {
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

        vm.startPrank(buyer);
        IExchange(e).redeem();
        vm.stopPrank();

        assertEscrowBalances(e, price, sellerDep + buyerDep);
        assertTrue(BionetExchange(e).isAvailableToWithdraw());
    }

    function test_no_funds_moved() public {
        uint256 price = 2 ether;
        uint256 sellerDep = 0.2 ether;
        uint256 buyerDep = 0.2 ether;
        address e = createExchange([uint256(1), price, sellerDep, buyerDep]);
        assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        vm.startPrank(buyer);
        IExchange(e).redeem();
        vm.stopPrank();

        assertEscrowBalances(e, price + buyerDep, sellerDep);
        assertFalse(BionetExchange(e).isAvailableToWithdraw());
    }
}
