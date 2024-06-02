// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Donate is AutomationCompatible, Ownable {
    // Receiver structure
    struct Receiver {
        uint256 amount;
        string currency;
    }

    // Donation details
    uint256 public totalAmount;
    uint256 public endTime;
    string public title;
    string public description;

    mapping(address => Receiver) public receivers;

    // Event definitions
    event Donated(address indexed donor, uint256 amount, string currency);

    event AddReciver(address indexed donor, Receiver receiver);

    constructor(
        uint256 _totalAmount,
        uint256 _endTime,
        string memory _title,
        string memory _description
    ) Ownable(msg.sender) {
        totalAmount = _totalAmount;
        endTime = _endTime;
        title = _title;
        description = _description;
    }

    function donateETH() external payable {
        require(block.timestamp < endTime, "Donation period ended");
        emit Donated(msg.sender, msg.value, "ETH");
    }

    function addReciver(address receiverAddress, Receiver memory receiver)
        external
        onlyOwner
    {
        receivers[receiverAddress] = receiver;
        emit AddReciver(msg.sender, receiver);
    }

    // function donateUSDC(uint256 _amount) external {
    //     require(block.timestamp < endTime, "Donation period ended");
    //     emit Donated(msg.sender, _amount, "USDC");
    // }

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

    function handleAllocation() internal {
        


    }

    function getEthBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
