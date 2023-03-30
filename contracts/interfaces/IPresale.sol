// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./AggregatorV3Interface.sol";
import "./IBaked.sol";
import "./IBotPool.sol";
import "./IERC20T.sol";

import "../libraries/PresaleLib_structs.sol";

// uint8 constant _t = 5;
// uint8 constant _n = 6;

interface IPresale is IBaked {

    // ### EVENTS ###
    event Purchase(address indexed from, address indexed to, uint value);
    event Extinguished(uint tcTotal);
    event Vested(address indexed from, address indexed to, uint value, uint pctVested);
    event RoundUpdate(uint newRound, uint tcSoldSinceLastRound);
    event MigrationStatus(uint completedAccounts, uint totalAccounts, uint tcTotal, uint tccTotal);
    event MigrationDone();




    // ### VIEW FUNCTIONS ###
    function version() external view returns (string memory version);
    
    function TC() external view returns (IERC20T TC);
    function USDC() external view returns (IERC20 USDC);
    function USDCe() external view returns (IERC20 USDCe);

    function priceFeed() external view returns (AggregatorV3Interface priceFeed);

    function oneHundredPct() external view returns (uint oneHundredPct);
    function secPerWeek() external view returns (uint secPerWeek);
    function timeStartPublicRounds() external view returns (uint timeStartPublicRounds);
    function normalizedTC() external view returns (uint normalizedTC);
    function normalizedUSD() external view returns (uint normalizedUSD);
    function normalizedAVAX() external view returns (uint normalizedAVAX);
    function extraBonusThreshold() external view returns (uint extraBonusThreshold);
    function extraBonusPct() external view returns (uint extraBonusPct);
    function extraBonusInitialCliff() external view returns (uint extraBonusInitialCliff);
    function t() external view returns (uint8 t);
    function nftAmounts(uint index) external view returns (uint nftAmount);
    function fiftyPct() external view returns (uint fiftyPct);

    function maxSingleLoopSize() external view returns (uint maxSingleLoopSize);
    function maxUsers() external view returns (uint maxUsers);

    function n() external view returns (uint8 n);
    function TCRounds(uint index) external view returns (uint TCRound);
    function USDPrice(uint index) external view returns (uint USDPrice);
    function currentRound() external view returns (uint currentRound);
    function totalTC() external view returns (uint totalTC);
    function requiredTC() external view returns (uint requiredTC); // amount of TC required to fund the full Presale
    function requiredTCC() external view returns (uint requiredTCC); // amount of TCC required to fund the full Presale
    function tcDisbursed() external view returns (uint tcDisbursed);
    function totalSpentUSD() external view returns (uint totalSpentUSD);
    function totalPurchasedTC() external view returns (uint totalPurchasedTC);
    function totalPurchasedTCSinceLastRound() external view returns (uint totalPurchasedTCSinceLastRound);
    function contractUserID() external view returns (uint contractUserID); // == 1;

    function lastUserTransferred() external view returns (uint lastUserTransferred);
    function BotPool() external view returns (IBotPool BotPool);
    function teamWallet() external view returns (address teamWallet);
    function foundersVesting() external view returns (address foundersVesting);
    function treasuryWallet_() external view returns (address treasuryWallet);
    function timeEnd() external view returns (uint timeEnd);
    function referralCodes(string memory referralCode) external view returns (uint userID);

	// struct PresaleLib_structs.UserStruct {
    //     uint userID;
    //     address adresse;
    //     bool isRegistered;
    //     bool[_t] nftRewards;
    //     uint spentUSDC;
    //     uint spentUSDCe;
    //     uint balanceTotalEver;  // total TC balance
    //     uint balanceBonus;      // total bonus TC ever received by this user via Vesting
    //     uint balanceBonusFromYourReferrals;
    //     uint balanceBonusFromUsingReferrals;
    //     uint balanceVested;     // amount of TC vested; cumulative; used for `extraBonusThreshold` 2% on 100k TC
    //     uint balance;           // current balance available to vest or to be withdrawn at CROWDFUND end
    //     uint balanceTCC;
    //     string referralCode;
    // }

	struct Info {
        // User user;
        uint numUsers;
        uint[_n] TCRounds;
        uint[_n] USDPrice;
        uint currentRound;
        uint totalTC;
        uint totalSpentUSD;
        uint totalPurchasedTC;
        uint totalPurchasedTCSinceLastRound;
        uint totalTCGivenForReferrals;
    }

    struct Contribution {
        address userAddress;
        uint amountUSD;
        uint amountTC;
    }

    function userIDs(address account) external view returns (uint userID);
    // function users_(uint index) external view returns (PresaleLib_structs.UserStruct memory user_);

    function contributions(uint index) external view returns (Contribution memory contribution);

    function existingOwners(uint index) external view returns (address existingOwner);
    function existingTCBalances(uint index) external view returns (uint existingTCBalance);
    function existingTCCBalances(uint index) external view returns (uint existingTCCBalance);
    function ownerCompleted() external view returns (uint ownerCompleted);
    function ownerCount() external view returns (uint ownerCount);




    // ### EXISTING BALANCES FUNCTIONS ###
    function rememberExistingOwners(address[] calldata _existingOwners) external;

    function rememberExistingTCBalances(uint[] calldata _existingTCBalances) external;

    function rememberExistingTCCBalances(uint[] calldata _existingTCCBalances) external;

    function loopExistingBalances() external;

    function _setUser(PresaleLib_structs.UserStruct memory _user) external;




    // ### SETTER FUNCTIONS ###
    function setBotPool(address _BotPool) external;

    function setTimeStartPublicRounds(uint timestamp) external;

    function setTeamWallet(address newTeamWallet) external;

    function setTreasuryWallet(address newTreasuryWallet) external;

    function walletChange(address newWallet) external;




    // ### GETTER FUNCTIONS ###
    function getInfo() external view returns (Info memory info);

    function getUser(address account) external view returns (PresaleLib_structs.UserStruct memory user);

    function getUserById(uint index) external view returns (PresaleLib_structs.UserStruct memory user);

    function getUserList() external view returns (PresaleLib_structs.UserStruct[] memory users);

    function getContributions() external view returns (Contribution[] memory contributions);

    function setReferralCode(string calldata myReferralCode) external;




    // ### TC PURCHASE FUNCTIONS ###
    function requestUsingAmountTC(uint amountTC, uint expectedRound) external returns (uint purchasedTC, uint spentUSD);

    function requestUsingAmountUSDC(uint amountUSD, uint expectedRound) external returns (uint purchasedTC, uint spentUSD);

    function vestTC(uint amountTC, uint8 yrs) external;




    // ### PRESALE END FUNCTIONS ###
    function endCrowdfund(address newCROWDFUND) external;




    // ### MISC FUNCTIONS ###
    function approve() external;

    function claimERC20(address _token) external;

}