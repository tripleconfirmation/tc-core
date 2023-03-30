// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

// import "./constants.sol"; // required only for `_level` check on construction

import "./libraries/Caffeinated.sol";

import "./libraries/NFTStructs.sol";

import "./interfaces/EIP721TokenReceiver.sol";
import "./interfaces/INFTAdmin.sol";

/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://eips.ethereum.org/EIPS/eip-721
contract NFTBase {

    string public /* immutable */ version;

    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint indexed _tokenId);

    // -> ERC-721 Required function.
    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint indexed _tokenId);

    // -> ERC-721 Required function.
    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    INFTAdmin public NFTAdmin;

    // -> ERC-721 Required Variables
    // NFT Name
    string public /* immutable */ name;

    // NFT "Ticker"
    string public /* immutable */ symbol;

    // NFT Level as it relates to the Triple Confirmation ecosystem
    uint8 public immutable level;

    // List of all NFT
    NFTStructs.NFT[] public NFTs;

    // Mappings to track owners, balances, and approved wallets
    mapping(address => uint) public balances;
    mapping(address => mapping(address => bool)) public approvedForAll;

    constructor(
        address _NFTAdmin,
        string memory _name,
        string memory _symbol,
        uint8 _level,
        NFTStructs.NFT[] memory _NFTs
    ) {
        // // require(
        // //     _level < 10, // == constants.sol -> lenFeeReductions
        // //     "Invalid `_level`"
        // // );
        // This is also verified independently in NFTAdmin
        // using an actual pull from `constants.sol`
        
        NFTAdmin = INFTAdmin(_NFTAdmin);
        version = NFTAdmin.version();
        name = _name;
        symbol = _symbol;
        level = _level;

        // This external function is intended to be called before
        // any users receive any NFTs. This verifies the `level`
        // of this contract.
        NFTAdmin.addNewNFT(address(this));

        address _adminWallet = NFTAdmin.adminWallet();
        balances[_adminWallet] = _NFTs.length;
        
        // have to copy array manually
        for (uint i = 0; i < _NFTs.length; ++i) {
            NFTs.push(_NFTs[i]);
            NFTs[i].owner = _adminWallet;
            NFTs[i].tokenId = i;
            emit Transfer(address(0), _adminWallet, i);
        }

        string memory _header           = string.concat(name, " | ");
        error_countUnderflow            = string.concat(_header, error_countUnderflow);
        error_transferInvalidTokenId    = string.concat(_header, error_transferInvalidTokenId);
        error_transferFromAddress       = string.concat(_header, error_transferFromAddress);
        error_safeTransferFromOwner     = string.concat(_header, error_safeTransferFromOwner);
        error_safeTransferFromResponse1 = string.concat(_header, error_safeTransferFromResponse1);
        error_safeTransferFromResponse2 = string.concat(_header, error_safeTransferFromResponse2);
        error_approve                   = string.concat(_header, error_approve);
        error_getApproved               = string.concat(_header, error_getApproved);
        error_transferPotentialLoss     = string.concat(_header, error_transferPotentialLoss);
    }

    string public /* immutable */ error_countUnderflow = 
        "GET NFTs ERROR: `invertedList` underflowed.";

    // 0x00 --> normal list with lowest tokenId's first
    // 0x01 --> inverted list where highest tokenId's first
    // 0x02 --> first matching lowest tokenId only
    // 0x03 --> first matching highest tokenId only
    function _getNftsOf(
        address account,
        bytes1 operation
    ) public view returns (
        NFTStructs.accountNFTs memory nfts
    ) {
        nfts.nft = address(this);
        nfts.balance = balanceOf(account);

        bool _firstMatch = operation != 0x02 && operation != 0x03;

        nfts.tokenIds = new uint[](_firstMatch ? 1 : nfts.balance);
        nfts.nfts = new NFTStructs.NFT[](nfts.tokenIds.length);
        
        bool _invertedList = uint8(operation) % 2 == 1; // 0x01, 0x03, 0x05, etc
        uint _count = _invertedList ? _firstMatch ? 1 : nfts.balance : 0;

        for (uint i; i < NFTs.length; ++i) {
            if (NFTs[i].owner == account) {
                // Build the inverted list and check for an underflow.
                if (_invertedList) {
                    require(
                        _count > 0,
                        error_countUnderflow
                    );
                    nfts.nfts[--_count] = NFTs[i];
                    nfts.tokenIds[_count] = nfts.nfts[_count].tokenId;
                    if (_firstMatch) {
                        break;
                    }
                    continue;
                }
                // Otherwise the regular list does this
                nfts.nfts[_count] = NFTs[i];
                nfts.tokenIds[_count] = nfts.nfts[_count].tokenId;
                if (_firstMatch) {
                    break;
                }
                ++_count;
            }
        }

        return nfts;
    }

    function getNftsOf(
        address account
    ) external view returns (
        NFTStructs.accountNFTs memory nfts
    ) {
        return _getNftsOf(account, bytes1(0x00));
    }

    function getTokenIdsOf(address account) external view returns (uint[] memory) {
        return _getNftsOf(account, bytes1(0x00)).tokenIds;
    }

    // -> ERC-721 Optional variable.
    // Explicitly set to 0 to avoid any confusion: "Where is this set?"
    // Quite purposefully it's set to 0 per ERC-721 recommendations.
    uint8 constant public decimals = 0;

    // -> ERC-721 Optional function.
    /// @notice Enumerate valid NFTs
    /// @dev Throws if `_index` >= `totalSupply()`.
    /// @param _index A counter less than `totalSupply()`
    /// @return The token identifier for the `_index`th NFT,
    ///  (sort order not specified)
    function tokenByIndex(uint _index) external pure returns (uint) {
        return _index; // which is == NFTs[_index].tokenId;
    }

    // -> ERC-721 Optional function.
    /// @notice Enumerate NFTs assigned to an owner
    /// @dev Throws if `_index` >= `balanceOf(_owner)` or if
    ///  `_owner` is the zero address, representing invalid NFTs.
    /// @param _owner An address where we are interested in NFTs owned by them
    /// @param _index A counter less than `balanceOf(_owner)`
    /// @return The token identifier for the `_index`th NFT assigned to `_owner`,
    ///   (sort order not specified)
    function tokenOfOwnerByIndex(
        address _owner,
        uint _index
    ) external view returns (uint) {
        return _getNftsOf(_owner, bytes1(0x00)).tokenIds[_index];
    }

    // -> ERC-721 Optional function.
    /// @notice Count NFTs tracked by this contract
    /// @return A count of valid NFTs tracked by this contract, where each one of
    ///  them has an assigned and queryable owner not equal to the zero address
    function totalSupply() external view returns (uint) {
        return NFTs.length;
    }

    // -> ERC-721 Optional function.
    /// @notice A distinct Uniform Resource Identifier (URI) for a given asset.
    /// @dev Throws if `_tokenId` is not a valid NFT. URIs are defined in RFC
    ///  3986. The URI may point to a JSON file that conforms to the "ERC721
    ///  Metadata JSON Schema".
    function tokenURI(uint _tokenId) external view returns (string memory) {
        return NFTs[_tokenId].uri;
    }

    // -> ERC-721 Required function.
    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return balance The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }

    // -> ERC-721 Required function.
    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return owner The address of the owner of the NFT
    function ownerOf(uint _tokenId) external view returns (address owner) {
        return NFTs[_tokenId].owner;
    }

    // string public /* immutable */ error_transferNullAddress =
    //     "TRANSFER ERROR: `_to` cannot be the null address.";
    
    string public /* immutable */ error_transferInvalidTokenId =
        "TRANSFER ERROR: Invalid `tokenId`.";

    string public /* immutable */ error_transferFromAddress =
        "TRANSFER ERROR: `_from` does not own the specified NFT.";

    function _verifyTransfer(
        address _from,
        address _to,
        uint _tokenId
    ) private view returns (
        address
    ) {
        // Instead of reverting on sending to address(0),
        // simply redirect to the treasuryWallet to prevent
        // NFTs from burning on a malformed or malicious transfer.
        // require(_to != address(0), error_transferNullAddress);

        require(_tokenId < NFTs.length, error_transferInvalidTokenId);
        require(_from == NFTs[_tokenId].owner, error_transferFromAddress);
        
        // In order of likelihood to occur.
        // Prevent token burns by silently re-routing to the `treasuryWallet`.
        if (
            _to == address(0)
            || _to == address(0xdead)
            || _from == address(0)
            || _from == address(0xdead)
            || msg.sender == address(0)
            || msg.sender == address(0xdead)
        ) {
            _to = NFTAdmin.getTreasuryWallet();
        }

        return _to;
    }

    function _execTransfer(address _from, address _to, uint _tokenId) private {
        NFTs[_tokenId].owner = _to;
        delete NFTs[_tokenId].approved;

        --balances[_from];
        ++balances[_to];
    }

    function _updateNFTAdmin(address _from, address _to, uint _tokenId) private {
        NFTAdmin.nftTransferNotification(_from, _to);
        emit Transfer(_from, _to, _tokenId);
    }

    function _verifyAuth(uint _tokenId, string memory errorMsg) private view {
        require(
            msg.sender == NFTs[_tokenId].owner
            || msg.sender == NFTs[_tokenId].approved
            || approvedForAll[NFTs[_tokenId].owner][msg.sender],
            errorMsg
        );
    }

    function _safeTransferFrom(
        address _from,
        address _to,
        uint _tokenId,
        string memory _errorNum
    ) private returns (
        address
    ) {
        _verifyAuth(_tokenId, string.concat(error_safeTransferFromOwner, _errorNum));
        _to = _verifyTransfer(_from, _to, _tokenId);

        _execTransfer(_from, _to, _tokenId);
        _updateNFTAdmin(_from, _to, _tokenId);

        return _to;
    }

    string public /* immutable */ error_safeTransferFromOwner =
        "AUTH ERROR: Sender is not authorized to transfer ownership of this NFT. ";
    
    string public /* immutable */ error_safeTransferFromResponse1 =
        "RESPONSE ERROR: Invalid response from `_to` in `safeTransferFrom()`. (1)";

    bytes4 constant public ERC721MagicValue =
        bytes4(
            keccak256(
                "onERC721Received(address,address,uint,bytes)"
            )
        );
    // -> ERC-721 Required function.
    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    // @dev `payable` removed by TC to avoid coins (ETH, AVAX, etc) from being perma-lost.
    function safeTransferFrom(address _from, address _to, uint _tokenId, bytes calldata data) external {
        _to = _safeTransferFrom(_from, _to, _tokenId, "(1)");

        if (Caffeinated.isContract(_to)) {
            require(
                ERC721TokenReceiver(_to).onERC721Received(
                    msg.sender,
                    _from,
                    _tokenId,
                    data
                ) == ERC721MagicValue,
                error_safeTransferFromResponse1
            );
        }
    }
    
    string public /* immutable */ error_safeTransferFromResponse2 =
        "RESPONSE ERROR: Invalid response from `_to` in `safeTransferFrom()`. (2)";
    
    // -> ERC-721 Required function.
    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    // @dev `payable` removed by TC to avoid coins (ETH, AVAX, etc) from being perma-lost.
    function safeTransferFrom(address _from, address _to, uint _tokenId) external {
        _to = _safeTransferFrom(_from, _to, _tokenId, "(2)");

        if (Caffeinated.isContract(_to)) {
            require(
                ERC721TokenReceiver(_to).onERC721Received(
                    msg.sender,
                    _from,
                    _tokenId,
                    ""
                ) == ERC721MagicValue,
                error_safeTransferFromResponse2
            );
        }
    }

    // -> ERC-721 Required function.
    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    // @dev `payable` removed by TC to avoid coins (ETH, AVAX, etc) from being perma-lost.
    function transferFrom(address _from, address _to, uint _tokenId) external {
        _safeTransferFrom(_from, _to, _tokenId, "(3)");
    }

    string public /* immutable */ error_transferPotentialLoss =
        string.concat(
            "TRANSFER ERROR: Use `transferFrom()` to send an NFT ",
            "to a smart contract."
        );
    // -> ERC-721 Optional function.
    //    Provides identical functionality to an ERC-20
    //    with transfers to contracts blocked to avoid
    //    accidentally incurring a total loss of the NFT.
    function transfer(address _to, uint _tokenId) external {
        require(
            !Caffeinated.isContract(_to)
            || NFTAdmin.isTeamWallet(_to),
            error_transferPotentialLoss
        );
        _safeTransferFrom(msg.sender, _to, _tokenId, "(4)");
    }

    string public /* immutable */ error_approve =
        "APPROVE ERROR: Sender is not authorized to change the `approved` of this NFT.";
    
    // -> ERC-721 Required function.
    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    // @dev `payable` removed by TC to avoid coins (ETH, AVAX, etc) from being perma-lost.
    function approve(address _approved, uint _tokenId) external {
        _verifyAuth(_tokenId, error_approve);
        NFTs[_tokenId].approved = _approved;
        emit Approval(msg.sender, _approved, _tokenId);
    }

    string public /* immutable */ error_getApproved =
        "GET APPROVED ERROR: Invalid `_tokenId`.";
    
    // -> ERC-721 Required function.
    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return approved The approved address for this NFT, or the zero address if there is none
    function getApproved(uint _tokenId) external view returns (address) {
        require(
            NFTs.length > _tokenId,
            error_getApproved
        );
        return NFTs[_tokenId].approved;
    }

    // -> ERC-721 Required function.
    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external {
        approvedForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    // -> ERC-721 Required function.
    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return _approvedForAll True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return approvedForAll[_owner][_operator];
    }

}


