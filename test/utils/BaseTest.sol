// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

// test stuff
import "forge-std/Test.sol";
import {SigUtils} from "./SigUtils.sol";
import {SelectorHelper} from "./SelectorHelper.sol";

// diamond stuff
import {Diamond} from "diamond/Diamond.sol";
import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";
import {OwnershipFacet} from "diamond/facets/OwnershipFacet.sol";
import {IDiamondLoupe} from "diamond/interfaces/IDiamondLoupe.sol";
import {DiamondCutFacet} from "diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "diamond/facets/DiamondLoupeFacet.sol";

// app stuff
import {USDC} from "../../src/mocks/USDC.sol";
import {Treasury} from "../../src/dao/Treasury.sol";
import {ExchangeArgs} from "../../src/BionetTypes.sol";
import {BionetInit, InitArgs} from "../../src/BionetInit.sol";
import {FromStorage} from "../../src/facets/FromStorage.sol";
import {ServiceFacet} from "../../src/facets/ServiceFacet.sol";
import {ExchangeFacet} from "../../src/facets/ExchangeFacet.sol";

abstract contract BaseTest is SelectorHelper {
    // $500 in USDC
    uint256 constant BUYER_INITIAL_BALANCE = 500e6;

    // Secret keys need to sign permit
    uint256 buyerSecretKey = 0xa1234;
    uint256 sellerSecretKey = 0xb5678;

    // Actors
    address buyer = vm.addr(buyerSecretKey);
    address seller = vm.addr(sellerSecretKey);
    address moderator = address(0x11);

    USDC usdc;

    // Default values
    uint128 defaultPrice = 20e6;
    uint256 defaultDisputeTime = 30 days;
    uint16 defaultModeratorFee = 200; // 2%
    uint256 defaultPermitExpiration = 1 days;

    // Default Service Info
    uint256 serviceId;
    string serviceName = "Example Service";
    string serviceUri = "ar://hashtojson";

    // lil helper
    SigUtils sigUtil;

    address diamondAddress;
    address owner = address(this);

    function setUp() public virtual {
        vm.deal(buyer, 1 ether);
        vm.deal(seller, 1 ether);
        vm.deal(moderator, 1 ether);

        // deploy treasure and stablecoin (mock)
        usdc = new USDC();
        // Give some buying power to the buyer
        usdc.mint(buyer, BUYER_INITIAL_BALANCE);
        sigUtil = new SigUtils(usdc.DOMAIN_SEPARATOR());
        Treasury t = new Treasury(address(usdc));

        // Deploy my facets
        FromStorage fs = new FromStorage();
        ServiceFacet sf = new ServiceFacet();
        ExchangeFacet ef = new ExchangeFacet();

        // *** Diamond Setup *** //
        // deploy core facets
        DiamondCutFacet dCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet dLoupe = new DiamondLoupeFacet();
        OwnershipFacet ownerF = new OwnershipFacet();

        // deploy diamond
        diamondAddress = address(new Diamond(owner, address(dCutFacet)));

        // Deploy the init
        BionetInit bInit = new BionetInit();
        InitArgs memory _args = InitArgs({
            treasury: address(t),
            usdc: address(usdc),
            protocolFee: 200
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

        // Deploy a service for testing owned by the seller
        vm.startPrank(seller);
        serviceId = ServiceFacet(diamondAddress).createService(
            serviceName,
            serviceUri
        );
        vm.stopPrank();
    }

    function makeService() internal returns (uint256 sid) {
        sid = ServiceFacet(diamondAddress).createService(
            serviceName,
            serviceUri
        );
    }

    function defaultExchangeArgs()
        internal
        view
        returns (ExchangeArgs memory args)
    {
        args = ExchangeArgs({
            serviceId: serviceId,
            buyer: buyer,
            moderator: moderator,
            moderatorPercentage: defaultModeratorFee,
            price: defaultPrice,
            disputeTimerValue: defaultDisputeTime,
            uri: "ar://txid"
        });
    }

    function makePermit(address _owner, uint256 _nonce)
        internal
        view
        returns (SigUtils.Permit memory permit)
    {
        permit = SigUtils.Permit({
            owner: _owner,
            spender: diamondAddress,
            value: defaultPrice,
            nonce: _nonce,
            deadline: defaultPermitExpiration
        });
    }
}
