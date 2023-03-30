// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "../libraries/BotControllerLib_structs.sol";

import "./IBaked.sol";
import "./IERC20.sol";
import "./IERC20T.sol";
import "./INFTAdmin.sol";


interface IBotController is IBaked {

	// ### VIEW FUNCTIONS ###
	function version() external view returns (string memory version);

	function oneHundredPct() external view returns (uint oneHundredPct);

	function cash() external view returns (IERC20 cash);
	function tc() external view returns (IERC20T tc);
	function tcc() external view returns (IERC20T tcc);

	function frontend() external view returns (address frontend);
	function nftAdmin() external view returns (INFTAdmin NFTAdmin);
	function botFactory() external view returns (address BotFactory);

	// `_` apended to clearly show returned variable is an internal variable -- an element in an array.
	function originalContracts(uint index) external view returns (address _contract);
	function getOriginalContracts() external view returns (address[] memory originalContracts);

	function treasuryWallet() external view returns (address treasuryWallet);

	function weeklyFeeTimeSlippage() external view returns (uint weeklyFeeTimeSlippage);
	function secPerWeek() external view returns (uint secPerWeek);
	function secPerYear() external view returns (uint secPerYear);
	function maxSingleLoopSize() external view returns (uint maxSingleLoopSize);
	function strMaxSingleLoopSize() external view returns (string memory strMaxSingleLoopSize);
	function maxPendingTX() external view returns (uint maxPendingTX);
	function minGas() external view returns (uint minGas);

	function feeReductions(uint index) external view returns (uint _feeReduction);
	function getFeeReductions() external view returns (uint[] memory feeReductions);

	function apr() external view returns (uint apr);
	function aprBotBonus() external view returns (uint aprBotBonus);
	function minReqBalCash() external view returns (uint minReqBalCash);
	function minReqBalTC() external view returns (uint minReqBalTC);

	function operatingDepositRatio() external view returns (uint operatingDepositRatio);

	function lastTimeUpkeepModified() external view returns (uint lastTimeUpkeepModified);
	function tcUpkeep() external view returns (uint tcUpkeep);
	function minFutureWeeksTCDeposit() external view returns (uint8 minFutureWeeksTCDeposit);

	function lastTimeProfitFeeModified() external view returns (uint lastTimeProfitFeeModified);
	function weeklyFeeWallet() external view returns (address weeklyFeeWallet);
	// Must be Editor or higher authorisation to view.
	function getLoopWallet() external view returns (address loopWallet);

	// Must be Editor or higher authorisation to view.
	function getLoopWalletFrontend(address sender) external view returns (address loopWallet);

	function botPoolMaxCash() external view returns (uint botPoolMaxCash);
	function perUserMaxCash() external view returns (uint perUserMaxCash);
	function profitFee() external view returns (uint profitFee);

	function profitFeePenalty() external view returns (uint profitFeePenalty);
	function slippagePct() external view returns (uint slippagePercentage);

	function reservePct() external view returns (uint reservePercentage);
	function borrowPct() external view returns (uint borrowPercentage);
	function dexFeePct() external view returns (uint dexFeePercentage);
	function overswapPct() external view returns (uint overswapPercentage);
	function overswapMaxCash() external view returns (uint overswapMaxCash);
	function minBalQualifyPct() external view returns (uint minBalQualifyPercentage);
	function shortSlippagePct() external view returns (uint shortSlippagePercentage);
	function shortEmergencySlippagePct() external view returns (uint shortEmergencySlippagePct);

	function maxEditors() external pure returns (uint maxEditors);
	function numEditors() external view returns (uint numEditors);

	// Must be Editor or higher authorisation to view.
	function getIsEditor(address account) external view returns (bool isEditor);

	// Must be Editor or higher authorisation to view.
	function getEditorList() external view returns (BotControllerLib_structs.Editor[] memory editorList);

	// Must be Editor or higher authorisation to view.
	function getEditorListFrontend(address sender) external view returns (BotControllerLib_structs.Editor[] memory editorList);

	// Must be Editor or higher authorisation to view.
	function getSetNewBotController_nextBotPool() external view returns (address setNewBotController_nextBotPool);

	// Must be Editor or higher authorisation to view.
	function getSetNewBotController_nextBotPoolFrontend(address sender) external view returns (address setNewBotController_nextBotPool);

