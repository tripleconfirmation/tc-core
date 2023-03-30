// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "./IBotController.sol";
import "./IBotPool.sol";
import "./IERC20.sol";

interface IBotTrader {

    // ### EVENTS ###
    event LongEntry(uint amountCash);
    event LongExit(uint amountCash);
    event AssetBorrowed(uint amount);
    event ShortEntry(uint amountCash);
    event ShortExit(uint amountCash);
    event DebtRepaid(uint amount);
    event BalancesUpdated(uint lastCashBalance);
    event PendingRequestsComplete(uint users);




    // ### VIEW FUNCTIONS ###
    function version() external view returns (string memory version);

    function botController() external view returns (IBotController botController);
    function botPool() external view returns (IBotPool botPool);

    function oneHundredPct() external view returns (uint oneHundredPct);
    function minGas() external view returns (uint minGas);

    function cash() external view returns (IERC20 cash);
    function asset() external view returns (IERC20 asset);

    function tradingWallet() external view returns (address tradingWallet);

    function staticsLength() external view returns (uint8 staticsLength); // MUST == BotTraderLib_util.staticsLength; == 27
    function valuesLength() external view returns (uint8 valuesLength); // MUST == BotTraderLib_withdraw.valuesLength == 6
    function numUsers() external view returns (uint numUsers);
    function activeUsers() external view returns (uint activeUsers);
    function maxUsers() external view returns (uint maxUsers);

    function userIDs(address userAddress) external view returns (uint userID);
    function userAddress(uint userID) external view returns (address userAddress);
    function withdrawAllType(uint userID) external view returns (uint8 withdrawAllType);
    function pendingWithdrawal(uint userID) external view returns (uint pendingWithdrawal);
    function pendingDeposit(uint userID) external view returns (uint pendingDeposit);
    function deposited(uint userID) external view returns (uint deposited);
    function balance(uint userID) external view returns (uint balance);
    function balanceTradeStart(uint userID) external view returns (uint balanceTradeStart);
    function totalChange(uint userID) external view returns (int totalChange);
    function totalFeePaid(uint userID) external view returns (uint totalFeePaid);
    function isActiveUser(uint userID) external view returns (bool isActiveUser);
    function balanceUpdated(uint userID) external view returns (bytes1 userBalanceIsUpdated); // array, not mapping

    function tradeStatus() external view returns (int tradeStatus);
    function isRepayingLoan() external view returns (bool isRepayingLoan);
    function lastCashBalance() external view returns (uint lastCashBalance);
    function entryPrice() external view returns (uint entryPrice);
    function pendingUser() external view returns (uint pendingUser);
    function pendingExecAllowed() external view returns (bool pendingExecAllowed);
    function balancesUser() external view returns (uint balancesUser);
    function balancesUpdated() external view returns (bool balancesUpdated);
    function tradeExitCashBalance() external view returns (uint tradeExitCashBalance);
    function balancesSum() external view returns (uint balancesSum);
    function emergencyShortPadding() external view returns (uint emergencyShortPadding);

    // function error_withdrawLongAsset() external view returns (string memory error_withdrawLongAsset);
    // function error_withdrawLongAssetOverswap() external view returns (string memory error_withdrawLongAssetOverswap);
    // function error_withdrawLongCashOverswap() external view returns (string memory error_withdrawLongCashOverswap);
    // function error_withdrawShortAssetOverswap() external view returns (string memory error_withdrawShortAssetOverswap);
    // function error_withdrawShortCashOverswap() external view returns (string memory error_withdrawShortCashOverswap);
    // function error_withdrawShortAssetTooLittle() external view returns (string memory error_withdrawShortAssetTooLittle);
    // function error_withdrawShortAssetTooMuch() external view returns (string memory error_withdrawShortAssetTooMuch);
    // function error_withdrawShortCashTooLittle() external view returns (string memory error_withdrawShortCashTooLittle);
    function errorStrings(uint index) external view returns (string memory errorString);

    // function pctSlippage() external view returns (uint pctSlipage);
    function API_SWAP_pcts() external view returns (uint[3] memory pcts);




    // ### AUTHORISATION FUNCTIONS ###
    function botPoolLevel(address sender) external view returns (bool hasBotPoolLevelAuth);

    function adminLevel(address sender) external view returns (bool hasAdminLevelAuth);

    function editorLevel(address sender) external view returns (bool hasEditorLevelAuth);

    function tradingLevel(address sender) external view returns (bool hasTradingLevelAuth);

    function botControllerLevel(address sender) external view returns (bool hasBotControllerLevelAuth);




    // ### GETTER FUNCTIONS ###
    function getBotTotalCashBalance() external view returns (uint BotTotalCashBalance);

    function getBalanceOfUserID(uint userID) external view returns (uint balanceOfUserID);

    function getBalanceOf(address account) external view returns (uint balanceOf);

    function getAssetBalance() external view returns (uint assetBalance);

    function getAssetDebt() external view returns (uint assetDebt);

    function hasBalanceUserID(uint userID) external view returns (bool hasBalance);

    function hasBalance(address account) external view returns (bool hasBalance);

    function getAAVEUserData() external view returns (uint[6] memory aaveUserData);

    function getAssetPrice() external view returns (uint assetPrice);

    function entryPriceDecimals() external view returns (uint entryPriceDecimals);

    function getTradeStatusOf(address account) external view returns (int tradeStatus);
    // Should always return the BotTrader's `tradeStatus` regardless of the `account` given.

    function getWithdrawEstimates(
        address account,
        uint BotTraderUserID,
        uint amountCash,
        bool withdrawNow
    ) external view returns (uint[6] memory withdrawEstimates); // 6 == valuesLength




    // ### SETTER FUNCTIONS ###
    function setBotController(IBotController newBotController) external;

    function setTradingWallet(address newTradingWallet) external;

    function setBalanceTradeStart(uint userID) external;




    // ### DEPOSIT FUNCTIONS ###
    function deposit(address account, uint amountCash) external;

    function addUser(address account) external;




    // ### CANCEL PENDING FUNCTIONS ###
    function cancelPendingTransfers(address account) external;




    // ### WITHDRAW FUNCTIONS ###
    function withdraw(uint userID, uint amountCash) external; // use only when `tradeStatus` == 0

    function withdrawNow(uint userID, uint amountCash, bytes calldata swapCallData) external;




    // ### WITHDRAW ALL FUNCTIONS ###
    function withdrawAll(uint userID, bool onlyCash) external;

    function withdrawAllNow(uint userID, bool onlyCash, bytes calldata swapCallData) external;

    // _selfAuth
    function _withdrawEnd(address account, uint userID, IERC20 token, uint[6] memory values) external; // 6 == valuesLength




    // ### EMERGENCY WITHDRAW ALL FUNCTIONS ###
    function emergencyWithdrawAll(address account) external; // team callable




    // ## LONG FUNCTIONS ##
    function longEntry(bytes calldata swapCallData) external;

    function longExit(bytes calldata swapCallData) external;




    // ### SHORT FUNCTIONS ###
    function shortEntry_getAmountToBorrow() external view returns (uint amountToBorrow);

    function shortEntry(bytes calldata swapCallData) external;

    function shortExit(bytes calldata swapCallData) external;




    // ### TRADE EXIT FUNCTIONS ###
    // _selfAuth
    function _tradeEntry_updateBalances() external;

    function tradeExit_updateBalances() external;

    function tradeExit_handlePending() external;

    function addToEmergencyShortPadding(uint amount) external; // Library only




    // ### TEAM FUNCTIONS ###
    function reApprove() external;

    function claimERC20(address token) external;
}