// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Donate} from "./Donate.sol";

struct RegistrationParams {
    string name;
    bytes encryptedEmail;
    address upkeepContract;
    uint32 gasLimit;
    address adminAddress;
    uint8 triggerType;
    bytes checkData;
    bytes triggerConfig;
    bytes offchainConfig;
    uint96 amount;
}

interface AutomationRegistrarInterface {
    function registerUpkeep(RegistrationParams calldata requestParams)
        external
        returns (uint256);
}

contract StringToAddress {
    using Strings for uint256;

    function stringToAddress(string memory s) public pure returns (address) {
        bytes memory ss = bytes(s);
        require(ss.length == 42, "Invalid address length");

        uint160 result = 0; // 使用uint160来确保结果可以转成address
        for (uint256 i = 2; i < 42; i++) {
            uint160 c = uint160(uint8(ss[i]));

            if (c >= 48 && c <= 57) {
                c -= 48;
            } else if (c >= 65 && c <= 70) {
                c -= 55;
            } else if (c >= 97 && c <= 102) {
                c -= 87;
            } else {
                revert("Invalid character in address");
            }

            result = result * 16 + c;
        }

        return address(result);
    }
}

contract DonateFactory is ConfirmedOwner, CCIPReceiver {
    error DonateFactory__NoLinkToWithdraw();
    error DonateFactory__LinkTransferFailed();
    error DonateFactory__SourceChainNotAllowed(uint64 sourceChainSelector);
    error DonateFactory__SenderNotAllowed(address sender);

    event UpkeepRegistered(uint256 upkeepID, address donateContract);
    event DonateCreated(address donateContract);
    event SubscriptionAdded(uint256 subscriptionId, address donateContract);
    event ConsumerAdded(uint256 subscriptionId, address donateContract);
    event Response(bytes32 indexed requestId, bytes response, bytes err);

    LinkTokenInterface public immutable i_link;
    AutomationRegistrarInterface public immutable i_registrar;
    address public usdcTokenAddress;

    bytes32 private s_lastReceivedMessageId; // Store the last received messageId.
    address private s_lastReceivedTokenAddress; // Store the last received token address.
    uint256 private s_lastReceivedTokenAmount; // Store the last received amount.
    string private s_lastReceivedText; // Store the last received text.

    // Mapping to keep track of allowlisted senders.
    mapping(address => bool) public allowlistedSenders;

    // Mapping to keep track of allowlisted source chains.
    mapping(uint64 => bool) public allowlistedSourceChains;

    mapping(address => uint256) public sourceAmounts;

    StringToAddress private converter = new StringToAddress();

    constructor(
        LinkTokenInterface link,
        AutomationRegistrarInterface registrar,
        address router,
        address _usdcTokenAddress
    ) ConfirmedOwner(msg.sender) CCIPReceiver(router) {
        i_link = link;
        i_registrar = registrar;
        usdcTokenAddress = _usdcTokenAddress;
    }

    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert DonateFactory__SourceChainNotAllowed(_sourceChainSelector);
        if (!allowlistedSenders[_sender])
            revert DonateFactory__SenderNotAllowed(_sender);
        _;
    }

    function allowlistSourceChain(uint64 _sourceChainSelector, bool allowed)
        external
        onlyOwner
    {
        allowlistedSourceChains[_sourceChainSelector] = allowed;
    }

    /// @dev Updates the allowlist status of a sender for transactions.
    /// @notice This function can only be called by the owner.
    /// @param _sender The address of the sender to be updated.
    /// @param allowed The allowlist status to be set for the sender.
    function allowlistSender(address _sender, bool allowed) external onlyOwner {
        allowlistedSenders[_sender] = allowed;
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage)
        internal
        override
        onlyAllowlisted(
            any2EvmMessage.sourceChainSelector,
            abi.decode(any2EvmMessage.sender, (address))
        ) // Make sure source chain and sender are allowlisted
    {
        s_lastReceivedMessageId = any2EvmMessage.messageId; // fetch the messageId
        s_lastReceivedText = abi.decode(any2EvmMessage.data, (string)); // abi-decoding of the sent text
        // Expect one token to be transferred at once, but you can transfer several tokens.
        s_lastReceivedTokenAddress = any2EvmMessage.destTokenAmounts[0].token;
        s_lastReceivedTokenAmount = any2EvmMessage.destTokenAmounts[0].amount;

        address addr = converter.stringToAddress(s_lastReceivedText);

        sourceAmounts[addr] = s_lastReceivedTokenAmount;
    }

    function registerAndPredictID(address _deployedContract) public {
        RegistrationParams memory params = RegistrationParams({
            name: "",
            encryptedEmail: hex"",
            upkeepContract: _deployedContract,
            gasLimit: 2000000,
            adminAddress: owner(),
            triggerType: 0,
            checkData: hex"",
            triggerConfig: hex"",
            offchainConfig: hex"",
            amount: 1000000000000000000
        });

        i_link.approve(address(i_registrar), params.amount);
        uint256 upkeepID = i_registrar.registerUpkeep(params);
        if (upkeepID != 0) {
            emit UpkeepRegistered(upkeepID, _deployedContract);
        } else {
            revert("auto-approve disabled");
        }
    }

    function getCrossUsdc(address donateContract)
        public
        view
        returns (uint256)
    {
        return sourceAmounts[donateContract];
    }

    function createDonate(
        uint256 _totalAmount,
        uint256 _endTime,
        string memory _title,
        string memory _description
    ) public returns (address) {
        Donate newDonate = new Donate(
            _totalAmount,
            _endTime,
            _title,
            _description,
            usdcTokenAddress
        );

        emit DonateCreated(address(newDonate));
        registerAndPredictID(address(newDonate));

        return address(newDonate);
    }

    function withdrawLink() public onlyOwner {
        uint256 balance = i_link.balanceOf(address(this));
        if (balance == 0) revert DonateFactory__NoLinkToWithdraw();

        if (!i_link.transfer(msg.sender, balance))
            revert DonateFactory__LinkTransferFailed();
    }

    function getContractLinkBalance() public view returns (uint256) {
        return i_link.balanceOf(address(this));
    }

    function getUserLinkBalance() public view returns (uint256) {
        return i_link.balanceOf(address(msg.sender));
    }
}
