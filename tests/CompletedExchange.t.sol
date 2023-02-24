// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IConfig} from "../src/interfaces/IConfig.sol";
import {BionetExchange} from "../src/BionetExchange.sol";
import {IExchange} from "../src/interfaces/IExchange.sol";
import {ITreasury} from "../src/interfaces/ITreasury.sol";
import {BionetTestBase} from "./BionetTestBase.sol";

contract CompletedExchange is BionetTestBase {
    function test_completed_fuzz_pricing_terms(
        uint96 p,
        uint96 sd,
        uint96 bd
    ) public {
        _doComplete(p, sd, bd);
    }

    function test_seller_trigger_complete() public {
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

        // fast forward in time
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(seller);
        IExchange(e).triggerTimer();
        vm.stopPrank();

        uint256 fee = BionetExchange(e).feeCollected();

        assertEscrowBalances(e, buyerDep, (price + sellerDep) - fee);
        assertTrue(BionetExchange(e).isAvailableToWithdraw());

        // Check the treasury contract balance
        IConfig c = IConfig(IExchange(e).config());
        ITreasury t = ITreasury(c.getTreasury());
        assertEq(address(t).balance, fee, "Treasury Fee");
    }

    function _doComplete(
        uint256 price,
        uint256 sellerDep,
        uint256 buyerDep
    ) internal returns (address e) {
        e = createExchange([uint256(1), price, sellerDep, buyerDep]);
        //assertEscrowBalances(e, 0, sellerDep);

        vm.startPrank(buyer);
        IExchange(e).commit{value: price + buyerDep}();
        vm.stopPrank();

        vm.startPrank(buyer);
        IExchange(e).redeem();
        vm.stopPrank();

        vm.startPrank(buyer);
        IExchange(e).complete();
        vm.stopPrank();

        uint256 fee = BionetExchange(e).feeCollected();

        assertEscrowBalances(e, buyerDep, (price + sellerDep) - fee);

        assertTrue(BionetExchange(e).isAvailableToWithdraw());
        assertEq(BionetExchange(e).finalizedDate(), block.timestamp);

        // Check the treasury contract balance
        IConfig c = IConfig(IExchange(e).config());
        ITreasury t = ITreasury(c.getTreasury());
        assertEq(address(t).balance, fee);
    }
}
