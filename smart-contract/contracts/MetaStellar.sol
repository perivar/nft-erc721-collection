// SPDX-License-Identifier: MIT
// Creator: Stellar Labs

pragma solidity >=0.8.9 <0.9.0; // PIN: changed

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol"; // PIN: added

contract MetaStellar is
    Ownable,
    ERC721A,
    ERC2981 // PIN: added ERC2981
{
    using Strings for uint256; // PIN: added

    /********************
     * Public variables *
     ********************/

    uint256 public immutable collectionSize;

    uint256 public maxPerAddressDuringMint;
    uint64 public whitelistPrice;
    uint64 public publicPrice;

    // @dev ERC2981 token royalty
    // Royalty is specified as a fraction of sale price. {_feeDenominator} is overridable but defaults to 10000,
    // meaning the fee is specified in basis points by default.
    // Default basis points are a percentage pluss 2 decimals (10000 = 100%, 1000 = 10%, 0 = 0%)
    uint96 public royaltyfeeNumerator;

    bool public saleIsActive;
    bool public whitelistSaleIsActive;

    mapping(address => bool) public whiteList;
    mapping(address => address) private payments;

    /********************
     * Private variables *
     ********************/

    string private _baseTokenURI = "";
    string private uriSuffix = ".json"; // PIN: added

    /***************************
     * Contract initialization *
     ***************************/
    constructor() ERC721A("MetaStellar", "METASTELLAR") {
        collectionSize = 10000;
        saleIsActive = false;
        whitelistSaleIsActive = true;
        publicPrice = 500000000000000000;
        whitelistPrice = 200000000000000000;
        maxPerAddressDuringMint = 50;
        royaltyfeeNumerator = 1000;
        _setDefaultRoyalty(msg.sender, royaltyfeeNumerator);
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "CIU");
        _;
    }

    modifier saleQuantity(uint256 quantity) {
        require(_totalMinted() + quantity <= collectionSize, "SQ1");
        require(
            _numberMinted(msg.sender) + quantity <= maxPerAddressDuringMint,
            "SQ2"
        );
        _;
    }

    /*****************
     * Admin actions *
     *****************/

    function publicSaleChangeState() external onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function whitelistSaleChangeState() external onlyOwner {
        whitelistSaleIsActive = !whitelistSaleIsActive;
    }

    function setRoyaltyFeeNumerator(uint96 _fee) external onlyOwner {
        royaltyfeeNumerator = _fee;
    }

    function setWhitelistPrice(uint64 price) external onlyOwner {
        whitelistPrice = price;
    }

    function setPublicPrice(uint64 price) external onlyOwner {
        publicPrice = price;
    }

    function setMaxPerAdressDuringMint(uint256 num) external onlyOwner {
        maxPerAddressDuringMint = num;
    }

    function addToWhitelist(address _addr) external onlyOwner {
        whiteList[_addr] = true;
    }

    function deteleWhiteList(address _addr) external onlyOwner {
        delete whiteList[_addr];
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setURIsuffix(string memory suffix) public onlyOwner {
        uriSuffix = suffix;
    }

    /// @dev See {ERC2981-_setTokenRoyalty}.
    function setTokenRoyalty(uint256 tokenId, address receiver)
        external
        onlyOwner
    {
        _setTokenRoyalty(tokenId, receiver, royaltyfeeNumerator);
    }

    /// @dev See {ERC2981-resetTokenRoyalty}.
    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    /// @dev See {ERC2981-setDefaultRoyalty}.
    function setDefaultRoyalty(address receiver) external onlyOwner {
        _setDefaultRoyalty(receiver, royaltyfeeNumerator);
    }

    function setPaymentMapping(address _payspitteraddr, address _minter)
        external
        onlyOwner
    {
        payments[_minter] = _payspitteraddr;
    }

    function withdrawMoney() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "TF");
    }

    /****************
     * User actions *
     ****************/

    function mint(uint256 quantity)
        external
        payable
        callerIsUser
        saleQuantity(quantity)
    {
        require(saleIsActive, "S1");
        _safeMint(msg.sender, quantity);
        refundIfOver(publicPrice * quantity);
    }

    function whitelistMint(uint256 quantity)
        external
        payable
        callerIsUser
        saleQuantity(quantity)
    {
        require(whitelistSaleIsActive, "W1");
        _safeMint(msg.sender, quantity);
        if (msg.sender != owner()) {
            require(whiteList[msg.sender], "W2");
            refundIfOver(whitelistPrice * quantity);
        }
    }

    /// @dev See {IERC721Metadata-tokenURI}. Overridden to add uriSuffix.
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length != 0
                ? string(
                    abi.encodePacked(baseURI, tokenId.toString(), uriSuffix)
                )
                : "";
    }

    /***********************
     * Convenience getters *
     ***********************/

    function numberMinted(address owner) external view returns (uint256) {
        return _numberMinted(owner);
    }

    function numberBurned(address owner) external view returns (uint256) {
        return _numberBurned(owner);
    }

    function totalMinted() external view returns (uint256) {
        return _totalMinted();
    }

    function totalBurned() external view returns (uint256) {
        return _burnCounter;
    }

    function getPaymentAddress(address _minter)
        external
        view
        returns (address)
    {
        if (msg.sender != owner()) {
            require(msg.sender == _minter, "PA");
        }
        return payments[_minter];
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "ME");
        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function burn(uint256 tokenId) external callerIsUser {
        _burn(tokenId, true);
    }

    /// @dev See {ERC721A-_baseURI}. Default empty. Overridden to support a non-empty baseTokenURI.
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
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
}
