// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "./IBotController.sol";
import "./IBotTrader.sol";
import "./IERC20.sol";
import "./IERC20T.sol";

interface IBotPool {

    // ### EVENTS ###
    event WeeklyFeeDone(uint amount);
    event EvictedAll();
    event BadUsersEjected();
    event VestingEnding(uint when);
    event PresaleEnded(uint when);




	// ### VIEW FUNCTIONS ###
    function version() external view returns (string memory version);

    function botController() external view returns (IBotController botController);
    function pendingNewBotController() external view returns (address pendingNewBotController);
    function botTraderSetBotController() external view returns (uint botTraderSetBotController);

    function oneHundredPct() external view returns (uint oneHundredPct);
    function originalFrontend() external view returns (address originalFrontend);
    function botFactory() external view returns (address botFactory);
    function presale() external view returns (address presale);
    function weeklyFeeWallet() external view returns (address weeklyFeeWallet);
    function frontend() external view returns (address frontend);

    function adminWallet() external view returns (address adminWallet);

    function cash() external view returns (IERC20 cash);
    function asset() external view returns (IERC20 asset);
    function tc() external view returns (IERC20T tc);
    function tcc() external view returns (IERC20T tcc);

    function cashSymbol() external view returns (string memory cashSymbol);

    function cashDecimals() external view returns (uint cashDecimals);

    function assetSymbol() external view returns (string memory assetSymbol);

    function assetDecimals() external view returns (uint assetDecimals);

    function tcSymbol() external view returns (string memory tcSymbol);
    function tccSymbol() external view returns (string memory tccSymbol);
    function tcDecimals() external view returns (uint tcDecimals);
    function tccDecimals() external view returns (uint tccDecimals);

    function mode() external view returns (string memory mode);
    function timeframe() external view returns (string memory timeframe);
    function strategyName() external view returns (string memory strategyName);
    function description() external view returns (string memory description);

    function tcToAdd() external view returns (bool tcToAdd);
    function botPoolCashBalance() external view returns (uint botPoolCashBalance);

    function vestingFrozen() external view returns (bool vestingFrozen);
    function minGas() external view returns (uint minGas);

    function botTraders(uint index) external view returns (IBotTrader botTrader);
    function isTradingWallet(uint index) external view returns (address isTradingWallet);
    function isBotTraderContract(address BotTraderContract) external view returns (bool isBotTraderContract);
    function availableBotTrader() external view returns (address availableBotTrader);

    function botTraderMaxUsers() external view returns (uint botTraderMaxUsers);
    function maxBotTraders() external view returns (uint maxBotTraders);

    function numBotTraders() external view returns (uint numBotTraders);

    function numUsers() external view returns (uint numUsers);
    function botPoolMaxUsers() external view returns (uint BotPoolMaxUsers);

    function userIDs(address userAddress) external view returns (uint userID);
    function userAddress(uint userID) external view returns (address userAddress);
    function isRegistered(uint userID) external view returns (bool isRegistered);
    function inBotTrader(uint userID) external view returns (IBotTrader BotTrader);
    function balanceTC(uint userID) external view returns (uint balanceTC);
    function balanceTCC(uint userID) external view returns (uint balanceTCC);
    function secsInBot(uint userID) external view returns (uint secsInBot);
    function inBotSince(uint userID) external view returns (uint inBotSince);
    function nextTimeUpkeep(uint userID) external view returns (uint nextTimeUpkeep);
    function lastTimeRewarded(uint userID) external view returns (uint lastTimeRewarded);
    function cumulativeTCUpkeep(uint userID) external view returns (uint cumulativeTCUpkeep);
    function operatingDepositTC(uint userID) external view returns (uint operatingDeposit);

    function t() external view returns (uint8 t);

    function vested(uint userID, uint index) external view returns (uint vested);

    function totalVestedTC() external view returns (uint totalVestedTC);

    function pendingWithdrawalTC(uint userID) external view returns (uint pendingWithdrawalTC);
    function isBadUser(uint userID) external view returns (bool isBadUser);

    function checkVestingHash(bytes32 testSubject) external view returns (bool isCorrectHash);

    function vestingHashMigrated() external view returns (bytes32 vestingHashMigrated); // this needs to be set to the incoming hash
    function vestingHashLength() external view returns (uint vestingHashLength);

    function totalBalanceTC() external view returns (uint totalBalanceTC);
    function nextTimeUpkeepGlobal() external view returns (uint nextTimeUpkeepGlobal);

    function tccNextUserToReward() external view returns (uint tccNextUserToReward);
    function tccInEscrow() external view returns (int tccInEscrow);
    function tccTimeFrozen() external view returns (uint tccTimeFrozen);
    function tccTimeToMelt() external view returns (uint tccTimeToMelt);
    function tccTimeEnabled() external view returns (uint tccTimeEnabled);
    function contractIsFrozen() external view returns (bool contractIsFrozen);

    function aTokensArr(uint index) external view returns (address aToken);




    // ### AUTHORISATION FUNCTIONS ###
    function selfLevel(address sender) external view returns (bool hasSelfLevelAuth);

    function adminLevel(address sender) external view returns (bool hasAdminLevelAuth);

    function editorLevel(address sender) external view returns (bool hasEditorLevelAuth);

    function weeklyFeeLevel(address sender) external view returns (bool hasWeeklyFeeLevelAuth);

    function presaleLevel(address sender) external view returns (bool hasPresaleLevelAuth);

    function sysGetLevel(address sender) external view returns (bool hasSysGetLevelAuth);




    // ### GETTER FUNCTIONS ###
    function getBotTraders() external view returns (address[] memory BotTraders);

    function getSender(address account) external view returns (address sender);