	// Must be Editor or higher authorisation to view.
	function getSignableTransactions() external view returns (BotControllerLib_structs.SignableTransaction[] memory signableTransactions);

	// Must be Editor or higher authorisation to view.
	function getSignableTransactionsFrontend(address sender) external view returns (BotControllerLib_structs.SignableTransaction[] memory signableTransactions);

	function permittedUser(address account) external view returns (bool isPermittedUser);
	function inPermittedUsersList(address account) external view returns (bool isInPermittedUsersList);
	function permittedUsersList(uint index) external view returns (address _user);

	function getPermittedUsersList() external view returns (address[] memory permittedUsersList);

	function nextPermittedUserToDelete() external view returns (uint nextPermittedUserToDelete);

	function sanctionedUser(address account) external view returns (bool isSanctionedUser);
	function inSanctionedUsersList(address account) external view returns (bool isInSanctionedUsersList);
	function sanctionedUsersList(uint index) external view returns (address _user);

	function getSanctionedUsersList() external view returns (address[] memory sanctionedUsersList);

	function nextSanctionedUserToDelete() external view returns (uint nextSanctionedUserToDelete);

	function minReqNFTLevel() external view returns (uint minReqNFTLevel);




	// ### AUTHORISATION FUNCTIONS ###
	function adminLevel(address sender) external returns (bool hasAdminLevelAuth);

	function editorLevel(address sender) external returns (bool hasEditorLevelAuth);

	function loopLevel(address sender) external returns (bool hasLoopLevelAuth);

	function sysGetLevel(address sender) external view returns (bool hasSysGetLevelAuth);




	// ### GETTER FUNCTIONS ###
	function pctFeeReductionOf(address account) external view returns (uint pctFeeReduction);

	function pctFeeOwedOf(address account) external view returns (uint pctFeeOwed);

	function pctProfitFeeOf(address account) external view returns (uint pctProfitFee);

	function pctPenaltyFeeOf(address account) external view returns (uint pctPenaltyFee);

	function pctRewardRateOf(address account, bool cashInBot) external view returns (uint pctRewardRate);

	function tcFeeOf(address account) external view returns (uint tcFee);

	function tccRewardCalcOf(address sender, bool cashInBot, int time, uint userTC) external view returns (uint tccRewardPerWeek);

	function tcReqUpkeepPaymentOf(address account, int time) external view returns (uint prepayUpkeepPaymentTC);

	function tcReqOperatingDepositOf(address account, uint amountCash) external view returns (uint operatingDepositTC);

	// function tcReqDepositOf(address account, uint amountCash, int time) external view returns (uint reqTCDeposit);




    // ### ADMIN FUNCTIONS TO MANAGE EDITORS ###
	// Only `adminWallet` can exec.
	function clearSignableTransactions() external;

	// Only `adminWallet` can exec.
	function addEditor(address _editor) external;

	// Only `adminWallet` can exec.
	function removeEditor(address _editor) external;




	// ### EDITOR TX FUNCTIONS ###
	// Only callable by internal functions, not any external entity.
	function doMultisig(
		address sender,
		string memory functionName,
		uint[] memory uintArr,
		address[] memory addressArr) external returns (bool runFunction);




	// ### SETTER FUNCTIONS ###
	// Must be Editor or higher authorisation to exec.
	function setBotFactory(address _BotFactory) external;

	// Must be Editor or higher authorisation to exec.
	function setBotPoolIsFrozen(address _BotPool, bool newContractIsFrozen) external;

	// Only `adminWallet` can exec.
	function setTreasuryWallet(address newTreasuryWallet) external;

	// Must be Editor or higher authorisation to exec.
	function setFrontend(address newFrontend) external;

	// Must be Editor or higher authorisation to exec.
	function setNftAdmin(address newNFTAdmin) external;

	// Must be Editor or higher authorisation to exec.
	function setMinReqNFTLevel(uint newMinReqNFTLevel) external;

	// Only `adminWallet` can exec.
	function setFeeReductions(uint[] memory newFeeReductions) external;

	// Only `adminWallet` can exec.
	function setApr(uint newApr) external;

	// Must be Editor or higher authorisation to exec.
	function setMinReqBalCash(uint newMinReqCashBal) external;

	// Only `adminWallet` can exec.
	function setOperatingDepositRatio(uint newOperatingDepositRatio) external;

	// Must be Editor or higher authorisation to exec.
	function setTCUpkeep(uint newTCUpkeep) external;

