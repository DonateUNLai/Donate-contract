// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract DonateNFT2 is VRFConsumerBaseV2Plus, ERC721URIStorage {
    uint256 private _tokenIds;
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);

    struct RequestStatus {
        bool fulfilled; // whether the request has been successfully fulfilled
        bool exists; // whether a requestId exists
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus) public s_requests; /* requestId --> requestStatus */

    // Your subscription ID.
    uint256 public s_subscriptionId;

    mapping(uint256 => uint256) public requestIdToTokenId;
    string constant META_DATA_1 =
        "ipfs://QmTNzsWJxB5zX3U77tGeVXZ54wqNvWjqetgw1GUPoiqh74/metedata1.json";
    string constant META_DATA_2 =
        "ipfs://QmTNzsWJxB5zX3U77tGeVXZ54wqNvWjqetgw1GUPoiqh74/metedata2.json";
    string constant META_DATA_3 =
        "ipfs://QmTNzsWJxB5zX3U77tGeVXZ54wqNvWjqetgw1GUPoiqh74/metedata3.json";
    string constant META_DATA_4 =
        "ipfs://QmTNzsWJxB5zX3U77tGeVXZ54wqNvWjqetgw1GUPoiqh74/metedata4.json";
    string constant META_DATA_5 =
        "ipfs://QmTNzsWJxB5zX3U77tGeVXZ54wqNvWjqetgw1GUPoiqh74/metedata5.json";

    // Past request IDs.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf/v2-5/supported-networks
    bytes32 public keyHash =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 public callbackGasLimit = 2500000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2_5.MAX_NUM_WORDS.
    uint32 public numWords = 2;

    /**
     * HARDCODED FOR SEPOLIA
     * COORDINATOR: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
     */
    constructor(uint256 subscriptionId, address _vrfCoordinator)
        VRFConsumerBaseV2Plus(_vrfCoordinator)
        ERC721("DonationNFT", "DNFT")
    {
        s_subscriptionId = subscriptionId;
    }

    // Assumes the subscription is funded sufficiently.
    // @param enableNativePayment: Set to `true` to enable payment in native tokens, or
    // `false` to pay in LINK
    function mintNFT() external returns (uint256 requestId) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;
        _mint(msg.sender, newItemId);

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        requestIdToTokenId[requestId] = newItemId;

        s_requests[requestId] = RequestStatus({
            randomWords: new uint256[](0),
            exists: true,
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] calldata _randomWords
    ) internal override {
        require(s_requests[_requestId].exists, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords);

        uint256 randomNumber = _randomWords[0];
        uint256 tokenId = requestIdToTokenId[_requestId];

        if (randomNumber % 5 == 0) {
            _setTokenURI(tokenId, META_DATA_1);
        } else if (randomNumber % 5 == 1) {
            _setTokenURI(tokenId, META_DATA_2);
        } else if (randomNumber % 5 == 2) {
            _setTokenURI(tokenId, META_DATA_3);
        } else if (randomNumber % 5 == 3) {
            _setTokenURI(tokenId, META_DATA_4);
        } else if (randomNumber % 5 == 4) {
            _setTokenURI(tokenId, META_DATA_5);
        }
    }

    function getRequestStatus(uint256 _requestId)
        external
        view
        returns (bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].exists, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.fulfilled, request.randomWords);
    }
}
