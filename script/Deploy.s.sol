// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {SelectorHelper} from "../test/utils/SelectorHelper.sol";

// diamond stuff
import {Diamond} from "diamond/Diamond.sol";
import {IDiamondCut} from "diamond/interfaces/IDiamondCut.sol";
import {OwnershipFacet} from "diamond/facets/OwnershipFacet.sol";
import {IDiamondLoupe} from "diamond/interfaces/IDiamondLoupe.sol";
import {DiamondCutFacet} from "diamond/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "diamond/facets/DiamondLoupeFacet.sol";

// app stuff
import {USDC} from "../src/mocks/USDC.sol";
import {Treasury} from "../src/dao/Treasury.sol";
import {ExchangeArgs} from "../src/BionetTypes.sol";
import {BionetInit, InitArgs} from "../src/BionetInit.sol";

// current facets
import {FromStorage} from "../src/facets/FromStorage.sol";
import {ServiceFacet} from "../src/facets/ServiceFacet.sol";
import {ExchangeFacet} from "../src/facets/ExchangeFacet.sol";

contract AnvilDeployScript is Script, SelectorHelper {
    // anvils default mnemonic
    string constant mnemonic =
        "test test test test test test test test test test test junk";

    // actors
    address buyer;
    address seller;
    address moderator;
    address deployer;

    // default USD balance. USD has 6 decimal places, e.g., 1 USD == 1e6
    uint256 constant defaultUSD = 10_000 * 1e6;

    // default protocol fee (2%)
    uint256 constant defaultProtocolFee = 200;

    /// Create 'users' from anvil and fund their accounts
    /// Deploy core contracts
    /// Mint some USDC to each user
    function setUp() public {
        // Note: actors use the following account indices: 1,2,3,4
        // We use actors here to mint USD to them
        buyer = vm.addr(vm.deriveKey(mnemonic, 1));
        seller = vm.rememberKey(vm.deriveKey(mnemonic, 2));
        moderator = vm.rememberKey(vm.deriveKey(mnemonic, 3));

        deployer = moderator = vm.rememberKey(vm.deriveKey(mnemonic, 4));
    }

    function run() public {
        vm.broadcast(deployer);

        // deploy treasure and stablecoin (mock). They are outside of diamond
        // address
        USDC usdc = new USDC();
        Treasury treasury = new Treasury(address(usdc));

        // fund the actors
        usdc.mint(buyer, defaultUSD);
        usdc.mint(seller, defaultUSD);
        usdc.mint(moderator, defaultUSD);

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
        address diamondAddress =
            address(new Diamond(address(this), address(dCutFacet)));

        // Deploy the init w/args
        BionetInit bInit = new BionetInit();
        InitArgs memory _args = InitArgs({
            treasury: address(treasury),
            usdc: address(usdc),
            protocolFee: defaultProtocolFee
        });
        // Encode the calldata
        bytes memory initCalldata =
            abi.encodeWithSignature("init((address,address,uint256))", _args);

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

        IDiamondCut(diamondAddress).diamondCut(cut, address(bInit), initCalldata);

        console.log("~ addresses: ~");
        console.log("USDC: %s", address(usdc));
        console.log("3 actors funded with 10,000 USDC");
        console.log("Treasury: %s", address(treasury));
        console.log("Diamond: %s", diamondAddress);
    }
}
