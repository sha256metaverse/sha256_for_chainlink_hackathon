// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin-contracts-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
contract layer1NFT is ERC721Upgradeable{
    address private ccipReceiver;
    mapping(uint256 => string) private uriByTokenId;

    function _initBrandNFT(string memory name, string memory symbol, address _ccipReceiver) public initializer {
        __ERC721_init(name, symbol);
        ccipReceiver = _ccipReceiver;
    }

    function mint(address _layer2Owner, uint256 _tokenId, string memory _tokenURI) public{
        require(msg.sender == ccipReceiver);
        _mint(_layer2Owner, _tokenId);
        uriByTokenId[_tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        return uriByTokenId[tokenId];
    }

    function checkReceiver() public view returns(address) {
        return ccipReceiver;
    }

}