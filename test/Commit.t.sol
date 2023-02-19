// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "../src/BionetTypes.sol";
import {BionetTestBase} from "./BionetTestBase.sol";

import {MockAsset} from "./mocks/MockAsset.sol";

/**
 */
contract CommitTest is BionetTestBase {
    uint256 constant offerPrice = 2.3 ether;

    function test_buyer_cant_withdraw_after_commit() public {
        uint256 offerId = _createOffer(offerPrice);

        uint256 eb = router.getEscrowBalance(buyer);
        assertEq(eb, 0);

        vm.startPrank(buyer);
        router.commit{value: offerPrice}(offerId);
        vm.stopPrank();

        uint256 ea = router.getEscrowBalance(buyer);
        assertEq(ea, offerPrice);

        vm.startPrank(buyer);
        router.withdraw();
        vm.stopPrank();

        uint256 ea1 = router.getEscrowBalance(buyer);
        assertEq(ea1, offerPrice);
    }

    function test_commit_wrong_price() public {
        uint256 oid = _createOffer(offerPrice);

        vm.startPrank(buyer);
        vm.expectRevert();
        router.commit{value: 2 ether}(oid);
        vm.stopPrank();
    }

    function test_commit_404_offer() public {
        vm.startPrank(buyer);
        vm.expectRevert();
        router.commit{value: offerPrice}(1001);
        vm.stopPrank();
    }

    function test_commit_to_void_offer() public {
        uint256 oid = _createOffer(offerPrice);
        vm.startPrank(seller);
        router.voidOffer(oid);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert();
        router.commit{value: offerPrice}(oid);
        vm.stopPrank();
    }

    function test_escrow_after_commit() public {
        uint256 oid = _createOffer(offerPrice);
        vm.startPrank(buyer);
        router.commit{value: offerPrice}(oid);
        vm.stopPrank();

        uint256 bal = router.getEscrowBalance(buyer);
        assertEq(bal, offerPrice);
    }
}
