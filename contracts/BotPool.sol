// SPDX-License-Identifier: CC-BY-NC-SA-4.0

pragma solidity ^0.8.19;

import "./libraries/API_SWAP.sol";
import "./libraries/Caffeinated.sol";

import "./libraries/BotPoolLib_deposit.sol";
import "./libraries/BotPoolLib_util.sol";
import "./libraries/BotPoolLib_vestedTC.sol";
import "./libraries/BotPoolLib_withdraw.sol";

import "./interfaces/IBotController.sol";
import "./interfaces/IBotTrader.sol";
// import "./interfaces/INFTAdmin.sol";

// import "hardhat/console.sol";

contract BotPool {

    string public version = "2023-03-28 | Alpha v3";

    event WeeklyFeeDone(uint amount);
    event EvictedAll();
    event BadUsersEjected();
    event VestingEnding(uint when);
    event PresaleEnded(uint when);

    // TODO: Edit `botController` to `BotController`
    IBotController public botController;
    address public pendingNewBotController;
    uint public botTraderSetBotController;

    // TODO: Edit `botFactory` to `BotFactory`
    uint public immutable oneHundredPct;
    address public immutable originalFrontend;
    address public immutable botFactory;
    address public presale;
    address public weeklyFeeWallet;
    function frontend() public view returns (address) {
        return botController.frontend();
    }

    function adminWallet() public view returns (address) {
        return botController.adminWallet();
    }

    IERC20 public immutable cash;
    IERC20 public immutable asset;
    IERC20T public immutable tc;
    IERC20T public immutable tcc;

    function cashSymbol() public view returns (string memory) {
        return cash.symbol();
    }

    function cashDecimals() public view returns (uint) {
        return 10 ** cash.decimals();
    }

    function assetSymbol() public view returns (string memory) {
        return asset.symbol();
    }

    function assetDecimals() public view returns (uint) {
        return 10 ** asset.decimals();
    }

    // Only settable at Deployment | `immutable` not supported for type `string`
    string public tcSymbol;
    string public tccSymbol;
    uint public immutable tcDecimals;
    uint public immutable tccDecimals;

    string public mode;
    string public timeframe;
    string public strategyName;
    string public description;

    uint public tcToAdd;
    uint public botPoolCashBalance;
    
    uint private nextUserToEvict = 1;
    bool public vestingFrozen;
    uint public immutable minGas;

    IBotTrader[] public botTraders;
    mapping(address => bool) public isTradingWallet;
    mapping(address => bool) public isBotTraderContract;
    address public availableBotTrader;

    uint public constant botTraderMaxUsers = type(uint).max; // @Alpha-v2>> 5000;
    // Easier to loop over users with `tradeExit_XX()` functions
    // in each BotTrader than it is to loop over BotTraders
    // and move each into and out of a trade.
    function maxBotTraders() public pure returns (uint) {
        return 1; // @Alpha-v2>> botController.maxSingleLoopSize();
    }

    function numBotTraders() external view returns (uint) {
        return botTraders.length;
    }

    uint public numUsers;
    function botPoolMaxUsers() public pure returns (uint) {
        return maxBotTraders() * botTraderMaxUsers;
    }
    mapping(address => uint) public userIDs;
    mapping(uint => address) public userAddress;
    mapping(uint => bool) public isRegistered;
    mapping(uint => IBotTrader) public inBotTrader;
    mapping(uint => uint) public balanceTC;
    mapping(uint => uint) public balanceTCC;
    mapping(uint => uint) public secsInBot;  // Should we have some mechanism to reset these values after an Annual TC Rewards Party ??
    mapping(uint => uint) public inBotSince;
    mapping(uint => uint) public nextTimeUpkeep;
    mapping(uint => uint) public lastTimeRewarded;
    mapping(uint => uint) public cumulativeTCUpkeep;
    mapping(uint => uint) public operatingDepositTC;

    uint8 public constant t = 5; // number of time option slots
    mapping(uint => uint[t]) public vested;

    // https://blog.logrocket.com/ultimate-guide-data-types-solidity/#bytes
    // https://www.linkedin.com/pulse/optimizing-smart-contract-gas-cost-harold-achiando/
    // https://docs.soliditylang.org/en/develop/types.html#members
    // https://www.unixtimestamp.com/
    // for vested[0]: 0 = start time        | 1 = 1 year end time | 2 = 2 years end time | 3 = 3 years end time | 4 = 4 years end time
    // for vested[x]: 0 = last time claimed | 1 = 1 year          | 2 = 2 years          | 3 = 3 years          | 4 = 4 years
    uint public totalVestedTC;

    mapping(uint => uint) public pendingWithdrawalTC;
    mapping(uint => bool) public isBadUser; // Yes, someone could loop through this entire mapping to rebuild the entire `badUserIDs` list but... c'mon.

    function checkVestingHash(bytes32 testSubject) external view returns (bool) {
        bytes32[] memory testSubjects = new bytes32[](1);
        testSubjects[0] = testSubject;
        (bool success, ) = BotPoolLib_vestedTC.checkVestingHash(testSubjects, vestingHashBalance); // testSubject == vestingHash();
        return success;
    }

    bytes32 public vestingHashMigrated; // MUST remain public
    bytes32 private vestingHashBalance; // MUST remain private
    uint public vestingHashLength;      // MUST remain public

    uint public totalBalanceTC;
    uint public nextTimeUpkeepGlobal;

    uint public tccNextUserToReward = 1;
    int public tccInEscrow;
    uint public tccTimeFrozen;
    uint public immutable tccTimeToMelt; // 42 hours
    uint public tccTimeEnabled;
    bool public contractIsFrozen; // `true` disables deposits and prevents botTraders from entering new trades

    // ------ Team only ------
    uint private nextUserToUpkeep = 1;
    uint[] private badUserIDs;
    uint private currentIndexOfBadUserIDs;
    // -----------------------

    address[] public aTokensArr;

    // `_contracts` must consist of:
    //  -> [0] ERC-20 asset
    //  -> [1] BotController
    //  -> [2] Presale

    // `_aTokens` may consist of any aTokens from AAVE. Such as:
    //  -> [3] AAVE's `cash` aToken
    //  -> [4] AAVE's `asset` aToken
    //  -> [5] AAVE's collateral aToken
    constructor(address[] memory _contracts, address[] memory _aTokens, string[4] memory _info) {
        botController = IBotController(_contracts[0]);
        // version = botController.version();

        cash = botController.cash();
        asset = IERC20(_contracts[1]);
        tc = botController.tc();
        tcc = botController.tcc();

        presale = _contracts[2];

        tcSymbol = tc.symbol();
        tccSymbol = tcc.symbol();
        tcDecimals = tc.denominator(); // 10 ** tc.decimals();
        tccDecimals = tcc.denominator(); // 10 ** tcc.decimals();
    
        oneHundredPct = botController.oneHundredPct();
        originalFrontend = botController.frontend();
        botFactory = botController.botFactory();
        nextTimeUpkeepGlobal = block.timestamp + botController.secPerWeek();
        
        minGas = botController.minGas();
        tccTimeToMelt = botController.secPerWeek() / 4; // 42 hours

        cash.approve(address(API_SWAP.aavePool), type(uint).max);

        _setInfo(_info);

        for (uint i; i < _aTokens.length; ++i) {
            aTokensArr.push(_aTokens[i]);
        }
    }

    // Each BotPool must be set as a Permitted User to enable global Deposits.
    // Otherwise, each user must be set individually as a Permitted User to enable individual Deposits.




    // ### AUTHORISATION FUNCTIONS ###
    function selfLevel(address sender) public view returns (bool) {
        return sender == address(this);
    }

    modifier _selfAuth() {
        // Allows the BotPoolLib to call `public` functions here.
        require(
            selfLevel(msg.sender),
            "POOL | AUTH: No external execution permitted."
        );
        _;
    }

    modifier _botTraderAuth() {
        require(
            isBotTraderContract[msg.sender],
            "POOL | AUTH: Only a BotTrader."
        );
        _;
    }

    modifier _selfAuth_botTraderAuth() {
        require(
            isBotTraderContract[msg.sender] || selfLevel(msg.sender),
            "POOL | AUTH: Only this BotPool or a BotTrader."
        );
        _;
    }

    function adminLevel(address sender) public view returns (bool) {
        return sender == adminWallet() || sender == address(botController);
    }

    modifier _adminAuth() {
        require(
            adminLevel(msg.sender),
            "POOL | AUTH: Only the Admin Wallet or BotController."
        );
        _;
    }

    function editorLevel(address sender) public view returns (bool) {
        return botController.getIsEditor(sender) || adminLevel(sender);
    }

    modifier _editorAuth() {
        require(
            editorLevel(msg.sender),
            "POOL | AUTH: Only an Editor, the Admin Wallet, or BotController."
        );
        _;
    }

    function weeklyFeeLevel(address sender) public view returns (bool) {
        return sender == weeklyFeeWallet || sender == botController.weeklyFeeWallet() || editorLevel(sender);
    }

    modifier _weeklyFeeAuth() {
        require(
            weeklyFeeLevel(msg.sender),
            "POOL | AUTH: Only a Weekly Fee Wallet, an Editor, the Admin Wallet, or BotController."
        );
        _;
    }

    // TODO: Include in Beta.
    // modifier _nftAdminAuth() {
    //     require(
    //         msg.sender == address(botController.nftAdmin()),
    //         "POOL | AUTH: Only NFT Admin."
    //     );
    //     _;
    // }

    // Only allow BotTraders or Frontend-authenticated sources
    // to obtain sensitive system data.
    function sysGetLevel(address sender) public view returns (bool) {
        return isBotTraderContract[sender] || weeklyFeeLevel(sender) || isTradingWallet[sender] || msg.sender == address(this);
    }

    modifier _sysGetLevel() {
        require(
            sysGetLevel(msg.sender) || msg.sender == frontend(),
            "POOL | AUTH: Only admin team."
        );
        _;
    }

    function presaleLevel(address sender) public view returns (bool) {
        return sender == presale && presale != address(0);
    }

    modifier _presaleAuth() {
        require(
            presaleLevel(msg.sender),
            "POOL | AUTH: Only Presale."
        );
        _;
    }




    // ### GETTER FUNCTIONS ###
    function getBotTraders() external view returns (address[] memory) {
        return BotPoolLib_util.getBotTraders();
    }

    function getSender(address account) public view returns (address) {
        require(msg.sender != address(0), "POOL | SENDER: Cannot be the 0 wallet.");
        return 
            (msg.sender == frontend()
            || msg.sender == address(this)
            || msg.sender == originalFrontend) ? account : msg.sender;
    }

    // Costs more bytecode to put into BotPoolLib than to leave.
    function getTradingWallets() external view _sysGetLevel returns (address[] memory) {
        return BotPoolLib_util.getTradingWallets();
    }

    function getaTokens() external view returns (address[] memory) {
        return aTokensArr;
    }

    function getNextUserIDToUpkeep() external view _sysGetLevel returns (uint) {
        return nextUserToUpkeep;
    }

    function libNextBadUserID() external view _sysGetLevel returns (uint) {
        return badUserIDs[currentIndexOfBadUserIDs];
    }

    function getCurrentIndexOfBadUserIDs() external view _sysGetLevel returns (uint) {
        return currentIndexOfBadUserIDs;
    }

    function getBadUserIDs() external view _sysGetLevel returns (uint[] memory) {
        return badUserIDs;
    }

    function getBadUserAddresses() external view _sysGetLevel returns (address[] memory) {
        return BotPoolLib_util.getBadUserAddresses();
    }

    function getNextUserIDToEvict() external _sysGetLevel view returns (uint) {
        return nextUserToEvict;
    }

    function getTotal_balance_entryPrice_debt() external view returns (uint, uint, uint, uint) {
        return BotPoolLib_util.getTotal_balance_entryPrice_debt();
    }

    function getVestedValues(uint userID) external view returns (uint[t] memory) {
        return vested[userID];
    }

    function getVestedSum(uint userID) public view returns (uint sum) {
        // Only sum the amounts of TC unless the userID is 0
        // in which case we're summing all the global timers.
        uint8 i = userID != 0 ? 1 : 0;
        for (; i < t; ++i) {
            sum += vested[userID][i];
        }
        return sum;
    }

    function getTradeStatusOfID(uint userID) public view returns (int) {
        return inBotTrader[userID].tradeStatus();
    }

    function getTradeStatusOf(address account) external view returns (int) {
        return getTradeStatusOfID(userIDs[account]);
    }




    // ### EXPOSED EXTERNAL FUNCTIONS ###
    function nftTransferNotification(address account) external {
        require(msg.sender == address(botController.nftAdmin()), "BPNFT");
        uint _userID = userIDs[account]; 
        __generateTCC(account, _userID, inBotTrader[_userID].getBalanceOf(account) > 0);
    }

    function removeTradingWallet(address removeMe) external _botTraderAuth {
        delete isTradingWallet[removeMe];
    }

    function addTradingWallet(address addMe) external _botTraderAuth {
        isTradingWallet[addMe] = true;
    }

    function rememberSecsInBot(address account) external _botTraderAuth {
        uint userID = userIDs[account];
        secsInBot[userID] += (block.timestamp - inBotSince[userID]);
        delete inBotSince[userID];
    }

    // TODO: Include in Beta.
    // function _nftAdminGenerateTCC(address account) external _nftAdminAuth {
    //     uint userID = userIDs[account];
    //     __generateTCC(account, userID, inBotTrader[userID].hasBalance(account));
    // }

    function setPresaleEnded() external _presaleAuth {
        BotPoolLib_vestedTC.presaleEnded();
        emit PresaleEnded(vested[0][0]);
    }

    // < 0.1 Kb (with full function 0.5 Kb)
    function reApprove() external {
        BotPoolLib_util.reApprove();
    }

    // Allows the Editors to send any extra TC to the BotController's `treasuryWallet`.
    // Cash must never be touched as any excess here in BotPool is automatically
    // sent to the `treasuryWallet` upon trade entry.
    function returnTC_TCC() external _editorAuth {
        BotPoolLib_util.returnTC_TCC();
    }

    // 0.5 Kb
    // Allows anyone to send tokens to the `treasuryWallet` that were accidentally received at this address.
    function claimERC20(address _token) external _editorAuth {
        BotPoolLib_util.claimERC20(_token);
    }
    
}