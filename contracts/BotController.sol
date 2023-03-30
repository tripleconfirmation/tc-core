// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "./Baked.sol";

import "./libraries/API_SWAP.sol";
import "./libraries/Caffeinated.sol";

import "./libraries/BotControllerLib_structs.sol";
import "./libraries/BotControllerLib_util.sol";

import "./interfaces/IBotController.sol";
import "./interfaces/IBotPool.sol";
import "./interfaces/IBotTrader.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC20T.sol";
import "./interfaces/INFTAdmin.sol";

// import "hardhat/console.sol";

contract BotController is Baked {

    string public constant version = "2023-01-31 | Alpha v2";

    // ensure identical to Caffeinated.precision -> 10 ** 18
    uint public constant oneHundredPct = Caffeinated.precision;

    IERC20 public immutable cash;
    IERC20T public immutable tc;
    IERC20T public immutable tcc;

    address public frontend;
    INFTAdmin public nftAdmin;
    address public botFactory;

    address[] public originalContracts;
    function getOriginalContracts() external view returns (address[] memory) {
        return originalContracts;
    }

    address public treasuryWallet;

    uint public constant weeklyFeeTimeSlippage = 21600; // 6 hours
    uint public constant secPerWeek = 604800;
    uint public constant secPerYear = 31536000;
    uint public constant maxSingleLoopSize = 1500;
    string public constant strMaxSingleLoopSize = "1500";
    uint public constant maxPendingTX = 10;
    uint public constant minGas = 200000;

    uint[] public feeReductions = [ 0, 25, 50, 75, 100 ];
    function getFeeReductions() external view returns (uint[] memory) {
        return feeReductions;
    }

    uint public apr = 21;
    uint public aprBotBonus = 2 * apr;
    uint public minReqBalCash = 1;
    function minReqBalTC() public view returns (uint) {
        uint _tcUpkeep = tcUpkeep;
        uint _reqTC;

        for (uint8 i = 1; i <= minFutureWeeksTCDeposit; ++i) {
            _tcUpkeep += uint((_tcUpkeep + 19) / 20);
            _reqTC += _tcUpkeep;
        }

        return _reqTC;
    }

    uint public operatingDepositRatio = 10;

    uint public lastTimeUpkeepModified = block.timestamp;
    uint public tcUpkeep = 100;
    uint8 public minFutureWeeksTCDeposit = 1;

    uint public lastTimeProfitFeeModified = block.timestamp;
    address public weeklyFeeWallet;
    address private loopWallet;

    function getLoopWallet() external view returns (address) {
        return getLoopWalletFrontend(msg.sender);
    }

    function getLoopWalletFrontend(address sender) public view returns (address) {
        require(
            sysGetLevel(sender),
            "TEAM | AUTH: Sender of `getLoopWallet()` must be a member of the admin team."
        );
        return loopWallet;
    }

    uint public botPoolMaxCash = 42000;
    uint public perUserMaxCash = 1000;
    uint public overswapMaxCash = 1000;   // = 1000 USDC

    uint public profitFee = 10;
    uint public profitFeePenalty = 50;

    uint public slippagePct = 125;                  // ==   .125%
    uint public reservePct = 12000;                 // == 12%
    uint public borrowPct = 68000;                  // == 68%
    uint public dexFeePct = 300;                    // ==   .3%
    uint public overswapPct = 3000;                 // ==  3%
    uint public minBalQualifyPct = 98000;           // == 98%
    uint public shortSlippagePct = 475;             // ==   .475% | lower percent favours First User | higher percent favours Last User
    uint public shortEmergencySlippagePct = 3000;   // ==  3%
    // `shortSlippagePct` is used in two scenarios, both of which occur when withdrawing immediately while the Bot is Short:
    // --> To bill an estimated Slippage amount when each user runs `withdrawNow()`, and
    // --> To ensure sufficient debt padding exists when each user runs `emergencyWithdrawAll()`.

    
    function maxEditors() public pure returns (uint) {
        return maxSingleLoopSize;
    }
    uint public numEditors;
    mapping(address => uint) private editorIDs;
    mapping(uint => address) private editorAddresses;
    mapping(uint => bool) private isEditor;

    // >>    Should we lock `getIsEditor()` down somehow?   <<
    // Only issue is that BotPools and BotTraders need to be able to reach
    // the variable and they're not registered in any manner with this BotController.
    function getIsEditor(address account) external view returns (bool) {
        return isEditor[editorIDs[account]];
    }

    // About 0.8 Kb better to keep the Editor List generation in this contract rather than put in a library.

    // 0.7 Kb
    // Use from the outside as an Editor to grab the list.
    // Otherwise use the Frontend.sol contract to grab.
    function getEditorList() external view returns (BotControllerLib_structs.Editor[] memory) {
        return getEditorListFrontend(msg.sender);
    }

    function getEditorListFrontend(address sender) public view returns (BotControllerLib_structs.Editor[] memory) {
        require(
            sysGetLevel(sender),
            "TEAM | AUTH: Sender of `getEditorList()` must be a member of the admin team."
        );
        return _getEditorList();
    }

    function _getEditorList() private view returns (BotControllerLib_structs.Editor[] memory) {
        BotControllerLib_structs.Editor[] memory editorList = new BotControllerLib_structs.Editor[](numEditors);
        uint editorCount;

        // We need two loops since `editorIDs` cannot be reused, thus when someone
        // is added as an Editor then removed as an Editor, their ID still persists
        // but they've lost the role. Hence we make one list as large as all editors
        // that have ever existed, then pair it down to only those who still possess
        // credentials.
        for (uint i = 1; i <= numEditors; ++i) {
            if (isEditor[i]) {
                editorList[editorCount].editorID = i;
                editorList[editorCount].editorAddress = editorAddresses[i];
                ++editorCount;
            }
        }
        
        return editorList;
    }

    address private setNewBotController_nextBotPool;

    function getSetNewBotController_nextBotPool() external view returns (address) {
        return getSetNewBotController_nextBotPoolFrontend(msg.sender);
    }

    function getSetNewBotController_nextBotPoolFrontend(address sender) public view returns (address) {
        require(
            sysGetLevel(sender),
            "TEAM | AUTH: Sender of `getSetNewBotController_nextBotPool()` must be a member of the admin team."
        );
        return setNewBotController_nextBotPool;
    }

    BotControllerLib_structs.SignableTransaction[] private signableTransactions;

    function getSignableTransactions() external view returns (BotControllerLib_structs.SignableTransaction[] memory) {
        return getSignableTransactionsFrontend(msg.sender);
    }

    function getSignableTransactionsFrontend(address sender) public view returns (BotControllerLib_structs.SignableTransaction[] memory) {
       require(
            sysGetLevel(sender),
            "TEAM | AUTH: Sender of `getSignableTransactions()` must be a member of the admin team."
        );
        return signableTransactions;
    }

    mapping(address => bool) public permittedUser;
    mapping(address => bool) public inPermittedUsersList;
    address[] public permittedUsersList;

    function getPermittedUsersList() external view returns (address[] memory) {
        return permittedUsersList;
    }

    uint public nextPermittedUserToDelete;

    mapping(address => bool) public sanctionedUser;
    mapping(address => bool) public inSanctionedUsersList;
    address[] public sanctionedUsersList;

    function getSanctionedUsersList() external view returns (address[] memory) {
        return sanctionedUsersList;
    }

    uint public nextSanctionedUserToDelete;

    uint public minReqNFTLevel = 1;

    // `_contracts` must consist of:
    //  -> [0] ERC-20 cash
    //  -> [1] ERC-20 TC
    //  -> [2] ERC-20 TCC
    //  -> [3] Frontend
    //  -> [4] nftAdmin
    //  -> [5] BotFactory
    //  -> [6] BotController == `address(this)`
    constructor(address[] memory _contracts) {
        adminWallet = msg.sender;

        cash = IERC20T(_contracts[0]);
        tc = IERC20T(_contracts[1]);
        tcc = IERC20T(_contracts[2]);

        uint _decimalsTC = 10 ** tc.decimals();
        tcUpkeep *= _decimalsTC;
        treasuryWallet = tc.treasuryWallet();

        frontend = _contracts[3];
        nftAdmin = INFTAdmin(_contracts[4]);
        botFactory = _contracts[5];

        originalContracts = _contracts;
        originalContracts.push(address(this));

        profitFee *= oneHundredPct / 100;
        profitFeePenalty *= oneHundredPct / 100;

        uint _decimalsCash = 10 ** cash.decimals();
        minReqBalCash *= _decimalsCash;
        botPoolMaxCash *= _decimalsCash;
        perUserMaxCash *= _decimalsCash;
        overswapMaxCash *= _decimalsCash;

        for (uint i; i < feeReductions.length; ++i) {
            feeReductions[i] *= oneHundredPct / 100;
        }

        apr *= oneHundredPct / 100;
        aprBotBonus *= oneHundredPct / 100;

        operatingDepositRatio *= oneHundredPct;

        slippagePct                 *= oneHundredPct / 100000;  //   .125%
        reservePct                  *= oneHundredPct / 100000;  // 12%
        borrowPct                   *= oneHundredPct / 100000;  // 68%
        dexFeePct                   *= oneHundredPct / 100000;
        overswapPct                 *= oneHundredPct / 100000;
        minBalQualifyPct            *= oneHundredPct / 100000;
        shortSlippagePct            *= oneHundredPct / 100000;  //   .475%
        shortEmergencySlippagePct   *= oneHundredPct / 100000;  //  2.25%
    }




    // ### AUTHORISATION FUNCTIONS ###
    modifier _selfAuth() {
        require(
            msg.sender == address(this),
            "TEAM | AUTH: No external execution permitted."
        );
        _;
    }

    function adminLevel(address sender) public returns (bool) {
        _checkTXTimestamps();
        return sender == adminWallet;
    }

    modifier _adminAuth() override {
        require(
            adminLevel(msg.sender),
            "TEAM | AUTH: Sender is not the Admin Wallet."
        );
        _;
    }

    function editorLevel(address sender) public returns (bool) {
        return adminLevel(sender) || isEditor[editorIDs[sender]];
    }

    modifier _editorAuth() {
        require(
            editorLevel(msg.sender),
            "TEAM | AUTH: Sender is not an Editor or the Admin Wallet."
        );
        _;
    }

    function loopLevel(address sender) public returns (bool) {
        return editorLevel(sender) || sender == loopWallet;
    }

    modifier _loopAuth() {
        require(
            loopLevel(msg.sender),
            "TEAM | AUTH: Sender is not the Admin Wallet or the Loop Wallet."
        );
        _;
    }

    function sysGetLevel(address sender) private view returns (bool) {
        return (msg.sender == sender || msg.sender == frontend || msg.sender == address(this))
            && isEditor[editorIDs[sender]] || sender == adminWallet || sender == loopWallet;
    }




    // ### GETTER FUNCTIONS ###
    function pctFeeReductionOf(address account) public view returns (uint) {
        return feeReductions[nftAdmin.highestLevelOf(account)];
    }

    function pctFeeOwedOf(address account) public view returns (uint) {
        return oneHundredPct - pctFeeReductionOf(account);
    }

    function pctProfitFeeOf(address account) public view returns (uint) {
        return profitFee * pctFeeOwedOf(account) / oneHundredPct;
    }

    function pctPenaltyFeeOf(address account) public view returns (uint) {
        return profitFeePenalty * pctFeeOwedOf(account) / oneHundredPct;
    }

    function pctRewardRateOf(address account, bool hasCashInBot) public view returns (uint) {
        uint _rewardRatePct = apr;

        if (hasCashInBot) {
            _rewardRatePct += apr;

            uint _nftLevelPct = pctFeeReductionOf(account);
            if (_nftLevelPct > 0) {
                _rewardRatePct += (apr * nftAdmin.highestLevelOf(account));
            }
        }

        return _rewardRatePct;
    }

    function tcFeeOf(address account) public view returns (uint) {
        return tcUpkeep * pctFeeOwedOf(account) / oneHundredPct;
    }

    function tccRewardCalcOf(address account, bool hasCashInBot, int time, uint userTC) public view returns (uint) {
        uint _apr = pctRewardRateOf(account, hasCashInBot);
        uint uTime;

        if (time >= 0) {
            uTime = uint(time);
        }
        else {
            uTime = secPerWeek;
        }

        uint TCCPerWeek =
            userTC
            * _apr
            * uTime
            / secPerYear
            / oneHundredPct;

        return TCCPerWeek;
    }

    function tcReqUpkeepPaymentOf(address account, int time) public view returns (uint) {
        uint _TCDeposit;

        if (time >= 0) {
            _TCDeposit = uint(time);
        }
        else {
            _TCDeposit = secPerWeek;
        }

        _TCDeposit *= (tcUpkeep * pctFeeOwedOf(account));

        return _TCDeposit / secPerWeek / oneHundredPct;
    }

    function tcReqOperatingDepositOf(address account, uint amountCash) public view returns (uint) {
        return oneHundredPct * amountCash * pctFeeOwedOf(account) * tc.decimals() / cash.decimals() / operatingDepositRatio / oneHundredPct;
    }

    // To be used when a user is going to deposit. Returns the amount of `tc` they must have on-deposit alongside the `cash`.
    // function tcReqDepositOf(address account, uint amountCash, int time) external view returns (uint) {
    //     return minReqBalTC() + tcReqUpkeepPaymentOf(account, time) + tcReqOperatingDepositOf(account, amountCash);
    // }




    // ### ADMIN FUNCTIONS TO MANAGE EDITORS ###
    function clearSignableTransactions() external _adminAuth {
        delete signableTransactions;
    }

    function addEditor(address _editor) external _adminAuth {
        if (isEditor[editorIDs[_editor]]) {
            return;
        }

        require(
            numEditors < maxEditors(),
            string.concat(
                "TEAM | ADD EDITOR: Maximum number of editors ever (",
                Caffeinated.uintToString(maxEditors()),
                ") permitted reached."
            )
        );

        // we start at index 1 to ensure index 0 returns false as a base case for unregistered peeps
        ++numEditors;

        editorIDs[_editor] = numEditors;
        editorAddresses[numEditors] = _editor;
        isEditor[numEditors] = true;
    }

    function removeEditor(address _editor) external _adminAuth {
        uint editorID = editorIDs[_editor];
        isEditor[editorID] = false;

        for (uint i; i < signableTransactions.length; ++i) {
            uint signatureIndex = _getSignatureIndex(i, editorID);
            bool hasSigned = signatureIndex != type(uint).max;

            if (hasSigned) {
                _unsignTX(i, signatureIndex);
                _checkSignatures(i);
            }
        }
    }




    // ### EDITOR TX FUNCTIONS ###
    function _getSignatureIndex(uint TX, uint editorID) private view returns (uint) {
        for (uint i; i < signableTransactions[TX].signatures.length; ++i) {
            if (signableTransactions[TX].signatures[i] == editorID) {
                return i;
            }
        }

        return type(uint).max;
    }

    function _signTX(uint TX, uint editorID) private {
        signableTransactions[TX].signatures.push(editorID);
    }

    function _unsignTX(uint TX, uint signatureIndex) private {
        signableTransactions[TX].signatures[signatureIndex] = signableTransactions[TX].signatures[signableTransactions[TX].signatures.length - 1];
        signableTransactions[TX].signatures.pop();
    }

    function _routeSignature(uint TX, uint editorID) private {
        uint signatureIndex = _getSignatureIndex(TX, editorID);
        bool hasSigned = signatureIndex != type(uint).max;

        if (!hasSigned) {
            _signTX(TX, editorID);
        }
        else {
            _unsignTX(TX, signatureIndex);
        }

        signableTransactions[TX].lastTimeSigned = block.timestamp;
    }

    function _checkSignatures(uint TX) private returns (bool) {
        // has the required number of signatures
        if (signableTransactions[TX].signatures.length >= numEditors / 2 + 1) {
            _deleteTX(TX);
            return true;
        }

        // has no signatures
        if (signableTransactions[TX].signatures.length == 0) {
            _deleteTX(TX);
        }

        // does not have the required number of signatures
        return false;
    }

    // order doesn't really matter - can be sorted on frontend
    function _deleteTX(uint TX) private {
        signableTransactions[TX] = signableTransactions[signableTransactions.length - 1];
        signableTransactions.pop();
    }

    function _createTX(
        bytes memory functionName,
        bytes memory inputs,
        uint[] memory uintArr,
        address[] memory addressArr
    ) private returns (uint) {
        require(
            signableTransactions.length < maxPendingTX,
            "TEAM | TRANSACTION CREATION: Cannot create more than 10 signable transactions."
        );

        BotControllerLib_structs.SignableTransaction memory newTX;
        newTX.functionName = bytes32(functionName);
        newTX.inputs = bytes32(inputs);
        newTX.uintInput = uintArr;
        newTX.addressInput = addressArr;
        newTX.lastTimeSigned = block.timestamp;

        signableTransactions.push(newTX);
        return signableTransactions.length - 1;
    }

    function _getTX(
        bytes memory functionName,
        bytes memory inputs,
        uint[] memory uintArr,
        address[] memory addressArr
    ) private returns (uint) {
        for (uint i; i < signableTransactions.length; ++i) {
            bool found = signableTransactions[i].functionName == bytes32(functionName) && signableTransactions[i].inputs == bytes32(inputs);

            if (found) {
                return i;
            }
        }

        return _createTX(functionName, inputs, uintArr, addressArr);
    }

    function _checkTXTimestamps() private {
        for (uint i; i < signableTransactions.length; ++i) {
            if (block.timestamp - signableTransactions[i].lastTimeSigned > secPerWeek) {
                signableTransactions[i] = signableTransactions[signableTransactions.length - 1];
                signableTransactions.pop();
                --i;
            }
        }
    }

    function doMultisig(
        address sender,
        string memory functionName,
        uint[] memory uintArr,
        address[] memory addressArr
    ) external _selfAuth returns (bool) {
        // Can only be run by BotControllerLib's.
        return _doMultisig(sender, functionName, uintArr, addressArr);
    }

    function _doMultisig(
        address sender,
        string memory functionName,
        uint[] memory uintArr,
        address[] memory addressArr
    ) private returns (bool) {
        _checkTXTimestamps();

        uint editorID = editorIDs[sender];

        if (isEditor[editorID]) {
            uint TX = _getTX(bytes(functionName), Caffeinated.toBytes(uintArr, addressArr), uintArr, addressArr);
            _routeSignature(TX, editorID);
            return _checkSignatures(TX);
        }

        return true;
    }

    function _createDynamicArrs(uint uintLen, uint addressLen) private pure returns (uint[] memory, address[] memory) {
        return BotControllerLib_util._createDynamicArrs(uintLen, addressLen);
    }




    // ### SETTER FUNCTIONS ###
    function setBotFactory(address newBotFactory) external _editorAuth {
        (, address[] memory addressArr) = _createDynamicArrs(0, 1);
        addressArr[0] = newBotFactory;

        if (!_doMultisig(msg.sender, "setBotFactory", new uint[](0), addressArr)) {
            return;
        }

        botFactory = newBotFactory;
    }

    function setBotPoolIsFrozen(address _botPool, bool newContractIsFrozen) external _editorAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 1);
        addressArr[0] = _botPool;
        uintArr[0] = newContractIsFrozen ? 1 : 0;

        if (!_doMultisig(msg.sender, "setBotPoolIsFrozen", uintArr, addressArr)) {
            return;
        }
        
        IBotPool BotPool = IBotPool(_botPool);
        BotPool.setContractIsFrozen(newContractIsFrozen);
    }

    function setTreasuryWallet(address newTreasuryWallet) external _adminAuth {
        // Default to the TC `treasuryWallet`.
        if (newTreasuryWallet == address(this) || newTreasuryWallet == address(0)) {
            newTreasuryWallet = tc.treasuryWallet();
        }

        treasuryWallet = newTreasuryWallet;
    }

    function setFrontend(address newFrontend) external _editorAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(0, 1);
        addressArr[0] = newFrontend;

        if (!_doMultisig(msg.sender, "setFrontend", uintArr, addressArr)) {
            return;
        }

        frontend = newFrontend;
    }

    function setNftAdmin(address newNftAdmin) external _editorAuth {
        require(
            BotControllerLib_util.checkSetNftAdmin(newNftAdmin),
            "TEAM | SET NFT ADMIN: Identifical NFTs not found."
        );

        nftAdmin = INFTAdmin(newNftAdmin);
    }

    function setMinReqNftLevel(uint newMinReqNFTLevel) external _editorAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 0);
        uintArr[0] = newMinReqNFTLevel;

        if (!_doMultisig(msg.sender, "setMinReqNftLevel", uintArr, addressArr)) {
            return;
        }

        minReqNFTLevel = newMinReqNFTLevel;
    }

    function setFeeReductions(uint[] memory newFeeReductions) external _adminAuth {
        for (uint i; i < newFeeReductions.length; ++i) {
            require(
                newFeeReductions[i] <= oneHundredPct,
                "TEAM | UPKEEP: Cannot set an NFT level's upkeep reductions >100.0%."
            );
        }

        feeReductions = newFeeReductions;
    }

    function setApr(uint newApr) external _adminAuth {
        apr = newApr;
        aprBotBonus = 2 * newApr;
    }

    function setMinReqBalCash(uint newMinReqCashBal) external _editorAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 0);
        uintArr[0] = newMinReqCashBal;

        if (!_doMultisig(msg.sender, "setMinReqBalCash", uintArr, addressArr)) {
            return;
        }

        minReqBalCash = newMinReqCashBal;
    }

    function setOperatingDepositRatio(uint newOperatingDepositRatio) external _adminAuth {
        // Requires running the function twice if we're going below 1:1
        if (newOperatingDepositRatio < oneHundredPct && operatingDepositRatio > oneHundredPct) {
            newOperatingDepositRatio = oneHundredPct;
        }

        operatingDepositRatio = newOperatingDepositRatio;
    }

    function setTCUpkeep(uint newTCUpkeep) external _editorAuth {
        if (!BotControllerLib_util.checkSetTCUpkeep(newTCUpkeep)) {
            return;
        }

        tcUpkeep = newTCUpkeep;
        lastTimeUpkeepModified = block.timestamp;
    }

    function setMinFutureWeeksTCDeposit(uint8 newMinFutureWeeksTCDeposit) external _editorAuth {
        if (!BotControllerLib_util.checkSetMinFutureWeeksTCDeposit(newMinFutureWeeksTCDeposit)) {
            return;
        }

        minFutureWeeksTCDeposit = newMinFutureWeeksTCDeposit;
    }

    function setProfitFee(uint newProfitFee) external _adminAuth {
        if (!BotControllerLib_util.checkSetProfitFee(newProfitFee)) {
            return;
        }

        profitFee = newProfitFee;
        lastTimeProfitFeeModified = block.timestamp;
    }

    function setPenaltyFee(uint newPenaltyFee) external _adminAuth {
        require(newPenaltyFee <= oneHundredPct, "TEAM | PENALTY: Cannot increase penalty fee above 100%.");

        profitFee = newPenaltyFee;
    }

    function setWeeklyFeeWallet(address newWeeklyFeeWallet, address botPool) external _editorAuth {
        // botPool parameter is optional; if set to address(0) or address(this) will adjust THIS global
        // WeeklyFeeWallet
        if (BotControllerLib_util.checkSetWeeklyFeeWallet(newWeeklyFeeWallet, botPool)) {
            weeklyFeeWallet = newWeeklyFeeWallet;
        }
    }

    function setBotPoolMaxCash(uint newBotPoolMaxCash) external _editorAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 0);
        uintArr[0] = newBotPoolMaxCash;

        if (!_doMultisig(msg.sender, "setBotPoolMaxCash", uintArr, addressArr)) {
            return;
        }

        botPoolMaxCash = newBotPoolMaxCash;
    }

    function setPerUserMaxCash(uint newPerUserMaxCash) external _editorAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 0);
        uintArr[0] = newPerUserMaxCash;

        if (!_doMultisig(msg.sender, "setPerUserMaxCash", uintArr, addressArr)) {
            return;
        }

        perUserMaxCash = newPerUserMaxCash;
    }

    // NEW for Alpha v2
    function setPercentages(uint[] memory newPcts) external _editorAuth {
        BotControllerLib_util.checkSetPercentages(newPcts);

        if (!_doMultisig(msg.sender, "setPercentages", newPcts, new address[](0))) {
            return;
        }

        slippagePct = newPcts[0];
        reservePct = newPcts[1];
        borrowPct = newPcts[2];
        dexFeePct = newPcts[3];
        overswapPct = newPcts[4];
        minBalQualifyPct = newPcts[5];
        shortSlippagePct = newPcts[6];
        shortEmergencySlippagePct = newPcts[7];
    }

    // function emergencyWithdrawAllLoop(address BotTrader, bool chargeProfitFee) external _editorAuth {
    //     BotControllerLib_util.emergencyWithdrawAllLoop(BotTrader, chargeProfitFee);
    // }

    // NEW for Alpha v2
    function setOverswapMaxCash(uint newOverswapMaxCash) external _editorAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, 0);
        uintArr[0] = newOverswapMaxCash;

        if (!_doMultisig(msg.sender, "setOverswapMaxCash", uintArr, addressArr)) {
            return;
        }

        overswapMaxCash = newOverswapMaxCash;
    }

    // NEW for Alpha v2
    // Deletes all permitted users in the list, then deletes the entire list.
    // The `delete` keyword in Solidity shouldn't cost any gas as it gives a refund for resetting a variable.
    // may never need to do multiple loops
    function erasePermittedUsersList() external _loopAuth {
        if (!_doMultisig(msg.sender, "erasePermittedUsersList", new uint[](0), new address[](0))) {
            return;
        }

        for (uint i = nextPermittedUserToDelete; i < permittedUsersList.length; ++i) {
            delete permittedUser[permittedUsersList[i]];
            delete inPermittedUsersList[permittedUsersList[i]];

            if (gasleft() < minGas) {
                nextPermittedUserToDelete = i;
                return;
            }
        }

        delete permittedUsersList;
        delete nextPermittedUserToDelete;
        delete loopWallet;
    }

    // NEW for Alpha v2
    function setPermittedUsersList(address[] memory accounts, uint[] memory isPermitted) external _editorAuth {
        if (!BotControllerLib_util.checkSetPermittedUsersList(accounts, isPermitted)) {
            return;
        }

        for (uint i; i < accounts.length; ++i) {
            if (isPermitted[i] > 0) {
                if (permittedUser[accounts[i]]) {
                    continue;
                    // Don't bother wasting gas setting anything in this case.
                }

                permittedUser[accounts[i]] = true;

                if (!inPermittedUsersList[accounts[i]]) {
                    permittedUsersList.push(accounts[i]);
                    inPermittedUsersList[accounts[i]] = true;
                }
            }
            else {
                delete permittedUser[accounts[i]];
            }
        }
    }

    // NEW for Alpha v2
    // Deletes all permitted users in the list, then deletes the entire list.
    // The `delete` keyword in Solidity shouldn't cost any gas as it gives a refund for resetting a variable.
    // may never need to do multiple loops
    function eraseSanctionedUsersList() external _loopAuth {
        if (!_doMultisig(msg.sender, "eraseSanctionedUsersList", new uint[](0), new address[](0))) {
            return;
        }

        for (uint i = nextSanctionedUserToDelete; i < sanctionedUsersList.length; ++i) {
            delete sanctionedUser[sanctionedUsersList[i]];
            delete inSanctionedUsersList[sanctionedUsersList[i]];

            if (gasleft() < minGas) {
                nextSanctionedUserToDelete = i;
                return;
            }
        }

        delete sanctionedUsersList;
        delete nextSanctionedUserToDelete;
        delete loopWallet;
    }

    // NEW for Alpha v2
    function setSanctionedUsersList(address[] memory accounts, uint[] memory isSanctioned) external _editorAuth {
        if (!BotControllerLib_util.checkSetSanctionedUsersList(accounts, isSanctioned)) {
            return;
        }

        for (uint i; i < accounts.length; ++i) {
            if (isSanctioned[i] > 0 && !sanctionedUser[accounts[i]]) {
                sanctionedUser[accounts[i]] = true;

                if (!inSanctionedUsersList[accounts[i]]) {
                    sanctionedUsersList.push(accounts[i]);
                    inSanctionedUsersList[accounts[i]] = true;
                }
            }
            else {
                delete sanctionedUser[accounts[i]];
            }
        }
    }

    // NEW for Alpha v2
    function setLoopWallet(address newLoopWallet) external _adminAuth {
        loopWallet = newLoopWallet;
    }

    // NEW for Alpha v2
    function loop_setBotPoolIsFrozen(bool frozenStatus, address[] memory botPools) external _loopAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, botPools.length);
        uintArr[0] = frozenStatus ? 1 : 0; // 0 = false, 1 = true
        addressArr = botPools;

        if (!_doMultisig(msg.sender, "loop_setBotPoolIsFrozen", uintArr, addressArr)) {
            return;
        }

        // 800 is the cost to set a non-changing variable. Add +20% to safely pad any extra costs.
        uint gasRequired = (1000 * botPools.length) + minGas;
        
        // Before we even start the loop, make sure sufficient gas exists to complete
        // one full BotPool and its children.
        require(
            gasleft() > gasRequired,
            string.concat(
                "TEAM | GAS: Insufficient remaining. Must start with at least ",
                Caffeinated.uintToString(gasRequired),
                " gas. (1)"
            )
        );

        for (uint i; i < botPools.length; ++i) {
            if (gasleft() < minGas) {
                return;
            }
            IBotPool(botPools[i]).setContractIsFrozen(frozenStatus);
        }

        delete loopWallet;
    }

    // NEW for Alpha v2
    // How to use:
    //    - Set `loopWallet`
    //    - `loopWallet` runs this function over and over until completed, trimming the list of BotPools after each Tx
    //    -- OR --
    //    - Multi-Sig `adminWallet` can run over and over again manually
    function loop_setTradingWallet(address newTradingWallet, address[] memory botTraders) external _loopAuth {
        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, botTraders.length);
        uintArr[0] = uint(uint160(newTradingWallet)); // 0 = false, 1 = true
        addressArr = botTraders;

        if (!_doMultisig(msg.sender, "loop_setTradingWallet", uintArr, addressArr)) {
            return;
        }

        // 800 is the cost to set a non-changing variable. Add +20% to safely pad any extra costs.
        // uint originalGas = gasleft();
        uint gasRequired = (1000 * botTraders.length) + minGas;
        
        // Before we even start the loop, make sure sufficient gas exists to complete
        // one full BotPool and its children.
        require(
            gasleft() > gasRequired,
            string.concat(
                "TEAM | GAS: Insufficient remaining. Must start with at least ",
                Caffeinated.uintToString(gasRequired),
                " gas. (2)"
            )
        );

        for (uint i; i < botTraders.length; ++i) {
            if (gasleft() < minGas) {
                return;
            }
            IBotTrader(botTraders[i]).setTradingWallet(newTradingWallet);
        }

        delete loopWallet;
    }

    // NEW for Alpha v2
    // How to use:
    //    - Set `loopWallet`
    //    - `loopWallet` runs this function over and over until completed, trimming the list of BotPools after each Tx
    //    -- OR --
    //    - Multi-Sig `adminWallet` can run over and over again manually
    // Note: All users in a given BotPool must be looped over within 42 hours.
    //       Otherwise the rewards state resets, with users able to generate and collect rewards as usual.
    function loop_setTCCRewardsFrozen(bool usersShouldEarnRewards, address[] memory botPools) external _loopAuth {
        (uint8 status, , ) = BotControllerLib_util.runSetTCCRewardsFrozen(usersShouldEarnRewards, botPools);
        if (status == 2) {
           delete loopWallet;
        }
    }

    // NEW for Alpha v2
    // How to use:
    //    - Set `loopWallet`
    //    - `loopWallet` runs this function over and over until completed, trimming the list of BotPools after each Tx
    //    -- OR --
    //    - Multi-Sig `adminWallet` can run over and over again manually
    function loop_setNewBotController(address newBotController, address[] memory botPools) external _loopAuth {
        require(address(this) != newBotController, "TEAM | NEW: Given new BotController is the same as this one.");

        (uint[] memory uintArr, address[] memory addressArr) = _createDynamicArrs(1, botPools.length);
        uintArr[0] = uint(uint160(newBotController)); // 0 = false, 1 = true
        addressArr = botPools;

        if (!_doMultisig(msg.sender, "loopSetBotPoolIsFrozen", uintArr, addressArr)) {
            return;
        }

        // List of REQUIRED functions
        // require(
        //     // BotController.perUserMaxCash() == 
        //     // BotController.BotPoolMaxCash(),
        //     // BotController.minReqBalCash()
        //     // BotController.minReqBalTC()
        //     // BotController.operatingDepositRatio()
        //     // BotController.BotFactory()
        //     BotController.secPerWeek() == _newBotController.secPerWeek() &&
        //     _newBotController.frontend() != address(0) &&
        //     BotController.reqtcUpkeepPaymentOf(address(0)) == newBotController.reqtcUpkeepPaymentOf(address(0)) &&
        //     (
        //         BotController.treasuryWallet() == _newBotController.treasuryWallet() ||
        //         TC().treasuryWallet() == _newBotController.treasuryWallet()
        //     ) &&
        //     BotController.pctProfitFeeOf(address(0)) == _newBotController.pctProfitFeeOf(address(0)) &&
        //     BotController.pctPenaltyFeeOf(address(0)) == _newBotController.pctPenaltyFeeOf(address(0)) &&
        //     BotController.TCCRewardCalc(address(0)) == _newBotController.TCCRewardCalc(address(0)) &&
        //     BotController.TCFeeOf(address(0)) == _newBotController.TCFeeOf(address(0)) &&
        //     address(BotController.cash()) == address(_newBotController.cash()) &&
        //     address(BotController.TC()) == address(_newBotController.TC()) &&
        //     address(BotController.TCC()) == address(_newBotController.TCC()) &&
        //     BotController.adminWallet() == _newBotController.adminWallet() &&
        //     BotController.maxSingleLoopSize() == _newBotController.maxSingleLoopSize(),
        //     "POOL | ..."
        // );

        // IBotController _newBotController = IBotController(newBotController);

        // 800 is the cost to set a non-changing variable. Multiply by 5 to safely pad any extra costs.
        uint oneLoopGasUsed = (4000 * botPools.length) + minGas;
        
        // Before we even start the loop, make sure sufficient gas exists to complete
        // one full BotPool and its children.
        require(
            gasleft() > oneLoopGasUsed,
            string.concat(
                "TEAM | GAS: Insufficient remaining. Must start with at least ",
                Caffeinated.uintToString(oneLoopGasUsed),
                " gas. (4)"
            )
        );

        oneLoopGasUsed = 0;

        for (uint i; i < botPools.length; ++i) {
            uint gasTally = gasleft();
            if (gasTally < oneLoopGasUsed) {
                setNewBotController_nextBotPool = botPools[i];

                // Returns the address of the not-yet-set BotPool
                // or `address(0)` if completed successfully.
                // And the gas estimated required to complete.
                return; // (setNewBotController_nextBotPool, oneLoopGasUsed * (botPools.length + 1 - i));
            }

            IBotPool BotPool = IBotPool(botPools[i]);

            if (address(BotPool.botController()) == address(this)) {

                // This itself contains an interior loop that
                // goes through all BotTraders.
                BotPool.setBotController(newBotController);
            }

            // Ensure there's sufficient gas to perform
            // the `setBotController()` on the next BotPool
            // and all its BotTrader children.
            gasTally -= gasleft();
            if (gasTally > oneLoopGasUsed) {
                oneLoopGasUsed = gasTally + minGas;
            }
        }

        // Check this variable `setNewBotController_nextBotPool` to ensure the loop completed.
        delete setNewBotController_nextBotPool;
        delete loopWallet;
    }




    // ### MISC FUNCTIONS ###
    function loop_evictAllUsers(address botPool) external _loopAuth {
        (, address[] memory addressArr) = _createDynamicArrs(0, 1);
        addressArr[0] = botPool;

        if (!_doMultisig(msg.sender, "loop_evictAllUsers", new uint[](0), addressArr)) {
            return;
        }

        uint nextUserToEvict = IBotPool(botPool).evictAllUsers();

        if (nextUserToEvict == 1) {
            delete loopWallet;
        }
    }

    // NEW for Alpha v2
	function weeklyFee(address botPool) external _editorAuth {
        IBotPool(botPool).weeklyFee(); // BotControllerLib_util.weeklyFee(botPool);
    }

	// NEW for Alpha v2
    function ejectBadUser(address botPool, address account) external _editorAuth {
        BotControllerLib_util.ejectBadUser(botPool, account);
    }

    // 0.1 Kb
    function ejectBadUserID(address botPool, uint userID) external _editorAuth {
        BotControllerLib_util.ejectBadUserID(botPool, userID);
    }

    // NEW for Alpha v2
    function freezeMigrateVestedTC(address botPool, bool vestingStatus) external _loopAuth {
        if (BotControllerLib_util.freezeMigrateVestedTC(botPool, vestingStatus)) {
            delete loopWallet;
        }
    }

    // Allows anyone to send tokens to the `treasuryWallet` that were accidentally received at this address.
    function claimERC20(address token) external _editorAuth {
        IERC20 _token = IERC20(token);
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }

}
