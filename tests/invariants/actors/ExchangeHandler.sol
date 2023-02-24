// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import {Address} from "../InvariantBase.sol";
import {BionetExchange} from "../../../src/BionetExchange.sol";
import {BionetExchangeFactory} from "../../../src/BionetExchangeFactory.sol";

import "forge-std/Test.sol";

contract ExchangeHandler is Test {
    address payable[] buyers;
    address payable[] sellers;

    address factory;
    address[] public activeExchanges;

    // Ghost Variables
    uint256 public numExchanges;
    uint256 public totalWithdrawn;

    //TODO: For now we use fake asset address
    address fakeAsset = address(0x5151);

    constructor(
        address _factory,
        uint256 _numBuyers,
        uint256 _numSellers
    ) {
        factory = _factory;

        for (uint256 i; i < _numBuyers; ++i) {
            address payable buyer = payable(address(new Address()));
            vm.deal(buyer, 1e36);
            buyers.push(buyer);
        }

        for (uint256 i; i < _numSellers; ++i) {
            address payable seller = payable(address(new Address()));
            vm.deal(seller, 1e36);
            sellers.push(seller);
        }
    }

    function createExchange(
        uint256 buyerSeed,
        uint256 sellerSeed,
        uint256[4] memory _terms
    ) external {
        uint256 bI = bound(buyerSeed, 0, buyers.length - 1);
        uint256 sI = bound(sellerSeed, 0, sellers.length - 1);

        address payable buyer = buyers[bI];
        address payable seller = sellers[sI];
        uint256 dueFromSeller = _terms[2];

        vm.startPrank(seller);
        address exchange = BionetExchangeFactory(factory).createExchange{
            value: dueFromSeller
        }(buyer, fakeAsset, _terms);

        activeExchanges.push(exchange);

        vm.stopPrank();
        numExchanges += 1;
    }

    function commitToExchange(uint256 buyerSeed, uint256 exchangeSeed) public {
        uint256 bI = bound(buyerSeed, 0, buyers.length - 1);
        uint256 eI = bound(exchangeSeed, 0, numExchanges - 1);

        address payable buyer = buyers[bI];

        BionetExchange exchange = BionetExchange(activeExchanges[eI]);
        uint256 buyerAmount = exchange.price() + exchange.buyerPenalty();

        vm.startPrank(buyer);
        exchange.commit{value: buyerAmount}();
        vm.stopPrank();
    }

    function cancelExchange(uint256 exchangeSeed) public {
        uint256 eI = bound(exchangeSeed, 0, numExchanges - 1);
        BionetExchange exchange = BionetExchange(activeExchanges[eI]);
        address buyer = exchange.buyer();

        vm.startPrank(buyer);
        exchange.cancel();
        vm.stopPrank();
    }

    function revokeExchange(uint256 exchangeSeed) public {
        uint256 eI = bound(exchangeSeed, 0, numExchanges - 1);
        BionetExchange exchange = BionetExchange(activeExchanges[eI]);
        address seller = exchange.seller();

        vm.startPrank(seller);
        exchange.revoke();
        vm.stopPrank();
    }

    function redeemExchange(uint256 exchangeSeed) public {
        uint256 eI = bound(exchangeSeed, 0, numExchanges - 1);
        BionetExchange exchange = BionetExchange(activeExchanges[eI]);
        address buyer = exchange.buyer();

        vm.startPrank(buyer);
        exchange.redeem();
        vm.stopPrank();
    }

    function completeExchange(uint256 exchangeSeed) public {
        uint256 eI = bound(exchangeSeed, 0, numExchanges - 1);
        BionetExchange exchange = BionetExchange(activeExchanges[eI]);

        vm.startPrank(exchange.buyer());
        exchange.complete();
        vm.stopPrank();
    }

    function triggerExchange(uint256 exchangeSeed) public {
        uint256 eI = bound(exchangeSeed, 0, numExchanges - 1);
        BionetExchange exchange = BionetExchange(activeExchanges[eI]);
        exchange.triggerTimer();
    }

    function withdrawExchange(uint256 exchangeSeed) public {
        uint256 eI = bound(exchangeSeed, 0, numExchanges - 1);
        BionetExchange exchange = BionetExchange(activeExchanges[eI]);
        address buyer = exchange.buyer();
        address seller = exchange.buyer();
        uint256 tE = exchange.totalEscrow();

        vm.startPrank(buyer);
        exchange.withdraw();
        vm.stopPrank();

        vm.startPrank(seller);
        exchange.withdraw();
        vm.stopPrank();

        totalWithdrawn += tE;
    }
}