	// Must be Editor or higher authorisation to exec.
	function setMinFutureWeeksTCDeposit(uint8 newMinFutureWeeksTCDeposit) external;

	// Only `adminWallet` can exec.
	function setProfitFee(uint newProfitFee) external;

	// Only `adminWallet` can exec.
	function setPenaltyFee(uint newPenaltyFee) external;

	// Must be Editor or higher authorisation to exec.
	function setWeeklyFeeWallet(address newWeeklyFeeWallet, address botPool) external;

	// Must be Editor or higher authorisation to exec.
	function setBotPoolMaxCash(uint newBotPoolMaxCash) external;

	// Must be Editor or higher authorisation to exec.
	function setPerUserMaxCash(uint newPerUserMaxCash) external;

	// Must be Editor or higher authorisation to exec.
	function setPercentages(uint[] memory newPercentages) external;

	// NEW for Alpha v2
	// Must be Editor or higher authorisation to exec.
	function setOverswapMaxCash(uint newOverswapMaxCash) external;
	
	// NEW for Alpha v2
	// Requires `loopLevel` auth.
	function erasePermittedUsersList() external;

	// NEW for Alpha v2
	// Must be Editor or higher authorisation to exec.
	function setPermittedUsersList(address[] memory accounts, uint[] memory isPermitted) external;

	// NEW for Alpha v2
	// Requires `loopLevel` auth.
	function eraseSanctionedUsersList() external;

	// NEW for Alpha v2
	// Must be Editor or higher authorisation to exec.
	function setSanctionedUsersList(address[] memory accounts, uint[] memory isSanctioned) external;

	// NEW for Alpha v2
	// Only `adminWallet` can exec.
	function setLoopWallet(address newLoopWallet) external;

	// NEW for Alpha v2
    // How to use:
    //    - Set `loopWallet`
    //    - `loopWallet` runs this function over and over until completed, trimming the list of BotPools after each Tx
    //    -- OR --
    //    - Multi-Sig `adminWallet` can run over and over again manually
	// Requires `loopLevel` auth.
	function loop_setBotPoolIsFrozen(bool frozenStatus, address[] memory botPools) external;

	// NEW for Alpha v2
    // How to use:
    //    - Set `loopWallet`
    //    - `loopWallet` runs this function over and over until completed, trimming the list of BotTraders after each Tx
    //    -- OR --
    //    - Multi-Sig `adminWallet` can run over and over again manually
	// Requires `loopLevel` auth.
	function loop_setTradingWallet(address newTradingWallet, address[] memory botTraders) external;

	// NEW for Alpha v2
    // How to use:
    //    - Set `loopWallet`
    //    - `loopWallet` runs this function over and over until completed, trimming the list of BotPools after each Tx
    //    -- OR --
    //    - Multi-Sig `adminWallet` can run over and over again manually
	// Requires `loopLevel` auth.
    function loop_setTCCRewardsFrozen(bool usersShouldEarnRewards, address[] memory botPools) external;

	// NEW for Alpha v2
    // How to use:
    //    - Set `loopWallet`
    //    - `loopWallet` runs this function over and over until completed, trimming the list of BotPools after each Tx
    //    -- OR --
    //    - Multi-Sig `adminWallet` can run over and over again manually
	// Requires `loopLevel` auth.
    function loop_setNewBotController(address newBotController, address[] memory botPools) external;




	// ### MISC FUNCTIONS ###
	// NEW for Alpha v2
	// Requires `loopLevel` auth.
	function loop_evictAllUsers(address botPool) external;

	// NEW for Alpha v2
	// Must be Editor or higher authorisation to exec.
	function weeklyFee(address botPool) external;

	// NEW for Alpha v2
	// Must be Editor or higher authorisation to exec.
    function ejectBadUser(address botPool, address account, bool useEmergency) external;

    // NEW for Alpha v2 -- 0.1 Kb
	// Must be Editor or higher authorisation to exec.
    function ejectBadUserID(address botPool, uint userID, bool useEmergency) external;

	// NEW for Alpha v2
	// Requires `loopLevel` auth.
	function freezeMigrateVestedTC(address botPool, bool vestingStatus) external;

	// NEW for Alpha v2
	// Allows anyone to send tokens to the `treasuryWallet` that were accidentally received at this address.
    function claimERC20(address token) external;

}