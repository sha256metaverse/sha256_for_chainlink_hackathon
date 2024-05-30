// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin-contracts-upgradeable/contracts/utils/cryptography/MerkleProofUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable/contracts/utils/cryptography/ECDSAUpgradeable.sol";

contract layer2NFT is ERC721EnumerableUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    event Mint(address indexed to, uint256 indexed tokenId);
    event Burn(address indexed from, uint256 indexed tokenId);
    event TransferNFT(address indexed from, address indexed to, uint256 indexed tokenId);

    address public sha256Factory;
    
    address public mintableOperator;

    string public brandName;

    uint256 public brandInitialNumber;

    mapping(bytes32 => bool) private wasVerified;

    mapping(bytes32 => ClothingInfo) private clothingInfo;

    mapping(uint256 => ClothingInfo) private clothingInfoByTokenId;

    mapping(bytes32 => address) private mintable;

    mapping(uint256 => uint256) private transferNonce;

    mapping(uint256 => mapping(uint256 => SecondHand)) private productCondition;

    struct SecondHand {
        address currentOwner;
        uint256 timeStamp;
    }

    struct ClothingInfo {

        string clothingSeriesName;

        bool hasLimitedSupply;

        uint256 clothingInitialNumber;        

        uint256 maxSupply;

        uint256 mintedAmount;        

        uint256 mintTimestamp;

        uint256 SeriesCreatedTime;

        uint256 tokenId;

        bytes32 merkleLeaf;

        bytes32 merkleRoot;

        string merkleTreeIpfsAddress;

        string tokenURI;

        refundPolicy refund;
    }

    enum refundPolicy {
        noRefunds,
        refundable
    }

    function _initBrandNFT(string memory _brandName, string memory nftName, string memory nftSymbol, address owner, address _mintableOperator) public initializer {
        __ERC721_init(nftName, nftSymbol);
        brandName = _brandName;
        sha256Factory = msg.sender;
        mintableOperator = _mintableOperator;
        _transferOwnership(owner);
    }

    function merkleProof(bytes32 clothingToken, bytes32[] calldata _merkleProof, bytes32 _merkleRoot) public pure returns(bool) {
        bytes32 leaf = sha256(abi.encodePacked(clothingToken));
        return MerkleProofUpgradeable.verify(_merkleProof, _merkleRoot, leaf);
    }

    function calculateMerkleRoot(bytes32 clothingToken, bytes32[] calldata _merkleProof) public pure returns(bytes32) {
        bytes32 leaf = sha256(abi.encodePacked(clothingToken));
        return MerkleProofUpgradeable.processProof(_merkleProof, leaf);
    }

    function listNewClothing(refundPolicy _refund, string memory _clothingSeriesName, uint256 _maxSupply, bytes32 _merkleRoot, string memory _merkleTreeIpfsAddress, string memory _tokenURI) public onlyOwner {
        require(bytes(_clothingSeriesName).length > 0, "Brand proxy: Clothing name cannot be empty");
        require(bytes(clothingInfo[_merkleRoot].clothingSeriesName).length == 0, "Brand proxy: Batch already registered");
        clothingInfo[_merkleRoot] = ClothingInfo(_clothingSeriesName, false, brandInitialNumber, _maxSupply, 0, 0, block.timestamp, 0, bytes32(0), _merkleRoot, _merkleTreeIpfsAddress, _tokenURI, _refund);
        brandInitialNumber += _maxSupply;
    }

    function listNewLimitedClothing(refundPolicy _refund, string memory _clothingSeriesName, uint256 _maxSupply, bytes32 _merkleRoot, string memory _merkleTreeIpfsAddress, string memory _tokenURI) public onlyOwner {
        require(bytes(_clothingSeriesName).length != 0, "Brand proxy: Clothing name cannot be empty");
        require(bytes(clothingInfo[_merkleRoot].clothingSeriesName).length == 0, "Brand proxy: Batch already registered");
        clothingInfo[_merkleRoot] = ClothingInfo(_clothingSeriesName, true, brandInitialNumber, _maxSupply, 0, 0, block.timestamp, 0, bytes32(0), _merkleRoot, _merkleTreeIpfsAddress, _tokenURI, _refund);
        brandInitialNumber += _maxSupply;
    }

    function restockClothing(uint256 _maxSupply, bytes32 oldMerkleRoot, bytes32 _merkleRootUpdate, string memory _merkleTreeIpfsAddressUpdate) public onlyOwner {
        require(bytes(clothingInfo[_merkleRootUpdate].clothingSeriesName).length == 0, "Brand proxy: New batch has already been registered");
        ClothingInfo memory clothingInfoCache = clothingInfo[oldMerkleRoot];
        require(bytes(clothingInfoCache.clothingSeriesName).length != 0, "Brand proxy: Clothing name cannot be empty");
        require(!clothingInfoCache.hasLimitedSupply, "Brand proxy: Batch is limited edition, cannot add products");
        require(bytes(clothingInfoCache.clothingSeriesName).length != 0, "Brand proxy: Old batch is not registered");
        clothingInfoCache.maxSupply += _maxSupply;
        clothingInfoCache.merkleRoot = _merkleRootUpdate;
        clothingInfoCache.merkleTreeIpfsAddress = _merkleTreeIpfsAddressUpdate;
        clothingInfoCache.clothingInitialNumber = brandInitialNumber;
        clothingInfoCache.mintedAmount = 0;
        clothingInfo[_merkleRootUpdate] = clothingInfoCache;
        brandInitialNumber += _maxSupply;

    }

    function mintClothingNFT(bytes32 clothingToken, bytes32[] calldata _merkleProof) public nonReentrant {
        bytes32 _merkleRoot = calculateMerkleRoot(clothingToken, _merkleProof);
        bytes32 leaf = sha256(abi.encodePacked(clothingToken));
        ClothingInfo memory clothingInfoCache = clothingInfo[_merkleRoot];
        require(!wasVerified[leaf], "Brand proxy: Already verified");
        require(bytes(clothingInfoCache.clothingSeriesName).length != 0, "Brand proxy: Clothing name cannot be empty");
        require(merkleProof(clothingToken, _merkleProof, clothingInfoCache.merkleRoot), "Brand proxy: Merkle tree verification failed");
        require(clothingInfoCache.mintedAmount < clothingInfoCache.maxSupply, "Brand proxy: Exceeds maximum supply");
        if(clothingInfoCache.refund == refundPolicy.refundable) {
            require(mintable[leaf] == msg.sender, "Brand proxy: No minting permission");
        }
        uint256 _tokenId = clothingInfoCache.clothingInitialNumber + clothingInfoCache.mintedAmount;
        _safeMint(msg.sender, _tokenId);
        // clothingInfo[_merkleRoot].mintTimestamp = block.timestamp;
        clothingInfoCache.mintTimestamp = block.timestamp;

        // clothingInfo[_merkleRoot].tokenId = _tokenId;
        clothingInfoCache.tokenId = _tokenId;

        clothingInfo[_merkleRoot].mintedAmount += 1;
        clothingInfoCache.mintedAmount += 1;

        clothingInfoCache.merkleLeaf = leaf;
        clothingInfoByTokenId[_tokenId] = clothingInfoCache;

        productCondition[_tokenId][0].timeStamp = block.timestamp;

        wasVerified[leaf] = true;
        emit Mint(msg.sender, _tokenId);
    }

    function changeMintableOperator(address newOperator) public {
        require(msg.sender == mintableOperator, "Brand proxy: No operation permission");
        mintableOperator = newOperator;
    }

    function setMintableUser(address mintableUser, bytes32 leaf) public {
        require(!wasVerified[leaf], "Brand proxy: Already verified");
        require(mintable[leaf] == address(0), "Brand proxy: Already authorized");
        require(msg.sender == mintableOperator, "Brand proxy: No operation permission");
        mintable[leaf] = mintableUser;
    }

    function changeMintableUser(address newMintableUser, bytes32 _clothingToken) public {
        bytes32 leaf = sha256(abi.encodePacked(_clothingToken));
        require(!wasVerified[leaf], "Brand proxy: Already verified");
        require(mintable[leaf] == msg.sender, "Brand proxy: No operation permission");
        mintable[leaf] = newMintableUser;
    }

    function disableMintableUser(bytes32 _clothingToken) public {
        bytes32 leaf = sha256(abi.encodePacked(_clothingToken));
        require(msg.sender == mintableOperator, "Brand proxy: No operation permission");
        require(mintable[leaf] != address(0), "Brand proxy: Not authorized");
        require(!wasVerified[leaf], "Brand proxy: Already verified");
        delete mintable[leaf];
    }
    function clothingTokenWasVerified(bytes32 _clothingToken) view public returns(bool) {
        bytes32 leaf = sha256(abi.encodePacked(_clothingToken));
        return wasVerified[leaf];
    }

    function clothingInfoByRoot(bytes32 _root) public view returns(ClothingInfo memory) {
        return clothingInfo[_root];
    }

    function checkTokenRangeByMerkleRoot(bytes32 _root) public view returns(uint256[] memory) {
        uint256 _clothingInitialNumber = clothingInfo[_root].clothingInitialNumber;
        uint256 _maxSupply = clothingInfo[_root].maxSupply;
        uint256[] memory range = new uint256[](2);
        range[0] = _clothingInitialNumber;
        range[1] = _clothingInitialNumber + _maxSupply - 1;
        return range;
    }

    function checkClothingInfoByTokenId(uint256 _tokenId) public view returns(ClothingInfo memory) {
        _requireMinted(_tokenId);
        return clothingInfoByTokenId[_tokenId];
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        _requireMinted(_tokenId);
        return clothingInfoByTokenId[_tokenId].tokenURI;
    }

    function transferNFTWithVerification(address from, address to, uint256 tokenId, bytes32 messageHash0, bytes memory signature0, bytes32 messageHash1, bytes memory signature1) public {
        transferNFTWithVerification(from, to, tokenId, messageHash0, signature0, messageHash1, signature1, false);
    }

    function transferNFTWithVerification(address from, address to, uint256 tokenId, bytes32 messageHash0, bytes memory signature0, bytes32 messageHash1, bytes memory signature1, bool useSafeTransferFrom) public {
        _transferNFTWithVerification(from, to, tokenId, messageHash0, signature0, messageHash1, signature1, useSafeTransferFrom);
    }

    function _transferNFTWithVerification(address from, address to, uint256 tokenId, bytes32 messageHash0, bytes memory signature0, bytes32 messageHash1, bytes memory signature1, bool useSafeTransferFrom) public {
        require(ownerOf(tokenId) == from, "Brand proxy: From address does not own the token");
        uint256 _transferNounce = transferNonce[tokenId];
        address buyerAddress = ECDSAUpgradeable.recover(messageHash0, signature0);
        address sellerAddress = ECDSAUpgradeable.recover(messageHash1, signature1);
        bytes32 buildMessageHash = keccak256(abi.encodePacked(address(this), tokenId, _transferNounce));
        require(to == buyerAddress && from == sellerAddress, "Brand proxy: Address verification failed");
        require(ECDSAUpgradeable.toEthSignedMessageHash(buildMessageHash) == messageHash0 && messageHash0 == messageHash1, "Brand proxy: Message verification failed");

        if (useSafeTransferFrom) {
            _safeTransfer(from, to, tokenId, "");
        } else {
            _transfer(from, to, tokenId);
        }
        transferNonce[tokenId]++;
        productCondition[tokenId][transferNonce[tokenId]].currentOwner = to;
        productCondition[tokenId][transferNonce[tokenId]].timeStamp = block.timestamp;
        emit TransferNFT(from, to, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
        productCondition[tokenId][transferNonce[tokenId]].currentOwner = address(0);
        productCondition[tokenId][transferNonce[tokenId]].timeStamp = block.timestamp;
    }

    function approve(address to, uint256 tokenId) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        revert("ERC721 public approve not allowed");
    }

    function getApproved(uint256 tokenId) public view virtual override(ERC721Upgradeable, IERC721Upgradeable) returns (address) {
        require(_exists(tokenId), "ERC721: invalid token ID");
        return address(0);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        revert("ERC721 public setApprovalForAll not allowed");
    }

    function isApprovedForAll(address owner, address operator) public view virtual override(ERC721Upgradeable, IERC721Upgradeable) returns (bool) {
        return false;
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        revert("ERC721 public transferFrom not allowed");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        revert("ERC721 public safeTransferFrom not allowed");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override(ERC721Upgradeable, IERC721Upgradeable) {
        revert("ERC721 public safeTransferFrom not allowed");
    }
}