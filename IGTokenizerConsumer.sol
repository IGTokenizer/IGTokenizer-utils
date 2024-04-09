// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Chainlink, ChainlinkClient} from "@chainlink/contracts@0.8.0/src/v0.8/ChainlinkClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts@0.8.0/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts@0.8.0/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract IGTokenizerConsumer is ChainlinkClient {
    using Chainlink for Chainlink.Request;
    using Strings for uint96;

    uint256 public volume;
    bytes32 private jobId;
    uint256 private fee;

    struct IGTokenization {
        string postId;
        address requester;
        string postTokenId;
        bool isPending;
        bool isVerified;
    }

    mapping(bytes32 => IGTokenization) public requests;
    bytes32[] public requestKeys;

    event TokenizationRequest(bytes32 indexed requestId, string postId, string hashId);
    event InstagramPostVerification(bytes32 indexed requestId, string postId, bool isVerified);

    constructor() {
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0xDE6fe1bC4Dda932e0a5b557DdB10bbe5878ee752);
        jobId = "969b68fc36ab4cdfb2626c42d82842eb";
        fee = 0.1 * 10**18;
    }

    function verifyAuthority(string memory postIg, string memory hashVerify) public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.processVerification.selector
        );
        req.add("postId", postIg);
        req.add("hashToVerify", hashVerify);

        requestId = sendChainlinkRequest(req, fee);
        requestKeys.push(requestId);
        requests[requestId] = IGTokenization(postIg, msg.sender, hashVerify, true, false);
        emit TokenizationRequest(requestId, postIg, hashVerify);
        return requestId;
    }

    function processVerification(bytes32 requestId, bool valid) virtual public recordChainlinkFulfillment(requestId) {
        require(requests[requestId].isPending, "Oracle request already resolved");
        requests[requestId].isPending = false;
        requests[requestId].isVerified = valid;
        emit InstagramPostVerification(requestId, requests[requestId].postId, valid);
    }

    function getAllTokenizationRequests() external view returns (bytes32[] memory, IGTokenization[] memory) {
        bytes32[] memory keys = new bytes32[](requestKeys.length);
        IGTokenization[] memory tokenizationContracts = new IGTokenization[](requestKeys.length);

        for (uint256 i = 0; i < requestKeys.length; i++) {
            bytes32 key = requestKeys[i];
            keys[i] = key;
            tokenizationContracts[i] = requests[key];
        }

        return (keys, tokenizationContracts);
    }
}
