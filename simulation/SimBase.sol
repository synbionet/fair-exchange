// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

// Helpers
import {SelectorHelper} from "../test/utils/SelectorHelper.sol";
import {SigUtils} from "../test/utils/SigUtils.sol";

// Diamond specific
import {Diamond} from "diamond/Diamond.sol";
import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";
import {OwnershipFacet} from "diamond/facets/OwnershipFacet.sol";
import {IDiamondLoupe} from "diamond/interfaces/IDiamondLoupe.sol";
import {DiamondCutFacet} from "diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "diamond/facets/DiamondLoupeFacet.sol";

// App deps
import {USDC} from "../src/mocks/USDC.sol";
import {Treasury} from "../src/dao/Treasury.sol";
import {ExchangeArgs} from "../src/BionetTypes.sol";
import {BionetInit, InitArgs} from "../src/BionetInit.sol";

// Facets
import {FromStorage} from "../src/facets/FromStorage.sol";
import {ServiceFacet} from "../src/facets/ServiceFacet.sol";
import {ExchangeFacet} from "../src/facets/ExchangeFacet.sol";

import {Exchange, ExchangeArgs, ExchangePermitArgs, RefundType} from "../src/BionetTypes.sol";

struct Actor {
    address actorAddress;
    uint256 secretKey;
}

/**
 * Helper to write scripts for simulation andt testing
 */
