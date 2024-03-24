// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";

import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/MarketPlaceAcutionFacet.sol";

import "../contracts/AucToken.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/libraries/LibAppStorage.sol";

contract DiamondDeployer is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC20Facet erc20Facet;
    MarketPlaceAcutionFacet aFacet;
    AucToken nft;

    address A = address(0xa);
    address B = address(0xb);
    address C = address(0xc);
    address D = address(0xd);
    address DAO = address(0xda);
    address TEAM = address(0xea);

    MarketPlaceAcutionFacet boundAuctionMarketPlace;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20Facet = new ERC20Facet();
        aFacet = new MarketPlaceAcutionFacet();
        nft = new AucToken();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );

        cut[2] = (
            FacetCut({
                facetAddress: address(aFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("MarketPlaceAcutionFacet.sol")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(erc20Facet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC20Facet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        DAO = mkaddr("dao address");
        TEAM = mkaddr("team address");

        // set address
        diamond.setDAoAddress(address(DAO));
        diamond.setTeamAddress(address(TEAM));

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();

        A = mkaddr("user a");
        B = mkaddr("user b");
        C = mkaddr("user c");
        D = mkaddr("user d");

        // mint AUC tokens
        ERC20Facet(address(diamond)).mintTo(A);
        ERC20Facet(address(diamond)).mintTo(B);
        ERC20Facet(address(diamond)).mintTo(C);
        ERC20Facet(address(diamond)).mintTo(D);

        // bind the auction market place
        boundAuctionMarketPlace = MarketPlaceAcutionFacet.sol(address(diamond));
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function testERC20Facet() public {
        switchSigner(A);
        uint256 bal = ERC20Facet(address(diamond)).balanceOf(A);
        console.log("balance of A", bal);
        console.log("address of ERC20Facet", address(erc20Facet));
    }

    function testERC721() public {
        switchSigner(A);
        nft.mint();
        switchSigner(B);
        nft.mint();
        nft.mint();

        nft.approve(A, 1);

        switchSigner(A);
        nft.transferFrom(B, C, 1);

        switchSigner(C);

        console.log("Owner of 1", nft.ownerOf(1));

        assertEq(C, nft.ownerOf(1));
    }

    function testAuctionMarketPlaceName() public {
        string memory marketPlaceName = boundAuctionMarketPlace
            .marketPlaceName();

        assertEq(marketPlaceName, "Auction NFT MarketPlace");
    }

    // test create auction
    function testCreateAuction() public {
        uint256 currentNftTokenId = nft._tokenIds();
        console.log("currentNftTokenId==========>", currentNftTokenId);

        switchSigner(A);

        nft.mint();

        vm.warp(3e7);

        uint256 currentTimestamp = block.timestamp;
        uint256 endAuction = currentTimestamp + 3600;
        // uint256 approveAmount = 100000;

        console.log("endAuction==========>", endAuction);

        console.log("owner", nft.ownerOf(0));

        //approve boundAuctionMarketPlace to spend transfer nft
        nft.approve(address(boundAuctionMarketPlace), currentNftTokenId);

      
        boundAuctionMarketPlace.createAuction(
            LibAppStorage.Categories.ERC721,
            address(nft),
            address(erc20Facet),
            currentNftTokenId,
            2000,
            endAuction,
            100
        );

        uint256 auctionBidPrice = boundAuctionMarketPlace.getCurrentBidPrice(0);
        address currentBidOwner = boundAuctionMarketPlace.getCurrentBidOwner(0);
        // LibAppStorage.Auction storage a = boundAuctionMarketPlace.getAuctionDetails(0);

        assertEq(auctionBidPrice, 0);
        assertEq(currentBidOwner, address(0));
    }

    // test creation and auction and also test for placing of bid
    function testCreateAuctionAndMultipleBid() public {
        uint256 currentNftTokenId = nft._tokenIds();
        console.log("currentNftTokenId==========>", currentNftTokenId);

        switchSigner(A);

        nft.mint();

        vm.warp(10e7);

        uint256 currentTimestamp = block.timestamp;
        uint256 endAuction = currentTimestamp + 3600;

        console.log("owner", nft.ownerOf(currentNftTokenId));

        nft.approve(address(boundAuctionMarketPlace), currentNftTokenId);

        boundAuctionMarketPlace.createAuction(
            LibAppStorage.Categories.ERC721,
            address(nft),
            address(erc20Facet),
            currentNftTokenId,
            2000,
            endAuction,
            100
        );

        switchSigner(B);

        //approve boundAuctionMarketPlace to spend tokens
        ERC20Facet(address(diamond)).approve(
            address(boundAuctionMarketPlace),
            4000e18
        );

        // check allowance of diamond with signerB
        console.log("ALLOWANCE==>", ERC20Facet(address(diamond)).allowance(B, address(boundAuctionMarketPlace)));

        boundAuctionMarketPlace.placeBid(0, 2000);

    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