    function getTradingWallets() external view returns (address[] memory tradingWallets);

    function getaTokens() external view returns (address[] memory aTokens);

    function getNextUserIDToUpkeep() external view returns (uint nextUserIDToUpkeep);

    function libNextBadUserID() external view returns (uint nextBadUserID);

    function getCurrentIndexOfBadUserIDs() external view returns (uint nextBadUserID);

    function getCumulativeTCUpkeep(address account) external view returns (uint cumulativeTCUpkeep);

    function getBadUserIDs() external view returns (uint[] memory badUserIDs);

    function getBadUserAddresses() external view returns (address[] memory badUserAddresses);

    function getNextUserIDToEvict() external view returns (uint nextUserIDToEvict);

    function getTotal_balance_entryPrice_debt() external view returns (uint totalBalance, uint entryPrice, uint entryPriceDecimals, uint totalDebt);

    function getVestedValues(uint userID) external view returns (uint[5] memory vestedValues);

    function getVestedSum(uint userID) external view returns (uint sum);

    function getTradeStatusOfID(uint userID) external view returns (int tradeStatus);

    function getTradeStatusOf(address account) external view returns (int tradeStatus);






    // ### SETTER FUNCTIONS ###
    // _selfAuth
    function setTotalVestedTC(uint value) external;

    function setBotController(address newBotController) external;

    function setContractIsFrozen(bool newContractIsFrozen) external;

    function setInfo(string[4] memory newInfo) external;

    function setMode(string memory newMode) external;

    function setTimeframe(string memory newTimeframe) external;

    function setStrategyName(string memory newStrategyName) external;

    function setDescription(string memory newDescription) external;

    function setPresale(address newPresale) external;

    function setWeeklyFeeWallet(address newWeeklyFeeWallet) external;

    function freezeMigrateVestedTC(bool vestingStatus) external;

    function migrateVestedTC(address newBotPool, bytes32 vestingHashArray) external;

    function saveUsersTCCRewards() external returns (uint status);

    // _selfAuth
    function setVested(uint userID, uint yrs, uint value) external;




    // ### DEPOSIT FUNCTIONS ###
    function depositPresale(address account, uint amountTC, uint8 yrs, uint amountTCC) external;

    function deposit(address sender, uint amountTC, uint amountCash, uint tcToApprove, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    // _selfAuth
    function _addUserEnd(address account, IBotTrader BotTrader) external returns (uint userID);

    // _selfAuth
    function _createNextBotTraderEnd(address newBotTrader) external;




    // ### WITHDRAW FUNCTIONS ###
    function withdraw(address account, uint amountTC, uint amountCash) external;

    function withdrawNow(address account, uint amountTC, uint amountCash, bytes calldata swapCallData) external;




    // ### WITHDRAW ALL FUNCTIONS ###
    function withdrawAll(address account, bool onlyCash) external;

    function withdrawAllNow(address account, bool onlyCash, bytes calldata swapCallData) external;

    function emergencyWithdrawAll(address sender, uint debtTokens) external;




    // ### TC/TCC REWARD AND PAYMENT FUNCTIONS ###
    function collectRewards(address account) external;

    function remainingVestedTCOfID(uint userID, uint yrs) external view returns (uint remainingVestedTC);

    function remainingVestedTCOf(address account, uint yrs) external view returns (uint remainingVestedTC);

    // _selfAuth
    function _processTCWithdrawal(uint userID, uint amountTC, bool partialWithdrawal) external; // Only for BotPoolLib's

    // _selfAuth
    function _processTCCWithdrawal(uint userID) external; // Only for BotPoolLib's

    // _selfAuth
    function _rawCalcTCC(address account, uint userID, bool hasCashInBot) external;

    // _selfAuth
    function _generateTCC(address account, uint userID, bool hasCashInBot) external; // Only for BotPoolLib's

    // function rewardsPerWeek(uint userID) external view returns (uint rewardsPerWeek);

    function rewardsPerWeekOf(address sender) external view returns (uint rewardsPerWeek);




    // ### UPKEEP FUNCTIONS ###
    function weeklyFee() external;

    function evictAllUsers() external  returns (uint nextUserToEvict);

    function ejectBadUser(address account) external;

    function ejectBadUserID(uint userID) external;

    function ejectBadUser_inTrade(address account, bytes calldata swapCallData) external;

    function ejectBadUserID_inTrade(uint userID, bytes calldata swapCallData) external;




    // ### EXPOSED FUNCTIONS ###
    function cancelPendingTransfers(address account) external;

    function _pctOperatingDeposit(uint userID, uint pctUserPositionRemoved) external view returns (uint amountOperatingDeposit);

    function subUserOperatingDepositTC(address account, uint pctUserPositionRemoved) external;

    function processPendingTCWithdrawal(address account) external;

    // _selfAuth
    function _addPendingWithdrawalTC(uint userID, uint amountTC) external;

    // _selfAuth
    function _withdrawAllTokens(address account, uint userID, bool hasCashInBot) external; // Only for BotPoolLib's

    function withdrawAllTokens(address account) external; // Only for BotTrader's

    function transferCashFrom(address from, address to, uint amountCash) external;

    function repayAllLoans(uint amountCash) external;

    function operBotPoolCashBalance(uint amountCash, bytes1 operation) external;

    function nftTransferNotification(address account) external; //_nftAdminAuth

    function removeTradingWallet(address removeMe) external;

    function addTradingWallet(address addMe) external;

    function rememberSecsInBot(address account) external;

    function setPresaleEnded() external; // Presale Auth only

    function reApprove() external;

    function returnTC_TCC() external;

    function claimERC20(address _token) external;

}