// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface ILayer1NFT {

    function mint(address _layer2Owner, uint256 _tokenId, string memory _tokenURI) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);
}
