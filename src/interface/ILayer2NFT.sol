// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ILayer2NFT {

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
    }

    function merkleProof(bytes32 clothingToken, bytes32[] calldata _merkleProof, bytes32 _merkleRoot) external pure returns(bool);

    function calculateMerkleRoot(bytes32 clothingToken, bytes32[] calldata _merkleProof) external pure returns(bytes32);

    function listNewClothing(string memory _clothingSeriesName, uint256 _maxSupply, bytes32 _merkleRoot, string memory _merkleTreeIpfsAddress, string memory _tokenURI) external;

    function listNewLimitedClothing(string memory _clothingSeriesName, uint256 _maxSupply, bytes32 _merkleRoot, string memory _merkleTreeIpfsAddress, string memory _tokenURI) external;

    function restockClothing(uint256 _maxSupply, bytes32 oldMerkleRoot, bytes32 _merkleRootUpdate, string memory _merkleTreeIpfsAddressUpdate) external;

    function mintClothingNFT(bytes32 clothingToken, bytes32[] calldata _merkleProof) external;

    function clothingTokenWasVerified(bytes32 _clothingToken) external view returns(bool);

    function clothingInfoByRoot(bytes32 _root) external view returns(ClothingInfo memory);

    function checkClothingNameByMerkleRoot(bytes32 _root) external view returns(string memory);

    function checkClothingInfoByTokenId(uint256 _tokenId) external view returns(ClothingInfo memory);

    function tokenURI(uint256 _tokenId) external view returns (string memory);

    function registerCampion(address campion) external;

    function callWithCampion(address campion) external;

    function mintWithCampion(address campion, bytes32 clothingToken, bytes32[] calldata _merkleProof) external;

    function checkIsCampionRegistered(address campion) external view returns(bool);
}
