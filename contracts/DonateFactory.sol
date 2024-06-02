// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
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

interface FunctionsAddComsumerInterface {
    function addConsumer(uint256 subscriptionId, address consumer)
        external
        returns (uint256);
}

contract DonateFactory is ConfirmedOwner {
    event UpkeepRegistered(uint256 upkeepID, address donateContract);

    event DonateCreated(address donateContract);

    event ConsumerAdded(uint256 subscriptionId, address donateContract);

    LinkTokenInterface public immutable i_link;
    AutomationRegistrarInterface public immutable i_registrar;
    FunctionsAddComsumerInterface public i_router;

    uint256 public immutable i_subscriptionId;

    constructor(
        LinkTokenInterface link,
        AutomationRegistrarInterface registrar,
        FunctionsAddComsumerInterface router,
        uint256 subscriptionId
    ) ConfirmedOwner(msg.sender) {
        i_link = link;
        i_registrar = registrar;
        i_router = router;
        i_subscriptionId = subscriptionId;
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
            amount: 4000000000000000000
        });

        i_link.approve(address(i_registrar), params.amount);
        uint256 upkeepID = i_registrar.registerUpkeep(params);
        if (upkeepID != 0) {
            emit UpkeepRegistered(upkeepID, _deployedContract);
        } else {
            revert("auto-approve disabled");
        }
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
            _description
        );

        emit DonateCreated(address(newDonate));
        registerAndPredictID(address(newDonate));
        return address(newDonate);
    }

    function addConsumer(address donateContract) public onlyOwner {
        i_router.addConsumer(i_subscriptionId, donateContract);
        emit ConsumerAdded(i_subscriptionId, donateContract);
    }
}
