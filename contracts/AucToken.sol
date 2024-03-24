// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

import "../contracts/libraries/LibAppStorage.sol";

contract AucToken {
    LibAppStorage.AppStorage internal s;

    uint256 _tokenIds;

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Approval(address indexed from, address indexed to, uint256 tokenId);

    function name() public pure returns (string memory) {
        return "AucToken";
    }

    function symbol() public pure returns (string memory) {
        return "ACT";
    }

    function approve(address _to, uint256 _tokenId) external {
        require(_to != address(0), "ERC721: Approval to the zero address");
        require(
            s.owners[_tokenId] == msg.sender,
            "ERC721: approve caller is not owner"
        );

        s.tokenApprovals[_tokenId] = _to;

        emit Approval(msg.sender, _to, _tokenId);
    }

    function balanceOf(address _user) public view returns (uint256) {
        return s.balances[_user];
    }

    function ownerOf(uint256 _tokenId) public view returns (address) {
        return s.owners[_tokenId];
    }

    function getApproved(uint256 _tokenId) public view returns (address) {
        return s.tokenApprovals[_tokenId];
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external {
        _transfer(_from, _to, _tokenId);
    }

    function transfer(address _to, uint256 _tokenId) external {
        _transfer(msg.sender, _to, _tokenId);
    }

    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        require(
            _from != address(0),
            "ERC721: transfer of token that is not own"
        );
        require(_to != address(0), "ERC721: transfer to the zero address");
        require(
            s.owners[_tokenId] == msg.sender ||
                s.tokenApprovals[_tokenId] == msg.sender,
            "ERC721: transfer caller is not owner nor approved"
        );
        require(
            s.owners[_tokenId] == _from,
            "ERC721: transfer of token that is not own"
        );
        s.tokenApprovals[_tokenId] = address(0);
        s.owners[_tokenId] = _to;
        s.balances[_from]--;
        s.balances[_to]++;
        emit Transfer(_from, _to, _tokenId);
    }

    /// @notice Generates an SVG image for a given tokenID
    /// @param _tokenId The tokenID of the NFT
    /// @return The SVG image as a base64 encoded string
    function _generateNFT(
        uint256 _tokenId
    ) internal pure returns (string memory) {
        bytes memory svg = abi.encodePacked(
            '<svg id="sw-js-blob-svg" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">',
            '<defs><linearGradient id="sw-gradient"><stop id="stop1" stop-color="rgb(248, 117, 55)" offset="0%"></stop><stop id="stop2" stop-color="rgb(251, 168, 31)" offset="100%"></stop></linearGradient></defs>',
            '<path fill="url(#sw-gradient)" d="M 17.5 -19.2 C 25 -14.5 35.1 -11.2 37.9 -5.2 C 40.7 0.7 36.1 9.5 30.4 15.7 C 24.6 22 17.7 25.8 10.8 27.3 C 3.9 28.8 -3 28 -10 26.1 C -16.9 24.1 -24 21 -29.9 15.1 C -35.8 9.3 -40.5 0.7 -38.3 -5.9 C -36.2 -12.5 -27.1 -16.9 -19.5 -21.7 C -12 -26.4 -6 -31.5 -0.5 -30.8 C 5 -30.2 9.9 -24 17.5 -19.2 Z" transform="matrix(1,0,0,1,50,50)" style="transition: all 0.3s ease 0s" stroke="url(#sw-gradient)"></path>',
            '<text font-size="12" x="25" y="50" fill="rgb(255, 255, 255)">',
            Strings.toString(_tokenId),
            "</text></svg>"
        );

        return
            string(
                abi.encodePacked(
                    "data:image/svg+xml;base64,",
                    Base64.encode(svg)
                )
            );
    }

    /// @notice Returns the tokenURI for a given tokenID
    /// @param _tokenId The tokenID of the NFT
    function getTokenURI(uint256 _tokenId) public pure returns (string memory) {
        string memory id = Strings.toString(_tokenId);
        bytes memory dataURI = abi.encodePacked(
            "{",
            '"name": "DevFarunaNFT #',
            id,
            '",',
            '"description": "DevFaruna giving out free NFTs ',
            id,
            '",',
            '"image": "',
            _generateNFT(_tokenId),
            '"',
            "}"
        );
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }

    function _setTokenURI(uint256 _tokenId, string memory _tokenURI) internal {
        s.tokenURI[_tokenId] = _tokenURI;
    }

    /// @notice Mints an NFT with a unique tokenURI
    /// @dev Increments the tokenID and mints an NFT with the tokenURI
    function mint() public payable {
        require(msg.value >= 1e16, "Not enough mint fee");
        _safeMint(msg.sender, _tokenIds);
        _setTokenURI(_tokenIds, getTokenURI(_tokenIds));

        _tokenIds = _tokenIds + 1;
    }

    function _safeMint(address _to, uint256 _tokenId) internal {
        s.owners[_tokenId] = _to;
        s.balances[_to] = s.balances[_to] + 1;

        emit Transfer(address(0), _to, _tokenId);
    }
}
