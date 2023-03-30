// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "../libraries/BotTraderLib_withdraw.sol";
import "../libraries/FrontendLib_getUser.sol";
import "../libraries/FrontendLib_getInfo.sol";
import "../libraries/FrontendLib_getInfoAdmins.sol";
import "../libraries/FrontendLib_depositWithdraw.sol";
import "../libraries/FrontendLib_vestedTC.sol";

import "./IERC20.sol";
import "./IERC20T.sol";
import "./IBotController.sol";
import "./IBotTrader.sol";

// import "../Frontend.sol";

interface IFrontend {

    // ### VIEW FUNCTIONS ###
    function version() external view returns (string memory version);

    function botController() external view returns (address botController);

    function BotController() external view returns (IBotController BotController);

    function pctOneHundred() external view returns (uint pctOneHundred);

    function pctCashPnL(uint index) external view returns (uint pctCashPnLAtIndex);

    function editorLevel(address sender) external view returns (bool hasEditorLevel);




    // ### VIEW FUNCTIONS ###
    function setBotController(address _newBotController) external;

    function setPctCashPnL(uint[2] calldata _pctCashPnL) external;




    // ### GETTER FUNCTIONS ###
    function getUser(address botPool, address account) external view returns (FrontendLib_getUser.GetUserStruct memory user);

    function getUserOf(address botPool) external view returns (FrontendLib_getUser.GetUserStruct memory user);

    function getInfo(address botPool) external view returns (FrontendLib_getInfo.Info memory info);

    function getBotTraderObject(address botPool) external view returns (FrontendLib_getInfo.BotTradersAdmins memory botTraderAdmins);




    // ### WITHDRAW AMOUNTS FUNCTIONS ###
    function getWithdrawEstimates(
        address botPool,
        uint amountTC,
        uint amountCash,
        bool withdrawNow_
    ) external view returns (FrontendLib_depositWithdraw.WithdrawEstimates memory withdrawEstimates);

    function getWithdrawEstimatesOf(
        address botPool,
        address account,
        uint amountTC,
        uint amountCash,
        bool withdrawNow_
    ) external view returns (FrontendLib_depositWithdraw.WithdrawEstimates memory withdrawEstimates);




    // ### DEPOSIT AMOUNTS FUNCTIONS ###
    function getDepositEstimates(
        address botPool,
        uint amountTC,
        uint amountCash
    ) external view returns (FrontendLib_depositWithdraw.DepositEstimates memory depositEstimates);

    function getDepositEstimatesOf(
        address botPool,
        address account,
        uint amountTC,
        uint amountCash
    ) external view returns (FrontendLib_depositWithdraw.DepositEstimates memory depositEstimates);




    // ### TRADE GETTER FUNCTIONS ###
    function cashBalanceOf(address botTrader) external view returns (uint cashBalance);

    function assetBalanceOf(address botTrader) external view returns (uint assetBalance);

    function longEntry_sellCash(address botTrader) external view returns (uint longEntry_sellCash);

    function longExit_sellAsset(address botTrader) external view returns (uint longExit_sellAsset);

    function shortEntry_sellAsset(address botTrader) external view returns (uint shortEntry_sellAsset);

    function shortExit_buyAsset(address botTrader) external view returns (uint shortExit_buyAsset);

    function getTradeStatusOf(address botTrader) external view returns (int tradeStatus);

    function getBotTotalCashBalance(address botTrader) external view returns (uint botTotalCashBalance);




    // ### DEPOSIT FUNCTIONS ###
    // TC and/or cash
    // Pending during a trade
    function deposit(address BotPool, uint amountTC, uint amountCash) external;

    function depositWithPermit(address botPool, uint amountTC, uint amountCash, uint tcToApprove, uint deadline, uint8 v, bytes32 r, bytes32 s) external;




    // ### WITHDRAW FUNCTIONS ###
    function withdraw(address BotPool, uint amountTC, uint amountCash) external;

    // Immediate during a trade
    function withdrawNow(address BotPool, uint amountTC, uint amountCash, bytes calldata swapCallData) external;




    // ### WITHDRAW ALL FUNCTIONS ###
    // Pending during a trade
    function withdrawAll(address BotPool, bool onlyCash) external;

    // Immediate during a trade
    function withdrawAllNow(address BotPool, bool onlyCash, bytes calldata swapCallData) external;

    // TC and cash
    // Immediate during a trade
    // Will return tokens in addition to/instead of cash token during a trade
    function emergencyWithdrawAllWithDebt(address BotPool, uint debtTokens) external;

    function emergencyWithdrawAll(address BotPool) external;




    // ### CANCEL PENDING FUNCTIONS ###
    function cancelPendingTransfers(address BotPool) external;




    // ### COLLECT FARM REWARDS FUNCTION ###
    function collectRewards(address botPool) external;




    // ### VESTED FUNCTIONS ###
    function t() external returns (uint8 t);

    function checkVestedTC_vs_newBotPool(address botPool, address newBotPool) external view returns (bool isCorrectHash, uint lastUserIDChecked);

    function checkVestedTC_vs_unnamedArrays(
        address botPool,
        address[] calldata userAddress,
        uint[5][] calldata vested
    ) external view returns (bool isCorrectHash, uint lastUserIDChecked);

    function getVestedTCUnnamed(address botPool) external view returns (uint[5][] memory vestedTCUnnamed);

    function getUserAddresses(address botPool) external view returns (address[] memory userAddresses);

    function getVestingHashFromUnnamed(address botPool, address[] calldata userAddress, uint[5][] calldata vested) external view returns (bytes32 vestingHashFromUnnamed);

    function checkVestedTC_vs_namedArray(address botPool, FrontendLib_vestedTC.Vested[] calldata vestedObj) external view returns (bool isCorrectHash, uint lastUserIDChecked);

    function getVestedTCNamed(address botPool) external view returns (FrontendLib_vestedTC.Vested[] memory vestedTCNamed);

    function getVestingHashFromNamed(address botPool, FrontendLib_vestedTC.Vested[] calldata vestedObj) external view returns (bytes32 vestingHashFromNamed);




    // ### TEAM FUNCTIONS ###
    function claimERC20(address token) external;

    function getInfoAdmins(address botPool) external view returns (FrontendLib_getInfoAdmins.AdminInfo memory infoAdmins);

}