contract SimBase is SelectorHelper, Script {
    // Anvil's default mnemonic
    string constant ANVIL_MNEMONIC =
        "test test test test test test test test test test test junk";

    // actors
    address buyer;
    address seller;
    address moderator;
    address deployer;

    // Diamond address
    address diamondAddress;

    // default USD balance. USD has 6 decimal places, e.g., 1 USD == 1e6
    uint256 constant defaultUSD = 10_000 * 1e6;

    // default protocol fee (2%)
    uint256 constant defaultProtocolFee = 200;

    // ** Sim defaults **
    // service price
    uint128 defaultPrice = 20e6;
    // time to dispute
    uint256 defaultDisputeTime = 30 days;
    // moderator percentage
    uint16 defaultModeratorFee = 200; // 2%
    // sig permit expiration
    uint256 defaultPermitExpiration = 1 days;

    SigUtils sigUtil;

    mapping(address => uint256) actorSecretKeys;

    function _setUpActors() internal {
        uint256 dSk;
        uint256 bSk;
        uint256 sSk;
        uint256 mSk;
        (deployer, dSk) = deriveRememberKey(ANVIL_MNEMONIC, 0);
        actorSecretKeys[deployer] = dSk;

        (seller, sSk) = deriveRememberKey(ANVIL_MNEMONIC, 1);
        actorSecretKeys[seller] = sSk;

        (buyer, bSk) = deriveRememberKey(ANVIL_MNEMONIC, 2);
        actorSecretKeys[buyer] = bSk;

        (moderator, mSk) = deriveRememberKey(ANVIL_MNEMONIC, 3);
        actorSecretKeys[moderator] = mSk;
    }

    function _deployBaseContracts() internal {
        vm.startBroadcast(deployer);
        // deploy treasure and stablecoin (mock). They are outside of diamond
        // address
        USDC usdc = new USDC();
        Treasury treasury = new Treasury(address(usdc));

        // Fund the actors with USD
        usdc.mint(buyer, defaultUSD);
        usdc.mint(seller, defaultUSD);
        usdc.mint(moderator, defaultUSD);

        // Setup the signer utils
        sigUtil = new SigUtils(usdc.DOMAIN_SEPARATOR());

        // Deploy  facets
        FromStorage fs = new FromStorage();
        ServiceFacet sf = new ServiceFacet();
        ExchangeFacet ef = new ExchangeFacet();

        // *** Diamond Setup *** //

        // deploy core facets
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        OwnershipFacet ownerF = new OwnershipFacet();

        // deploy diamond
        diamondAddress = address(new Diamond(deployer, address(dCutFacet)));

        // Deploy the init w/args
        BionetInit bInit = new BionetInit();
        InitArgs memory _args = InitArgs({
            treasury: address(treasury),
            usdc: address(usdc),
            protocolFee: defaultProtocolFee
        });
        // Encode the calldata
        bytes memory initCalldata = abi.encodeWithSignature(
            "init((address,address,uint256))",
            _args
        );

        // Setup da cuts...
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);

        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(dLoupe),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            IDiamondCut.FacetCut({
                facetAddress: address(ownerF),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            IDiamondCut.FacetCut({
                facetAddress: address(fs),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: generateSelectors("FromStorage")
            })
        );

        cut[3] = (
            IDiamondCut.FacetCut({
                facetAddress: address(sf),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: generateSelectors("ServiceFacet")
            })
        );

        cut[4] = (
            IDiamondCut.FacetCut({
                facetAddress: address(ef),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: generateSelectors("ExchangeFacet")
            })
        );

        IDiamondCut(diamondAddress).diamondCut(
            cut,
            address(bInit),
            initCalldata
        );

        vm.stopBroadcast();

        console.log("~ addresses: ~");
        console.log("USDC: %s", address(usdc));
        console.log("Actors funded with 10,000 USDC");
        console.log("Treasury: %s", address(treasury));
        console.log("Diamond: %s", diamondAddress);
    }

    function _sellerCreateService(string memory name, string memory uri)
        internal
        returns (uint256 sid)
    {
        vm.startBroadcast(seller);
        sid = ServiceFacet(diamondAddress).createService(name, uri);
        vm.stopBroadcast();
    }

    function _sellerCreateOffer(uint256 serviceId)
        internal
        returns (uint256 id)
    {
        vm.startBroadcast(seller);
        ExchangeArgs memory args = ExchangeArgs({
            serviceId: serviceId,
            buyer: buyer,
            moderator: moderator,
            moderatorPercentage: defaultModeratorFee,
            price: defaultPrice,
            disputeTimerValue: defaultDisputeTime,
            uri: "ar://txid"
        });

        id = ExchangeFacet(diamondAddress).createOffer(args);
        vm.stopBroadcast();
    }

    function _buyerFundOffer(uint256 exchangeId) internal {
        vm.startBroadcast(buyer);
        SigUtils.Permit memory permit = _makePermitWithDefaults(buyer);
        bytes32 hashed = sigUtil.getTypedDataHash(permit);
        uint256 sk = actorSecretKeys[buyer];
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(sk, hashed);

        ExchangeFacet(diamondAddress).fundOffer(
            exchangeId,
            ExchangePermitArgs({v: v, r: r, s: s, validFor: permit.deadline})
        );
        vm.stopBroadcast();
    }

    function _buyerCompleteExchange(uint256 exchangeId) internal {
        vm.startBroadcast(buyer);
        ExchangeFacet(diamondAddress).complete(exchangeId);
        vm.stopBroadcast();
    }

    function _buyerDispute(uint256 exchangeId) internal {
        vm.startBroadcast(buyer);
        ExchangeFacet(diamondAddress).dispute(exchangeId);
        vm.stopBroadcast();
    }

    function _moderatorResolve(uint256 exchangeId, RefundType _rt) internal {
        vm.startBroadcast(moderator);
        ExchangeFacet(diamondAddress).resolve(exchangeId, _rt);
        vm.stopBroadcast();
    }

    function _buyerAgreeToRefund(uint256 exchangeId) internal {
        vm.startBroadcast(buyer);
        ExchangeFacet(diamondAddress).agreeToRefund(exchangeId);
        vm.stopBroadcast();
    }

    function _makePermitWithDefaults(address _owner)
        internal
        view
        returns (SigUtils.Permit memory permit)
    {
        uint256 _nonce = vm.getNonce(_owner);
        permit = SigUtils.Permit({
            owner: _owner,
            spender: diamondAddress,
            value: defaultPrice,
            nonce: _nonce,
            deadline: block.timestamp + defaultPermitExpiration
        });
    }
}
