// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BionetExchange} from "../src/BionetExchange.sol";
import {IExchange} from "../src/interfaces/IExchange.sol";
import {BionetTestBase} from "./BionetTestBase.sol";

contract CommitToExchange is BionetTestBase {
    function test_fuzz_pricing_terms(
        uint96 p,
        uint96 sd,
        uint96 bd
    ) public {
        _doCommit(p, sd, bd);
    }

    function test_commit_simple() public {
        uint256 tokenId = 1;
        uint256 price = 2 ether;
        uint256 sellerDep = 0;

        address e = createExchange([tokenId, price, sellerDep, uint256(0)]);
        vm.startPrank(buyer);
        vm.expectRevert("Exchange: Wrong deposit amount");
        IExchange(e).commit{value: 1 ether}();
        vm.stopPrank();
    }

    function test_buyer_must_send_correct_deposit() public {
        uint256 tokenId = 1;
        uint256 price = 2 ether;
        uint256 sellerDep = 0;

        {
            address e = createExchange([tokenId, price, sellerDep, uint256(0)]);
            vm.startPrank(buyer);
            vm.expectRevert("Exchange: Wrong deposit amount");
            IExchange(e).commit{value: 1 ether}();
            vm.stopPrank();
        }

        {
            address e = createExchange([tokenId, price, sellerDep, 0.9 ether]);
            vm.startPrank(buyer);
            vm.expectRevert("Exchange: Wrong deposit amount");
            IExchange(e).commit{value: 1 ether}();
            vm.stopPrank();
        }

        {
            address e = createExchange([tokenId, price, sellerDep, 0.9 ether]);
            vm.startPrank(buyer);
            vm.expectRevert("Exchange: Wrong deposit amount");
            IExchange(e).commit();
            vm.stopPrank();
        }

        {
            // Can send over amount
            address e = createExchange([tokenId, price, sellerDep, 0.9 ether]);
            vm.startPrank(buyer);
            IExchange(e).commit{value: 3 ether}();
            vm.stopPrank();
        }
    }

    function test_commitBy_expires() public {
        uint256 tokenId = 1;
        uint256 price = 2 ether;
        uint256 sellerDep = 0.2 ether;
        uint256 buyerDep = 0.2 ether;

        address e = createExchange([tokenId, price, sellerDep, buyerDep]);

        // Buyer doesn't pull the trigger and the deal expires
        vm.warp(block.timestamp + 9 days);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        assertEscrowBalances(e, 0, sellerDep);

        // Check buyer got their money back
        // Seller hasn't yet...
        assertEq(buyer.balance, FUNDING);
        assertLt(seller.balance, FUNDING);

        // Seller withdraws
        vm.startPrank(seller);
        IExchange(e).withdraw();
        vm.stopPrank();

        assertEscrowBalances(e, 0, 0);
        assertEq(seller.balance, FUNDING);
    }

    function test_seller_can_trigger_timer() public {
        uint256 tokenId = 1;
        uint256 price = 2 ether;
        uint256 sellerDep = 0.2 ether;
        uint256 buyerDep = 0.2 ether;

        address e = createExchange([tokenId, price, sellerDep, buyerDep]);

        // Try to trigger when not expired
        vm.startPrank(seller);
        IExchange(e).triggerTimer();
        vm.stopPrank();
        assertFalse(BionetExchange(e).isAvailableToWithdraw());

        // Buyer doesn't pull the trigger and the deal expires
        vm.warp(block.timestamp + 9 days);

        // Seller can trigger to close out when expired
        vm.startPrank(seller);
        IExchange(e).triggerTimer();
        vm.stopPrank();
        assertTrue(BionetExchange(e).isAvailableToWithdraw());
        assertEscrowBalances(e, 0, sellerDep);
    }

    function _doCommit(
        uint256 price,
        uint256 sellerDep,
        uint256 buyerDep
    ) internal returns (address e) {
        e = createExchange([uint256(1), price, sellerDep, buyerDep]);
        assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        assertEscrowBalances(e, price + buyerDep, sellerDep);
        assertFalse(BionetExchange(e).isAvailableToWithdraw());
    }
}
