pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IGTokenizerConsumer.sol";

contract IGPostNFT is Ownable, Pausable, ERC721URIStorage, IGTokenizerConsumer {

    mapping(string => address) private verifiedOwner;

    mapping(string => uint16) public edition;

    struct MintedNFT {
        address requester;
        string postID;
        uint256 tokenId;
        string metadataIPFS;
    }
    mapping(bytes32 => MintedNFT) private requestedNFTs;
    bytes32[] public requestsMadeKeys;
    event IGNFTMinted(address indexed minter, string postID, uint16 edition, uint256 tokenId, string tokenUri);

    constructor(address initialOwner) Ownable(initialOwner)
    ERC721("IGPostNFT", "IGNFT")
    IGTokenizerConsumer() {}
    
    //IPFS Hash of the metadata of the Smart Contract
    function contractURI() public pure returns (string memory) {
        return "ipfs://QmPeYkVk8qXZ8hdZLZQoRe6K2prpfrtkGbAdGAHzjw1A7U";
    }

    function mint(string memory postID, string memory metadataIPFS) public whenNotPaused() returns (uint256)
    {
        require(verifiedOwner[postID] == address(0) || verifiedOwner[postID] == msg.sender,
            "The video is already verified and sender is not registered as the owner");
        (uint96 videoTokenId, uint256 tokenId) = generateTokenId(postID);
        if (verifiedOwner[postID] == msg.sender) {
            _verifiedMint(msg.sender, postID, tokenId, metadataIPFS);
        } else {
            bytes32 requestId = verifyAuthority(postID, Strings.toString(videoTokenId));
            requestedNFTs[requestId] = MintedNFT(msg.sender, postID, tokenId, metadataIPFS);
        }
        return tokenId;
    } 

    function processVerification(bytes32 requestId, bool valid) override public {
        IGTokenizerConsumer.processVerification(requestId, valid);
        if (valid) {
            MintedNFT memory nft = requestedNFTs[requestId];
            verifiedOwner[nft.postID] = nft.requester;
            _verifiedMint(nft.requester, nft.postID, nft.tokenId, nft.metadataIPFS);
        }
    }

    function _verifiedMint(address requester, string memory postID, uint256 tokenId, string memory metadataIPFS)
    internal {
        _mint(requester, tokenId);
        _setTokenURI(tokenId, metadataIPFS);
        edition[postID]++;
        emit IGNFTMinted(requester, postID, edition[postID], tokenId, tokenURI(tokenId));
    }

    function generateTokenId(string memory postID) public view returns(uint96 videoTokenId, uint256 tokenId) {
        bytes memory postIdBytes = bytes(postID);
        require(postIdBytes.length == 11, "Instagram Post Id should be 11 ASCII characters long");
        videoTokenId = _toUint96(abi.encodePacked(hex"00", postIdBytes), 0);
        tokenId = uint256(videoTokenId) * 100000 + edition[postID] + 1;
    }

    function burn(uint256 tokenId) public whenNotPaused() {
        require(ownerOf(tokenId) == _msgSender(), "Not allowed to burn this NFT");
        _burn(tokenId);
    }

    function _baseURI() override internal view virtual returns (string memory) {
        return "ipfs://";
    }

    function _toUint96(bytes memory _bytes, uint256 _start) internal pure returns (uint96) {
        require(_bytes.length >= _start + 12, "toUint96_outOfBounds");
        uint96 tempUint;
        assembly {
            tempUint := mload(add(add(_bytes, 0xc), _start))
        }
        return tempUint;
    }

}
