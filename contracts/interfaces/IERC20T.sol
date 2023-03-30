// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

// import "./IBaked.sol";
import "./IERC20.sol";

// NOTE: not all IERC20 tokens have these functions
interface IERC20T is IERC20 {

    // ### EVENTS ####
    event Mint(address indexed origin, uint amount);
    event MultiTransfer(address indexed account, uint amount);
    event Rain(address indexed gifter, uint amount);
    event RainAll(address indexed account, uint amount);




    // ### PRE-CONSTRUCTOR VIEW FUNCTIONS ###
    function adminWallet() external view returns (address adminWallet);

    function denominator() external view returns (uint denominator);
    function supply() external view returns (uint supply);
    function version() external view returns (string memory version);

    function treasuryWallet() external view returns (address treasuryWallet);
    function loopWalletRainAll() external view returns (address loopWalletRainAll);

    function numUsers() external view returns (uint numUsers);
    function userAddresses(uint userID) external view returns (address userAddress);
    function userID(address account) external view returns (uint userID);
    function balances(address account) external view returns (uint balance);
    function transferToContract(address account) external view returns (address transferToContract);
    function currentUserRained(address account) external view returns (uint currentUserRained);
    function runningRainAllTotal(address account) external view returns (uint runningRainAllTotal);
    function rainExcluded(address account) external view returns (bool rainExcluded);
    // function allowances(address account) external view returns (mapping memory allowances); // invalid

    struct User {
        uint userID;
        address wallet;
        uint balance;
        bool rainExcluded;
        uint currentUserRained;
        uint runningRainAllTotal;
    }

    function getUserList() external view returns (User[] memory users);

    function getUserListIndices(uint first, uint last) external view returns (User[] memory users);

    function getUser(address account) external view returns (User memory user);

    function getCirculatingSupply() external view returns (uint circulatingSupply);

    function usersPerBlock() external view returns (uint usersPerBlock);
    function rainMinimumBalance() external view returns (uint rainMinimumBalance);

    function error_transfer_frozen() external view returns (string memory error_transfer_frozen);
    function error_goodbyeTokens() external view returns (string memory error_goodbyeTokens);
    function error_multiTransfer_blockLimit() external view returns (string memory error_multiTransfer_blockLimit);
    function error_rain_blockLimit() external view returns (string memory error_rain_blockLimit);




    // ### VIEW FUNCTIONS ###
    // Gasless token approval.
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function nonces(address owner) external view returns (uint nonces);
    function DOMAIN_SEPARATOR() external view returns (bytes32 DOMAIN_SEPARATOR);

    function PERMIT_TYPEHASH() external view returns (bytes32 PERMIT_TYPEHASH);
    function EIP712_DOMAIN() external view returns (bytes32 EIP712_DOMAIN);
    function chainID() external view returns (uint chainID); // should exactly match `block.chainid`

    function approveWithDeadline(address spender, uint amount, uint timestamp) external returns (bool success);
    function allowanceDeadline(address spender) external view returns (uint timestamp); // info only available to owner `msg.sender`
    function getDaysTimestamp(uint numDays) external view returns (uint timestamp);
    function revokeAllApprovals() external;
    function burnPreviousPermit() external;




    // ### SETTER FUNCTIONS ###
    function setAdminWallet(address newAdminWallet) external;

    function setTreasuryWallet(address newTreasuryWallet) external;

    function setUsersPerBlock(uint newUsersPerBlock) external;

    function setRainMinimumBalance(uint newRainMinimumBalance) external;

    function setLoopWalletRainAll(address newLoopWalletRainAll) external;




    // ### USER INTERACTIONS ###
    function sendToTreasury(uint amount) external;

    function goodbyeTokens() external;

    function multiTransfer(address[] memory recipients, uint[] memory amounts) external;

    function rain(uint amount, uint usersToRain) external;

    function rainList(uint amount, address[] memory list) external;

    function rainAll(uint amount) external;

    function claimERC20(address token) external;

}