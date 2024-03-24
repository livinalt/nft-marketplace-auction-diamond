// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC1155} from "../interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "../interfaces/IERC1155TokenReceiver.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MarketPlaceAcutionFacet is IERC1155TokenReceiver, IERC721Receiver {
    LibAppStorage.AppStorage internal l;
    LibAppStorage.Auction internal la;

    LibAppStorage.Auction[] public allAuctions;

    function marketPlaceName() external pure returns (string memory) {
        return "Auction NFT MarketPlace";
    }

    function createAuction(
        LibAppStorage.Categories _category,
        address _addressNFTCollection,
        address _addressPaymentToken,
        uint256 _nftTokenId,
        uint256 tokenAmount,
        uint256 _endAuction,
        uint256 _minBid
    ) external {
        require(
            _category == LibAppStorage.Categories.ERC721 ||
                _category == LibAppStorage.Categories.ERC1155 ||
                _category == LibAppStorage.Categories.Both,
            "AuctionMarketPlace: invalid category"
        );
        require(
            _endAuction > block.timestamp,
            "AuctionMarketPlace: endAuction must be in the future"
        );
        require(
            _minBid > 0,
            "AuctionMarketPlace: minBid must be greater than 0"
        );

        require(
            LibAppStorage.isContract(_addressNFTCollection),
            "AuctionMarketPlace: invalid NFT Collection address"
        );

        if (_category == LibAppStorage.Categories.ERC721) {
            IERC721 nftCollection = IERC721(_addressNFTCollection);

            require(
                nftCollection.ownerOf(_nftTokenId) == msg.sender,
                "AuctionMarketPlace: not owner of NFT"
            );

            // check if owner has approved the marketplace to transfer the NFT
            require(
                nftCollection.getApproved(_nftTokenId) == address(this),
                "AuctionMarketPlace: not approved to transfer NFT"
            );

            nftCollection.transferFrom(msg.sender, address(this), _nftTokenId);
        }

        if (_category == LibAppStorage.Categories.ERC1155) {
            IERC1155 nftCollection = IERC1155(_addressNFTCollection);

            require(
                nftCollection.balanceOf(msg.sender, _nftTokenId) > tokenAmount,
                "AuctionMarketPlace: Insufficient money"
            );

            nftCollection.safeTransferFrom(
                msg.sender,
                address(this),
                _nftTokenId,
                tokenAmount,
                ""
            );
        }

        // transfer the NFT to the marketplace

      
        address payable currentBidOwner = payable(address(0));

        // create the auction
        LibAppStorage.Auction memory auction = LibAppStorage.Auction({
            index: l.auctionIndex,
            category: _category,
            addressNFTCollection: _addressNFTCollection,
            addressPaymentToken: _addressPaymentToken,
            nftTokenId: _nftTokenId,
            tokenAmount: tokenAmount,
            auctionCreator: msg.sender,
            currentBidOwner: currentBidOwner,
            currentBidPrice: 0,
            endAuction: _endAuction,
            bidCount: 0,
            minBid: _minBid
        });

        // push the auction to the array
        allAuctions.push(auction);

        // increment the index
        l.auctionIndex++;

        // emit the event
        emit LibAppStorage.AuctionCreated(
            auction.index,
            auction.addressNFTCollection,
            auction.addressPaymentToken,
            auction.nftTokenId,
            auction.auctionCreator,
            auction.endAuction,
            auction.minBid
        );
    }

    // create function to check if auction is open
    function isAuctionOpen(uint256 _auctionIndex) public view returns (bool) {
        return allAuctions[_auctionIndex].endAuction > block.timestamp;
    }

    // get current bid price
    function getCurrentBidPrice(
        uint256 _auctionIndex
    ) external view returns (uint256) {
        return allAuctions[_auctionIndex].currentBidPrice;
    }

    // get current bid owner
    function getCurrentBidOwner(
        uint256 _auctionIndex
    ) external view returns (address) {
        return allAuctions[_auctionIndex].currentBidOwner;
    }

    // create function to place bid
    function placeBid(
        uint256 _auctionIndex,
        uint256 _bidAmount
    ) external returns (bool) {
        // check auction exists
        require(
            _auctionIndex < allAuctions.length,
            "AuctionMarketPlace: auction does not exist"
        );

        LibAppStorage.Auction storage auction = allAuctions[_auctionIndex];

        // check auction is open
        require(
            isAuctionOpen(_auctionIndex),
            "AuctionMarketPlace: auction is closed"
        );

        require(
            _bidAmount > auction.minBid,
            "AuctionMarketPlace: bid amount is less than minBid"
        );

        // checck if new bid is greater than current bid
        require(
            _bidAmount > auction.currentBidPrice,
            "AuctionMarketPlace: bid amount is less than current bid"
        );

        // check if the bidder is not the creator
        require(
            msg.sender != auction.auctionCreator,
            "AuctionMarketPlace: creator cannot bid"
        );

        // get the erc20 token
        IERC20 paymentToken = IERC20(auction.addressPaymentToken);

        if (auction.currentBidOwner == address(0)) {
            // require(
            //     paymentToken.allowance(msg.sender, address(this)) >= _bidAmount,
            //     "AuctionMarketPlace: not enough allowance to transfer"
            // );

            require(
                paymentToken.transferFrom(
                    msg.sender,
                    address(this),
                    _bidAmount
                ),
                "AuctionMarketPlace: failed to transfer bid amount"
            );
        }

        //if new bid is valid, transfer the previous bid amount to the previous bidder
        if (
            auction.currentBidOwner != address(0) && auction.currentBidPrice > 0
        ) {
            // do that calculation
            uint256 totalFee = calculateIncentiveTotalFee(
                auction.currentBidPrice
            );

            uint256 burned = calculateIncentiveBurned(totalFee);
            uint256 dao = calculateIncentiveDAO(totalFee);
            uint256 outbid = calculateIncentiveOutbid(totalFee);
            uint256 team = calculateIncentiveTeam(totalFee);
            uint256 lastAddress = calculateIncentiveLastAddress(totalFee);

            // total amount to debit
            uint256 totalDebit = totalFee + _bidAmount;

            // total amount to credit to previous bidder
            uint256 totalCredit = _bidAmount + outbid;

            // transfer the total amount to the diamond
            require(
                paymentToken.transferFrom(
                    msg.sender,
                    address(this),
                    totalDebit
                ),
                "AuctionMarketPlace: failed to transfer bid amount"
            );

            require(
                paymentToken.transfer(auction.currentBidOwner, totalCredit),
                "AuctionMarketPlace: failed to transfer previous bid amount"
            );


            require(
                paymentToken.transfer(address(0), burned),
                "AuctionMarketPlace: failed to burn"
            );

            // send dao share
            require(
                paymentToken.transfer(l.daoAddress, dao),
                "ActionMarketPlace: failed to transfer to DAO address"
            );

            // send team share
            require(
                paymentToken.transfer(l.teamAddress, team),
                "ActionMarketPlace: failed to transfer to Team address"
            );

            // send lastAddress
            require(
                paymentToken.transfer(l.lastInteractedAddress, lastAddress),
                "ActionMarketPlace: failed to transfer to last address"
            );
        }

        // update the current bid owner and price
        auction.currentBidOwner = payable(msg.sender);
        auction.currentBidPrice = _bidAmount;
        auction.bidCount++;

        // emit the event
        emit LibAppStorage.BidPlaced(_auctionIndex, msg.sender, _bidAmount);

        return true;
    }

    // create function for winner to claim NFT
    function claimNFT(uint256 _auctionIndex) external {
        // check auction exists
        require(
            _auctionIndex < allAuctions.length,
            "AuctionMarketPlace: auction does not exist"
        );

        LibAppStorage.Auction storage auction = allAuctions[_auctionIndex];

        // check auction is closed
        require(
            !isAuctionOpen(_auctionIndex),
            "AuctionMarketPlace: auction is still open"
        );

        // check if the caller is the winner
        require(
            msg.sender == auction.currentBidOwner,
            "AuctionMarketPlace: not the winner"
        );

        if (auction.category == LibAppStorage.Categories.ERC721) {
            // get the NFT collection
            IERC721 nftCollection = IERC721(auction.addressNFTCollection);

            // transfer the NFT to the winner
            nftCollection.transferFrom(
                address(this),
                msg.sender,
                auction.nftTokenId
            );
        }

        if (auction.category == LibAppStorage.Categories.ERC1155) {
            IERC1155 nftCollection = IERC1155(auction.addressNFTCollection);

            nftCollection.safeTransferFrom(
                msg.sender,
                address(this),
                auction.nftTokenId,
                auction.tokenAmount,
                ""
            );
        }

        // transfer the bid amount to the creator
        IERC20 paymentToken = IERC20(auction.addressPaymentToken);

        require(
            paymentToken.transfer(
                auction.auctionCreator,
                auction.currentBidPrice
            ),
            "AuctionMarketPlace: failed to transfer bid amount"
        );

        // emit the event
        emit LibAppStorage.NFTClaimed(
            _auctionIndex,
            msg.sender,
            auction.nftTokenId
        );
    }

    // create a function for creator to claim the token
    function claimToken(uint256 _auctionIndex) external {
        // check auction exists
        require(
            _auctionIndex < allAuctions.length,
            "AuctionMarketPlace: auction does not exist"
        );

        LibAppStorage.Auction storage auction = allAuctions[_auctionIndex];

        // check auction is closed
        require(
            !isAuctionOpen(_auctionIndex),
            "AuctionMarketPlace: auction is still open"
        );

        // check if the caller is the creator
        require(
            msg.sender == auction.auctionCreator,
            "AuctionMarketPlace: not the creator"
        );

        // get the NFT collection
        IERC721 nftCollection = IERC721(auction.addressNFTCollection);

        // transfer the NFT to the creator
        nftCollection.transferFrom(
            address(this),
            auction.currentBidOwner,
            auction.nftTokenId
        );

        // transfer the bid amount to the creator
        IERC20 paymentToken = IERC20(auction.addressPaymentToken);

        require(
            paymentToken.transfer(
                auction.auctionCreator,
                auction.currentBidPrice
            ),
            "AuctionMarketPlace: failed to transfer bid amount"
        );

        // emit the event
        emit LibAppStorage.TokenClaimed(
            _auctionIndex,
            msg.sender,
            auction.nftTokenId
        );
    }

    // create a function to end to collect your nft back after auction has ended and no bids
    function refund(uint256 _auctionIndex) external {
        // check auction exists
        require(
            _auctionIndex < allAuctions.length,
            "AuctionMarketPlace: auction does not exist"
        );

        LibAppStorage.Auction storage auction = allAuctions[_auctionIndex];

        // check auction is closed
        require(
            !isAuctionOpen(_auctionIndex),
            "AuctionMarketPlace: auction is still open"
        );

        // check if the caller is the creator
        require(
            msg.sender == auction.auctionCreator,
            "AuctionMarketPlace: not the creator"
        );

        //  check bidder count and currrent Bid Owner is 0
        require(
            auction.bidCount == 0 && auction.currentBidOwner == address(0),
            "AuctionMarketPlace: auction has bids"
        );

        // get the NFT collection
        IERC721 nftCollection = IERC721(auction.addressNFTCollection);

        // transfer the NFT to the creator
        nftCollection.transferFrom(
            address(this),
            auction.auctionCreator,
            auction.nftTokenId
        );

        // emit the event
        emit LibAppStorage.NFTRefund(
            _auctionIndex,
            msg.sender,
            auction.nftTokenId
        );
    }

    // calculate incentive
    //     if an NFT is auction and a bidder A bids 50 AUC erc tokens, the tokens are trnasferred to the diamond, if he is outbid, his tokens are transferred back with an incentive calculated below

    // 10% of highestBid==totalFee

    // 2% of totalFee is burned
    // 2% of totalFee is sent to a random DAO address(just random)
    // 3% goes back to the outbid bidder
    // 2% goes to the team wallet(just random)
    // 1% is sent to the last address to interact with AUCToken(write calls like transfer,transferFrom,approve,mint etc)
    function calculateIncentiveTotalFee(
        uint256 _highestBid
    ) private pure returns (uint256) {
        uint256 totalFee = (_highestBid * 10) / 100;
        return totalFee;
    }

    // function to amount to be burned
    function calculateIncentiveBurned(
        uint256 _totalFee
    ) private pure returns (uint256) {
        uint256 burned = (_totalFee * 2) / 100;
        return burned;
    }

    // function to amount to be sent to dAO address
    function calculateIncentiveDAO(
        uint256 _totalFee
    ) private pure returns (uint256) {
        uint256 dao = (_totalFee * 2) / 100;
        return dao;
    }

    // function to amount to be sent to outbid bidder
    function calculateIncentiveOutbid(
        uint256 _totalFee
    ) private pure returns (uint256) {
        uint256 outbid = (_totalFee * 3) / 100;
        return outbid;
    }

    // function to amount to be sent to team wallet
    function calculateIncentiveTeam(
        uint256 _totalFee
    ) private pure returns (uint256) {
        uint256 team = (_totalFee * 2) / 100;
        return team;
    }

    // function to amount to be sent to last address to interact with AUCToken
    function calculateIncentiveLastAddress(
        uint256 _totalFee
    ) private pure returns (uint256) {
        uint256 lastAddress = (_totalFee * 1) / 100;
        return lastAddress;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address /* _operator */,
        address /* _from */,
        uint256 /* _id */,
        uint256 /* _value */,
        bytes calldata /* _data */
    ) external pure override returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    function onERC1155BatchReceived(
        address /* _operator */,
        address /* _from */,
        uint256[] calldata /* _ids */,
        uint256[] calldata /* _values */,
        bytes calldata /* _data */
    ) external pure override returns (bytes4) {
        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }
}
