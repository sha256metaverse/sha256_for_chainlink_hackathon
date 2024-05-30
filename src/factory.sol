// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interface/ILayer2NFT.sol";
import "./interface/ILayer1NFT.sol";

contract FactoryContract is Ownable{
    address public ccipReceiver;
    address public layer1NFTAddress;
    address public layer2NFTAddress;

    address public ccipDeployer;
    address public implementationDeployer;

    mapping(bytes32 => address) private brandContracts;
    mapping(address => bool) private isBrandRegistered;
    address[] public allBrands;
    event BrandRegistered(address indexed brandName);

    constructor(address _ccipDeployer, address _implementationDeployer) {
        ccipDeployer = _ccipDeployer;
        implementationDeployer = _implementationDeployer;
    }

    function createNewContract(string memory _brandName, string memory nftName, string memory nftSymbol, address brandOwner, address mintableOperator) public onlyOwner returns(TransparentUpgradeableProxy brandProxy) {
        require(checkLength(_brandName) && checkLength(nftName) && checkLength(nftSymbol), "SHA256-factroy: Name exceeds specified length");
        bytes32 brandHash = keccak256(abi.encodePacked(_brandName));
        address brandContract = brandContracts[brandHash];
        require(!isBrandRegistered[brandContract], "SHA256-factroy: Brand already registered");
        bytes memory initCode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(address(this), address(this), new bytes(0))
        );
        bytes32 salt = brandHash;
        assembly {
            brandProxy := create2(0, add(initCode, 32), mload(initCode), salt)
        }

        if(block.chainid != 1) {
            require(layer2NFTAddress != address(0), "SHA256-factroy: Layer2 logic contract does not exist");
            brandProxy.upgradeTo(layer2NFTAddress);
            brandProxy.changeAdmin(address(0xdead));
            (bool success, ) = address(brandProxy).call(
                abi.encodeWithSelector(
                    bytes4(keccak256("_initBrandNFT(string,string,string,address,address)")),
                    _brandName,
                    nftName,
                    nftSymbol,
                    brandOwner,
                    mintableOperator
                )
            );
            require(success, "SHA256-factroy: Initialization failed");
        }

        else {
            require(ccipReceiver != address(0), "SHA256-factroy: Cross-chain contract does not exist");
            require(layer1NFTAddress != address(0), "SHA256-factroy: Layer1 logic contract does not exist");
            brandProxy.upgradeTo(layer1NFTAddress);
            brandProxy.changeAdmin(address(0xdead));
            (bool success, ) = address(brandProxy).call(
                abi.encodeWithSelector(
                    bytes4(keccak256("_initBrandNFT(string,string,address)")),
                    nftName,
                    nftSymbol,
                    ccipReceiver
                )
            );
            require(success, "SHA256-factroy: Initialization failed");
        }

        isBrandRegistered[address(brandProxy)] = true;
        brandContracts[brandHash] = address(brandProxy);
        allBrands.push(address(brandProxy));
        emit BrandRegistered(address(brandProxy));
    }

    function setCcipReceiver(address _ccipReceiver) public {
        require(msg.sender == ccipDeployer, "SHA256-factroy: No operation permission");
        ccipReceiver = _ccipReceiver;
    }

    function setLayer2Implementation(address _layer2NFTAddress) public {
        require(msg.sender == implementationDeployer, "SHA256-factroy: No operation permission");
        layer2NFTAddress = _layer2NFTAddress;
    }

    function setLayer1Implementation(address _layer1NFTAddress) public {
        require(msg.sender == implementationDeployer, "SHA256-factroy: No operation permission");
        layer1NFTAddress = _layer1NFTAddress;
    }

    function getBrandContract(string memory _brandName) public view returns (address) {
        bytes32 brandHash = keccak256(abi.encodePacked(_brandName));
        address brandContract = brandContracts[brandHash];
        require(isBrandRegistered[brandContract] && brandContract != address(0), "SHA256-factroy: Brand not registered");
        return brandContract;
    }

    function checkLength(string memory _string) private pure returns(bool) {
        return bytes(_string).length > 0 && bytes(_string).length <= 32;
    }

}