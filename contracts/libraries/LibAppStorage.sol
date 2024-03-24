// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibERC20} from "./LibERC20.sol";

library LibAppStorage {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    struct AppStorage {
        //ERC20
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        // AUCTION MARKETPLACE
        uint256 auctionIndex;
        address daoAddress;
        address teamAddress;
        address lastInteractedAddress;
    }

    enum Categories {
        ERC721,
        ERC1155,
        Both
    }

    struct Auction {
        uint256 index;
        Categories category;
        address addressNFTCollection;
        address addressPaymentToken;
        uint256 nftTokenId;
        uint256 tokenAmount;
        address auctionCreator;
        address payable currentBidOwner;
        uint256 currentBidPrice;
        uint256 endAuction;
        uint256 bidCount;
        uint256 minBid;
    }

    // event to notify when a new auction is created
    event AuctionCreated(
        uint256 index,
        address addressNFTCollection,
        address addressPaymentToken,
        uint256 nftTokenId,
        address auctionCreator,
        uint256 endAuction,
        uint256 minBid
    );

    // event to notify when a new bid is placed
    event BidPlaced(uint256 index, address bidder, uint256 bidAmount);

    // event to notify when an auction is ended
    event AuctionEnded(uint256 index, address winner, uint256 bidAmount);

    // event when winner claims the NFT
    event NFTClaimed(uint256 index, address winner, uint256 nftTokenId);

    // event when auction creator claims the the token
    event TokenClaimed(
        uint256 index,
        address auctionCreator,
        uint256 nftTokenId
    );

    // event where NFT is transferred to the creator
    event NFTRefund(uint256 index, address auctionCreator, uint256 nftTokenId);

    function isContract(
        address _addr
    ) internal view returns (bool addressCheck) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        addressCheck = (size > 0);
    }

    function getStorage() internal pure returns (AppStorage storage l) {
        assembly {
            l.slot := 0
        }
    }

    // ERC20
    function _transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        AppStorage storage l = getStorage();
        uint256 frombalances = l.balances[msg.sender];
        require(
            frombalances >= _amount,
            "ERC20: Not enough tokens to transfer"
        );
        l.balances[_from] = frombalances - _amount;
        l.balances[_to] += _amount;
        emit Transfer(_from, _to, _amount);
    }
}
