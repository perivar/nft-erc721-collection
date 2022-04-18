// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9 <0.9.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/Base64.sol";

contract YourNftToken is ERC721A, ERC2981, Ownable, ReentrancyGuard {
    using Strings for uint256;

    /********************
     * Public variables *
     ********************/

    bytes32 public merkleRoot;

    string public uriPrefix = "";
    string public uriSuffix = ".json";
    string public hiddenMetadataUri;

    uint256 public cost;
    uint256 public maxSupply;
    uint256 public maxMintAmountPerTx;

    bool public paused = true;
    bool public whitelistMintEnabled = false;
    bool public revealed = false;

    // The number of free token mints reserved for the contract owner
    // Reserve initial tokens for giveaways and rewards...
    uint256 public reservedSupply;

    // @dev ERC2981 token royalty
    // Secondary market royalties in basis points
    // Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000,
    // meaning the fee is specified in basis points by default.
    // Default basis points are a percentage pluss 2 decimals (10000 = 100%, 1000 = 10%, 0 = 0%)
    uint96 public royaltyFeesInBips;

    // Address for royalties
    address public royaltyAddress;

    // Mapping table for claimed whitelists
    mapping(address => bool) public whitelistClaimed;

    /***************************
     * Contract initialization *
     ***************************/
    constructor(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _cost,
        uint256 _maxSupply,
        uint256 _maxMintAmountPerTx,
        string memory _hiddenMetadataUri,
        uint256 _reservedSupply,
        uint96 _royaltyFeesInBips
    ) ERC721A(_tokenName, _tokenSymbol) {
        setCost(_cost);
        maxSupply = _maxSupply;
        setMaxMintAmountPerTx(_maxMintAmountPerTx);
        setHiddenMetadataUri(_hiddenMetadataUri);

        // Reserve initial tokens for giveaways and rewards...
        reservedSupply = _reservedSupply;
        if (reservedSupply > 0) _safeMint(msg.sender, reservedSupply);

        // Set the royalites
        setDefaultRoyalty(msg.sender, _royaltyFeesInBips);
    }

    // dummy constructor for testing without parameters
    // constructor() ERC721A("My NFT Token", "MNT") {
    //     cost = 50000000000000000;
    //     maxSupply = 20;
    //     maxMintAmountPerTx = 5;
    //     hiddenMetadataUri = "ipfs://__CID__/hidden.json";
    //     reservedSupply = 10;

    //     // Reserve initial tokens for giveaways and rewards...
    //     if (reservedSupply > 0) _safeMint(msg.sender, reservedSupply);

    //     // Set the royalites
    //     setDefaultRoyalty(msg.sender, 250);
    // }

    /// Check if there are tokens left that can be minted, and that the amount does not exceed the limit per tx
    modifier mintCompliance(uint256 _mintAmount) {
        require(
            _mintAmount > 0 && _mintAmount <= maxMintAmountPerTx,
            "Invalid mint amount!"
        );
        require(
            totalSupply() + _mintAmount <= maxSupply,
            "Max supply exceeded!"
        );
        _;
    }

    /// Check if enough payment was provided to mint `amount` number of tokens
    modifier mintPriceCompliance(uint256 _mintAmount) {
        require(msg.value >= cost * _mintAmount, "Insufficient funds!");
        _;
    }

    /****************
     * User actions *
     ****************/

    /// Mint tokens
    function mint(uint256 _mintAmount)
        public
        payable
        mintCompliance(_mintAmount)
        mintPriceCompliance(_mintAmount)
    {
        require(!paused, "The contract is paused!");

        _safeMint(_msgSender(), _mintAmount);
    }

    /// Mint tokens if the wallet has been whitelisted
    function whitelistMint(uint256 _mintAmount, bytes32[] calldata _merkleProof)
        public
        payable
        mintCompliance(_mintAmount)
        mintPriceCompliance(_mintAmount)
    {
        // Verify whitelist requirements
        require(whitelistMintEnabled, "The whitelist sale is not enabled!");
        require(!whitelistClaimed[_msgSender()], "Address already claimed!");
        require(isWhitelisted(_msgSender(), _merkleProof), "Invalid proof!");

        whitelistClaimed[_msgSender()] = true;
        _safeMint(_msgSender(), _mintAmount);
    }

    /******************
     * View functions *
     ******************/

    /// Check if the wallet is whitelisted for the presale
    function isWhitelisted(address wallet, bytes32[] calldata _merkleProof)
        public
        view
        returns (bool)
    {
        bytes32 leaf = keccak256(abi.encodePacked(wallet));
        return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }

    /// Get all the tokens owned by the address
    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory ownedTokenIds = new uint256[](ownerTokenCount);
        uint256 currentTokenId = _startTokenId();
        uint256 ownedTokenIndex = 0;
        address latestOwnerAddress;

        while (
            ownedTokenIndex < ownerTokenCount && currentTokenId < _currentIndex
        ) {
            TokenOwnership memory ownership = _ownerships[currentTokenId];

            if (!ownership.burned) {
                if (ownership.addr != address(0)) {
                    latestOwnerAddress = ownership.addr;
                }

                if (latestOwnerAddress == _owner) {
                    ownedTokenIds[ownedTokenIndex] = currentTokenId;

                    ownedTokenIndex++;
                }
            }

            currentTokenId++;
        }

        return ownedTokenIds;
    }

    /// @dev See {ERC721A-_startTokenId}. Default 0. Overridden to start token from 1.
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    /// @dev See {IERC721Metadata-tokenURI}. Overridden to add uriSuffix.
    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        _tokenId.toString(),
                        uriSuffix
                    )
                )
                : "";
    }

    /// @dev OpenSea contract metadata
    function contractURI() external view returns (string memory) {
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        // solium-disable-next-line quotes
                        '{"seller_fee_basis_points": ', // solhint-disable-line quotes
                        uint256(royaltyFeesInBips).toString(),
                        // solium-disable-next-line quotes
                        ', "fee_recipient": "', // solhint-disable-line quotes
                        uint256(uint160(royaltyAddress)).toHexString(20),
                        // solium-disable-next-line quotes
                        '"}' // solhint-disable-line quotes
                    )
                )
            )
        );
        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        return output;
    }

    /// @dev See {ERC721A-_baseURI}. Default empty. Overridden to support a non-empty baseTokenURI.
    function _baseURI() internal view virtual override returns (string memory) {
        return uriPrefix;
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    /*****************
     * Admin actions *
     *****************/

    function mintForAddress(uint256 _mintAmount, address _receiver)
        public
        mintCompliance(_mintAmount)
        onlyOwner
    {
        _safeMint(_receiver, _mintAmount);
    }

    function setRevealed(bool _state) public onlyOwner {
        revealed = _state;
    }

    function setCost(uint256 _cost) public onlyOwner {
        cost = _cost;
    }

    function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx)
        public
        onlyOwner
    {
        maxMintAmountPerTx = _maxMintAmountPerTx;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function setUriPrefix(string memory _uriPrefix) public onlyOwner {
        uriPrefix = _uriPrefix;
    }

    function setUriSuffix(string memory _uriSuffix) public onlyOwner {
        uriSuffix = _uriSuffix;
    }

    function setPaused(bool _state) public onlyOwner {
        paused = _state;
    }

    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setWhitelistMintEnabled(bool _state) public onlyOwner {
        whitelistMintEnabled = _state;
    }

    function setRoyaltyAddress(address receiver) public onlyOwner {
        royaltyAddress = receiver;
    }

    function setRoyaltyFeesInBips(uint96 fees) public onlyOwner {
        require(fees <= 1000, "No more than 10% royalties!");
        royaltyFeesInBips = fees;
    }

    /// @dev See {ERC2981-setDefaultRoyalty}.
    function setDefaultRoyalty(address receiver, uint96 fees) public onlyOwner {
        setRoyaltyAddress(receiver);
        setRoyaltyFeesInBips(fees);
        _setDefaultRoyalty(receiver, fees);
    }

    function withdraw() public onlyOwner nonReentrant {
        // This will pay HashLips Lab Team 5% of the initial sale.
        // By leaving the following lines as they are you will contribute to the
        // development of tools like this and many others.
        // =============================================================================
        // (bool hs, ) = payable(0x146FB9c3b2C13BA88c6945A759EbFa95127486F4).call{
        //     value: (address(this).balance * 5) / 100
        // }("");
        // require(hs);
        // =============================================================================

        // This will transfer the remaining contract balance to the owner.
        // Do not remove this otherwise you will not be able to withdraw the funds.
        // =============================================================================
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
        // =============================================================================
    }
}
