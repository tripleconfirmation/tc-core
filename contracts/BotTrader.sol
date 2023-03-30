// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "./libraries/API_SWAP.sol";
import "./libraries/Caffeinated.sol";

import "./libraries/BotTraderLib_trade.sol";
import "./libraries/BotTraderLib_util.sol";
import "./libraries/BotTraderLib_withdraw.sol";
import "./libraries/BotTraderLib_withdrawExt.sol";

import "./interfaces/IBotController.sol";
import "./interfaces/IBotPool.sol";

// import "hardhat/console.sol";

contract BotTrader {

    string public version;

    event LongEntry(uint amountCash);
    event LongExit(uint amountCash);
    event AssetBorrowed(uint amount);
    event ShortEntry(uint amountCash);
    event ShortExit(uint amountCash);
    event DebtRepaid(uint amount);
    event BalancesUpdated(uint lastCashBalance);
    event PendingRequestsComplete(uint users);

    // TODO: Edit `botPool` to `BotPool`
    // TODO: Edit `botController` to `BotController`
    IBotController public botController;
    IBotPool public botPool;
    
    uint public immutable oneHundredPct; // TODO: Remove for Beta. Only used in BotTraderLib_withdraw
    uint public immutable minGas;

    IERC20 public immutable cash;
    IERC20 public immutable asset;
    // IERC20[2] public assets; // TODO: In Beta, consider allowing 1 or 2 tokens to be assets
    // so long as those assets remain in-sync across the BotPool and all BotTraders.
    // Example: BTC.b or WBTC.e would both be authorised, with one chosen across all.
    // From BotController such a change would be possible with precision looping and verification.
    
    address public tradingWallet;

    uint8 public constant staticsLength = 27; // MUST == BotTraderLib_util.staticsLength;
    uint8 public constant valuesLength = 6; // MUST == BotTraderLib_withdraw.valuesLength
    uint public numUsers;
    uint public activeUsers;
    function maxUsers() public view returns (uint) {
        return botPool.botTraderMaxUsers();
    }

    mapping(address => uint) public userIDs;
    mapping(uint => address) public userAddress;
    mapping(uint => uint8) public withdrawAllType; // 0 = none, 1 = cashOnly, 2 = cash+tokens | TODO: Switch to bytes1
    mapping(uint => uint) public pendingWithdrawal;
    mapping(uint => uint) public pendingDeposit;
    mapping(uint => uint) public deposited;
    mapping(uint => uint) public balance;
    mapping(uint => uint) public balanceTradeStart;
    mapping(uint => int) public totalChange;
    mapping(uint => uint) public totalFeePaid;
    mapping(uint => bool) public isActiveUser;
    bytes1[] public balanceUpdated;

    // Not in trade: 0, long: 1, short: -1
    int public tradeStatus;
    bool public isRepayingLoan;
    uint public lastCashBalance;
    uint public entryPrice;
    uint public pendingUser = 1;
    bool public pendingExecAllowed;
    uint public balancesUser = 1;
    bool public balancesUpdated = true;
    uint[4] public tradeExitBalances;
    uint public emergencyShortPadding;

    // string public error_withdrawLongAsset;
    // string public error_withdrawLongAssetOverswap;
    // string public error_withdrawLongCashOverswap;
    // string public error_withdrawShortAssetOverswap;
    // string public error_withdrawShortCashOverswap;
    // string public error_withdrawShortAssetTooLittle;
    // string public error_withdrawShortAssetTooMuch;
    // string public error_withdrawShortCashTooLittle;
    string[8] public errorStrings;

    constructor(address _botPool) {
        botPool = IBotPool(_botPool);
        botController = IBotController(botPool.botController());

        version = botPool.version();

        oneHundredPct = botPool.oneHundredPct();
        minGas = botPool.minGas();

        cash = botPool.cash();
        asset = botPool.asset();

        _approve();
        // balanceUpdated.push(0x00); // empty first user

        // Removing all strings in the entire contract
        // saves 2.7 Kb.
        errorStrings = BotTraderLib_util.generateErrorStrings(asset, cash);
        // errorStrings[8] = "TRADER | LONG WITHDRAW: No swap took place."; // TODO: Fix in Beta
        
        // error_withdrawLongAsset =
        //     string.concat(
        //         "TRADER | LONG WITHDRAW: Insufficient ",
        //         asset.symbol(),
        //         " sold."
        //     );
        
        // error_withdrawLongAssetOverswap =
        //     string.concat(
        //         "TRADER | LONG WITHDRAW: ",
        //         asset.symbol(),
        //         " overswap was large. Please try again."
        //     );
        
        // error_withdrawLongCashOverswap =
        //     string.concat(
        //         "TRADER | LONG WITHDRAW: ",
        //         cash.symbol(),
        //         " overswap was large. Please try again."
        //     );

        // error_withdrawShortAssetOverswap =
        //     string.concat(
        //         "TRADER | SHORT WITHDRAW: ",
        //         asset.symbol(),
        //         " overswap was large. Please try again."
        //     );
        
        // error_withdrawShortCashOverswap =
        //     string.concat(
        //         "TRADER | SHORT WITHDRAW: ",
        //         cash.symbol(),
        //         " overswap was large. Please try again."
        //     );

        // error_withdrawShortAssetTooLittle =
        //     string.concat(
        //         "TRADER | SHORT WITHDRAW: Insufficient ",
        //         asset.symbol(),
        //         " bought."
        //     );

        // error_withdrawShortAssetTooMuch =
        //     string.concat(
        //         "TRADER | SHORT WITHDRAW: Too much ",
        //         asset.symbol(),
        //         " bought."
        //     );

        // error_withdrawShortCashTooLittle =
        //     string.concat(
        //         "TRADER | SHORT WITHDRAW: Insufficient ",
        //         cash.symbol(),
        //         " raised."
        //     );      
    }

    function _approve() private {
        cash.approve(API_SWAP.zeroXExchangeProxy, type(uint).max);
        cash.approve(address(API_SWAP.aavePool), type(uint).max);

        asset.approve(API_SWAP.zeroXExchangeProxy, type(uint).max);
        asset.approve(address(API_SWAP.aavePool), type(uint).max);
    }




    // ### AUTHORISATION FUNCTIONS ###
    modifier _selfAuth() {
        // Allows the BotPoolLib to call `public` functions here.
        require(
            msg.sender == address(this),
            "TRADER | AUTH: No external execution permitted."
        );
        _;
    }

    function botPoolLevel(address sender) public view returns (bool) {
        return sender == address(botPool);
    }

    modifier _botPoolAuth() {
        require(
            botPoolLevel(msg.sender),
            "TRADER | AUTH: Sender is not botPool."
        );
        _;
    }

    function adminLevel(address sender) public view returns (bool) {
        return botPool.adminLevel(sender);
    }

    function editorLevel(address sender) public view returns (bool) {
        return adminLevel(sender) || botPool.editorLevel(sender);
    }

    modifier _editorAuth() {
        require(
            editorLevel(msg.sender),
            "TRADER | AUTH: Sender is not an Editor, Admin Wallet, or botController."
        );
        _;
    }

    function tradingLevel(address sender) public view returns (bool) {
        return adminLevel(sender) || sender == tradingWallet || isRepayingLoan;
    }

    modifier _tradingAuth() {
        require(
            tradingLevel(msg.sender),
            "TRADER | AUTH: Sender is not Trading Wallet, Admin Wallet, or botController."
        );
        _;
    }

    modifier _botPoolAuthOrEditorAuth() {
        require(
            botPoolLevel(msg.sender) || editorLevel(msg.sender),
            "TRADER | AUTH: Sender is not botPool or an Editor."
        );
        _;
    }

    function botControllerLevel(address sender) public view returns (bool) {
        return adminLevel(sender) || sender == address(botController);
    }

    modifier _botControllerAuth() {
        require(
            botControllerLevel(msg.sender),
            "TRADER | AUTH: Sender is not Admin Wallet or botController."
        );
        _;
    }




    // ### GETTER FUNCTIONS ###
    // `public` only for `console.log` diagnostics; switch to `external` for release
    // 0.1 Kb
    function getBotTotalCashBalance() external view returns (uint) {
        (uint[staticsLength] memory outs, ) = BotTraderLib_util.getBotTotalCashBalance();
        return outs[16];
    }

    // < 0.1 Kb
    function getBalanceOfUserID(uint userID) external view returns (uint) {
        uint[staticsLength] memory outs = BotTraderLib_util.getUserBalance(userID);
        return outs[6];
    }

    function getBalanceOf(address account) external view returns (uint) {
        uint[staticsLength] memory outs = BotTraderLib_util.getUserBalance(userIDs[account]);
        return outs[6];
    }

    function getAssetBalance() external view returns (uint) {
        return asset.balanceOf(address(this));
    }

    // TODO: Change to `int` with negative for amount beyond debt.
    function getAssetDebt() external view returns (uint) {
        uint debt = API_SWAP.aaveDebt();
        uint assetBal = asset.balanceOf(address(this));
        if (debt < assetBal) {
            delete debt;
        }
        else if (assetBal > 0) {
            debt -= assetBal;
        }
        return debt;
    }

    function hasBalanceUserID(uint userID) public view returns (bool) {
        return balance[userID] > 0 || pendingDeposit[userID] > pendingWithdrawal[userID];
    }

    function hasBalance(address account) external view returns (bool) {
        return hasBalanceUserID(userIDs[account]);
    }

    function getAAVEUserData() external view returns (uint[6] memory) {
        return API_SWAP.aaveUserData();
    }

    function getAssetPrice() public view returns (uint) {
        return API_SWAP.getAssetPrice();
    }

    function entryPriceDecimals() public view returns (uint) {
        return 10 ** API_SWAP.getDecimals();
    }

    function getTradeStatusOf(address account) external view returns (int) {
        return account == account ? tradeStatus : type(int).max;
        // Using `account == account` won't return a compile error
        // and will ensure this function works the same as in botPool
        // thereby allowing the Frontend to submit the call to either
        // a botPool or a BotTrader and receive a proper response.
    }

    function getWithdrawEstimates(
        address account,
        uint BotTraderUserID,
        uint amountCash,
        bool withdrawNow_
    ) public view returns (uint[valuesLength] memory) {
        return BotTraderLib_withdrawExt.getWithdrawEstimates(account, BotTraderUserID, amountCash, withdrawNow_);
    }

    // Used in `_swapAndVerify()` as well as Both trade entry functions.
    // Used for all swap functions in nested libraries.
    function API_SWAP_pcts() external view returns (uint[3] memory pcts) {
        pcts[0] = botController.oneHundredPct();
        pcts[1] = botController.slippagePct();
        pcts[2] = botController.dexFeePct();
        return pcts;
    }




    // ### SETTER FUNCTIONS ###
    function setBotController(IBotController newBotController) external _botPoolAuth {
        botController = newBotController;
    }

    function setTradingWallet(address newTradingWallet) external _botControllerAuth {
        botPool.removeTradingWallet(tradingWallet);
        tradingWallet = newTradingWallet;
        botPool.addTradingWallet(tradingWallet);
    }

    function setBalanceTradeStart(uint userID) external _selfAuth {
        balanceTradeStart[userID] = balance[userID];
    }




    // ### TEAM FUNCTIONS ###
    function reApprove() external _botPoolAuthOrEditorAuth {
        _approve();
    }

    // Allows the team to withdraw tokens that are not `cash()` or `asset()`
    function claimERC20(address token) external _editorAuth {
        BotTraderLib_util.claimERC20(token);
    }

}