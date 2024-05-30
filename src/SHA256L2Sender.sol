// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IRouterClient} from "contracts-ccip@0.7.6/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "contracts-ccip@0.7.6/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "contracts-ccip@0.7.6/v0.8/ccip/libraries/Client.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SHA256L2Sender is OwnerIsCreator{
    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); // Used to make sure contract has enough balance to cover the fees.
    error DestinationChainNotAllowlisted(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.

    // Event emitted when a message is sent to another chain.
    event MessageSent(
        bytes32 indexed messageId, // The unique ID of the CCIP message.
        uint64 indexed destinationChainSelector, // The chain selector of the destination chain.
        address receiver, // The address of the receiver on the destination chain.
        bytes message, // The message being sent.
        address feeToken, // the token address used to pay CCIP fees.
        uint256 fees // The fees paid for sending the CCIP message.
    );

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedChains;
    mapping(address => bool) public brandRegistered;
    IRouterClient private s_router;
    IERC20 private  s_linkToken;
    Client.EVMExtraArgsV1 private extraArgs;

    constructor(address _router, address _link, uint256 _gasLimit, bool _strict) {
        s_router = IRouterClient(_router);
        s_linkToken = IERC20(_link);
        setExtraArgs(_gasLimit, _strict);
    }
    /// @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted.
    /// @param _destinationChainSelector The selector of the destination chain.
    modifier onlyAllowlistedChain(uint64 _destinationChainSelector) {
        if (!allowlistedChains[_destinationChainSelector])
            revert DestinationChainNotAllowlisted(_destinationChainSelector);
        _;
    }

    /// @dev Updates the allowlist status of a destination chain for transactions.
    /// @notice This function can only be called by the owner.
    /// @param _destinationChainSelector The selector of the destination chain to be updated.
    /// @param allowed The allowlist status to be set for the destination chain.
    function allowlistDestinationChain(
        uint64 _destinationChainSelector,
        bool allowed
    ) external onlyOwner {
        allowlistedChains[_destinationChainSelector] = allowed;
    }
    function registerBrand(address brandContract) public onlyOwner {
        require(!brandRegistered[brandContract]);
        brandRegistered[brandContract] = true;
    }

    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        address NFTAddress,
        address NFTOwner,
        uint256 tokenId,
        string memory tokenURI
    )
        external
        onlyAllowlistedChain(_destinationChainSelector)
        returns (bytes32 messageId)
    {

        require(brandRegistered[NFTAddress]);
        IERC721 brandContract = IERC721(NFTAddress);
        require(brandContract.ownerOf(tokenId) == NFTOwner);
        // 这里和可变gas有关
        bytes memory mintMessage = abi.encodeWithSignature("mint(address, uint256, string)", NFTOwner, tokenId, tokenURI);
        bytes memory message = abi.encode(NFTAddress, mintMessage);
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        //  address(linkToken) means fees are paid in LINK
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            address(s_linkToken),
            message,
            extraArgs
        );

        // Get the fee required to send the CCIP message
        uint256 fees = s_router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // approve the Router to transfer LINK tokens on contract's behalf. It will spend the fees in LINK
        s_linkToken.approve(address(s_router), fees);

        // Send the CCIP message through the router and store the returned CCIP message ID
        messageId = s_router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        // Emit an event with message details
        emit MessageSent(
            messageId,
            _destinationChainSelector,
            _receiver,
            message,
            address(s_linkToken),
            fees
        );

        // Return the CCIP message ID
        return messageId;
    }


    function _buildCCIPMessage(
        address _receiver,
        address _feeTokenAddress,
        bytes memory message,
        Client.EVMExtraArgsV1 memory _extraArgs
    ) internal pure returns (Client.EVM2AnyMessage memory) {
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver), // ABI-encoded receiver address
                data: message, // ABI-encoded string
                tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
                extraArgs: Client._argsToBytes(
                    // Additional arguments, setting gas limit and non-strict sequencing mode
                    _extraArgs
                ),
                // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
                feeToken: _feeTokenAddress
            });
    }

    function setExtraArgs(uint256 _gasLimit, bool _strict) public onlyOwner {
        extraArgs = Client.EVMExtraArgsV1({gasLimit: _gasLimit, strict: _strict});
    }

}