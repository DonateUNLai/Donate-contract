// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";

contract Donate is AutomationCompatible, Ownable {
    using SafeERC20 for IERC20;
    error USDCTransferFailed();

    // Event definitions
    event Donated(address indexed donor, uint256 amount, string currency);

    // Receiver structure
    struct Receiver {
        uint256 amount;
        string currency;
        bool isAllocated;
    }

    mapping(address => Receiver) public allocation;
    address[] public receivers;

    // Donation details
    uint256 public totalAmount;
    uint256 public endTime;
    string public title;
    string public description;
    IERC20 public usdcToken;

    uint256 private _tokenIds;

    modifier beforeEnd() {
        require(block.timestamp < endTime, "Donation period ended");
        _;
    }

    constructor(
        uint256 _totalAmount,
        uint256 _endTime,
        string memory _title,
        string memory _description,
        address _usdcToken
    ) Ownable(msg.sender) {
        totalAmount = _totalAmount;
        endTime = _endTime;
        title = _title;
        description = _description;
        usdcToken = IERC20(_usdcToken);
    }

    function donateETH() external payable beforeEnd {
        emit Donated(msg.sender, msg.value, "ETH");
    }

    function addReciver(
        address receiverAddress,
        uint256 amount,
        string memory currency
    ) external beforeEnd  {
        receivers.push(receiverAddress);
        allocation[receiverAddress] = Receiver(amount, currency, false);
    }

    function donateUSDC(uint256 _amount) external beforeEnd {
        if (!usdcToken.transferFrom(msg.sender, address(this), _amount))
            revert USDCTransferFailed();

        emit Donated(msg.sender, _amount, "USDC");
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        upkeepNeeded = block.timestamp >= endTime;
    }

    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        if (block.timestamp >= endTime) {
            handleAllocation();
        }
    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getCurrentTime() public view returns (uint256 time) {
        time = block.timestamp;
        return time;
    }

    function handleAllocation() internal onlyOwner {
        for (uint256 i = 0; i < receivers.length; i++) {
            address receiverAddress = receivers[i];
            if (allocation[receiverAddress].isAllocated) {
                Receiver memory receiver = allocation[receiverAddress];

                if (
                    keccak256(abi.encodePacked(receiver.currency)) ==
                    keccak256(abi.encodePacked("ETH"))
                ) {
                    allocateETH(receiverAddress, receiver.amount);
                } else if (
                    keccak256(abi.encodePacked(receiver.currency)) ==
                    keccak256(abi.encodePacked("USDC"))
                ) {
                    allcateUSDC(receiverAddress, receiver.amount);
                } else {
                    revert("Unsupported currency");
                }

                allocation[receiverAddress].isAllocated = true;
            }
        }
    }

    function allocateETH(address _receiver, uint256 _amount) internal {
        require(address(this).balance >= _amount, "Insufficient ETH balance");
        payable(_receiver).transfer(_amount);
    }

    function allcateUSDC(address _receiver, uint256 _amount) internal {
        uint256 contractBalance = usdcToken.balanceOf(address(this));
        require(contractBalance >= _amount, "Insufficient USDC balance");
        bool success = usdcToken.transfer(_receiver, _amount);
        require(success, "USDC transfer failed");
    }
}
