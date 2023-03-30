// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "../interfaces/IBotController.sol";
import "../interfaces/IBotPool.sol";
import "../interfaces/IBotTrader.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC20T.sol";

// import "hardhat/console.sol";

library FrontendLib_getInfo {

    struct BotTradersAdmins {
        address[] list;                 // list of all BotTraders in the this BotPool
        uint count;                     // how many BotTraders are under this BotPool?
        uint max;                       // maximum count of BotTraders permitted
        address available;              // address of the BotTrader with user slots still available
        address botFactory;             // address of the BotFactory which creates BotTraders
        address[] tradingWallet;        // address of the BotTrader's `tradingWallet`
        int[] tradeStatus;
        uint[] activeUsers;
        uint[] numUsers;
        bool[] isRepayingLoan;
        uint[] entryPrice;
        uint[] pendingUser;
        bool[] pendingExecAllowed;
        uint[] balancesUser;
        bool[] balancesUpdated;
        uint[] tradeExitCashBalance;
        uint[] balancesSum;
    }

    struct BotTraders {
        address[] list;                 // list of all BotTraders in the this BotPool
        uint count;                     // how many BotTraders are under this BotPool?
        uint max;                       // maximum count of BotTraders permitted
        uint maxUsersPerEach;           // users per each BotTrader permitted
        address available;              // address of the BotTrader with user slots still available
        address botFactory;             // address of the BotFactory which creates BotTraders
    }

    struct Asset {
        address adresse;                // address of this currency
        string symbol;                  // symbol of this currency
        uint8 decimals;                 // number of decimals this currency has
        uint denominator;               // divide by this number to get balance/value in decimal form
    }

    struct Cash {
        address adresse;                // address of this currency
        string symbol;                  // symbol of this currency
        uint8 decimals;                 // number of decimals this currency has
        uint denominator;               // divide by this number to get balance/value in decimal form
        uint balance;                   // total amount of `cash` for the BotPool; running internal total NOT cash.balanceOf(address(BotPool))
        uint botPoolMax;                // maximum total cash the BotPool will accept across all users
        uint perUserMax;                // maximum total cash the BotPool will accept per user
        uint overswapMax;               // = 1000 USDC
        uint minReqBalance;             // minimum required cash to be on-deposit
    }

    struct Upkeep {
        uint timeNext;
        uint timeLastModified;
        uint fee;                       // the amount of TC charged at next upkeep
        uint minWeeks;                  // number of weeks of {{ n Σ `fee` + 5% }} required
        uint reqFromZeroCash;           // required TC Upkeep payment to (pre-)pay for someone depositing cash into the Bot
    }

    struct TC {
        address adresse;                // address of this currency
        string symbol;                  // symbol of this currency
        uint8 decimals;                 // number of decimals this currency has
        uint denominator;               // divide by this number to get balance/value in decimal form
        uint balance;                   // total amount of TC for the BotPool; running internal total NOT tc.balanceOf(address(BotPool))
        address adminWallet;            // only used on TC/TCC: owner/admin wallet of this currency
        address treasuryWallet;         // only used on TC/TCC: treasury wallet of this currency
        uint circulatingSupply;         // only used on TC/TCC: circulating supply of this currency
        uint operatingDepositRatio;     //
        uint minReqBalance;             // if the user has cash in the Bot, they must maintain this TC balance at all times
    }

    struct Rewards {
        uint nextUser;                  // tccNextUserToReward()
        int inEscrow;                   // tccInEscrow()
        uint timeFrozen;                // tccTimeFrozen() when were rewards frozen? timestmap in UNIX seconds
        uint timeToMelt;                // tccTimeToMelt() how far from `timeFrozen` do rewards unfreeze unless the team gets `nextUser` to 0
        uint timeEnabled;               // `block.timestamp` when TCC rewards were enabled
    }

    struct TCC {
        address adresse;                // address of this currency
        string symbol;                  // symbol of this currency
        uint8 decimals;                 // number of decimals this currency has
        uint denominator;               // divide by this number to get balance/value in decimal form
        uint balance;                   // total amount of TCC for the BotPool; IS == tcc.balanceOf(address(BotPool))        
        address adminWallet;            // only used on TC/TCC: owner/admin wallet of this currency
        address treasuryWallet;         // only used on TC/TCC: treasury wallet of this currency
        uint circulatingSupply;         // only used on TC/TCC: circulating supply of this currency
        Rewards rewards;
    }

    struct Pct {
        uint oneHundred;                // BotPool's `oneHundredPct` - all percentages returned are intended to be divided by this
        uint profitFee;                 // profit fee as a percentage
        uint profitFeePenalty;          // additional profit fee levied on immediate withdrawal during a trade
        uint apr;                       // rate of TCC generation per year as a percentage
        uint aprBotBonus;               // additional rate of TCC generation per year as a percentage when also invested in BotTrader
        uint slippage;                  // maximum slippage our contracts are willing to accept as a percentage
        uint reserve;                   // cash kept in reserve when shorting as a percentage of total balance
        uint borrow;                    // cash borrowed as a percentage of collateral
        uint dexFee;                    // 0.3%
        uint overswap;                  // 3%
        uint minBalQualify;             // = 98%
        uint shortSlippage;             // 0.075% | lower percent favours First User | higher percent favours Last User
        uint[] feeReductions;           // array of percentage fee reductions applied when owning an NFT; in ascending order
    }

    struct Adresse {
        address frontend;               // address of the current Frontend
        address botController;          // BotController of this BotPool
        address adminWallet;            // address of the `adminWallet`
        address treasuryWallet;         // address of the treasury wallet which receives TC upkeep and profit fees
        address weeklyFeeWallet;        // address of the Python-run wallet that can initiate the weekly fee
        address nftAdmin;               // address of the NFTAdmin which controls NFTs
        address presale;                // address of the Presale smart contract admin
        address originalFrontend;       // original Frontend assigned to BotPool
        address[] originalContracts;    // contracts passed in at deployment time
    }

    struct Vesting {
        bool frozen;
        uint totalTC;
        uint timeStart;
        uint timeEnd_1yr;
        uint timeEnd_2yrs;
        uint timeEnd_3yrs;
        uint timeEnd_4yrs;
    }

    struct Sys {
        bool contractIsFrozen;          // contractIsFrozen() deposits are not accepted
        uint minGas;                    // minimum amount of gas required for each loop in a looping transaction
        uint numUsers;                  // numUsers
        uint maxUsers;                  // BotPoolMaxUsers()
        uint timeLastModifiedProfitFee; // the last time the profit fee was increased by the multisig
        uint weeklyFeeTimeSlippage;     // weeklyFeeTimeSlippage()
        uint maxSingleLoopSize;         // maximum number of entities that can be looped over in a single transaction of 30m gas
    }

    struct Info {
        address from;                   // which BotPool fulfilled this `getInfo()` request?
        string mode;                    // ex. "Automatic" or "Advanced" or "Follower"
        string timeframe;               // TF of the TV strategy being applied in this BotPool
        string strategyName;            // name of the TradingView strategy being applied in this BotPool
        string description;             // overall description of the BotPool
        string version;                 // version of the BotPool
        uint totalBotBalanceCash;       // the sum of all value held by BotTraders in this BotPool as measured in `cash`
        uint totalBotDebtCash;          // the sum of all debt held by BotTraders in this BotPool as measured in `cash`
        uint entryPrice;                // entry price of the most recent entry trade
        uint entryPriceDecimals;        // divisor for `entryPrice` above
        BotTraders botTraders;
        Upkeep upkeep;
        Asset asset;
        Cash cash;
        TC tc;
        TCC tcc;
        Pct pct;
        Adresse adresse;
        Vesting vesting;
        Sys sys;
    }

    // getInfo()
    //     |-- address:    from                         which BotPool fulfilled this `getInfo()` request?
    //     |-- string:     mode                         example: "Automatic"
    //     |-- string:     timeframe                    timeframe of the chart for the strategy being applied in this BotPool
    //     |-- string:     strategyName                 name of the strategy being applied in this BotPool
    //     |-- string:     description                  general description and notepad for this BotPool
    //     |-- uint:       totalBotBalanceCash;         the sum of all value held by BotTraders in this BotPool as measured in `cash`
    //     |-- uint:       totalBotDebtCash;            the sum of all debt held by BotTraders in this BotPool as measured in `cash`
    //     |-- uint:       entryPrice                   entry price from the first active BotTrader from `botTraders --> list`
    //     |-- uint:       entryPriceDecimals           decimals of the above `entryPrice`; denominator is 10 ^ {{ this }}
    //     \\-- group: botTraders
    //         |-- address[]:  list                     list of all BotTraders in this BotPool (BotTraders are children of BotPools)
    //         |-- uint:       count                    how many BotTraders are there in this BotPool?
    //         |-- uint:       max                      what's the maximum number of permitted BotTraders for this BotPool?
    //         |-- address:    available                which BotTrader is currently accepting users?
    //         |-- address:    botFactory               address of the BotFactory from which BotTraders are created
    //     \\-- group: upkeep
    //         |-- uint:   nextTime                 timestamp given in UNIX time of seconds when the weekly upkeep fee will next be charged
    //         |-- uint:   lastTimeModified         timestamp given in UNIX time of seconds when the weekly upkeep fee was last modified
    //         |-- uint:   fee                      amount of `tc` to be charged at the next weekly upkeep
    //         |-- uint:   minWeeks                 number of weeks of {{ n Σ `fee` + 5% }} required
    //         |-- uint:   reqFromZeroCash          amount of `tc` to be charged from present `block.timestamp` to the next weekly upkeep
    //     \\-- group: asset
    //         |-- address:    adresse                  address of the token to trade against AKA `asset`
    //         |-- string:     symbol                   ticker/symbol of the `asset` token
    //         |-- uint8:      decimals                 number of decimals this currency has; denominator is 10 ^ {{ this }}
    //         |-- uint:       denominator              10 ** `decimals` above
    //     \\-- group: cash
    //         |-- address:    adresse                  address of the token users deposit AKA `cash`
    //         |-- string:     symbol                   ticker/symbol of the `cash` token
    //         |-- uint8:      decimals                 number of decimals this currency has; denominator is 10 ^ {{ this }}
    //         |-- uint:       denominator              10 ** `decimals` above
    //         |-- uint:       balance                  total amount of `cash` for the BotPool; running internal total NOT cash.balanceOf(address(BotPool))
    //         |-- uint:       botPoolMax               if BotPool has more than this amount of `cash`, Deposits will be suspended
    //         |-- uint:       perUserMax               if a user has more than this amount of `cash`, they will be unable to Deposit more
    //         |-- uint:       overSwapMax              when performing a swap to withdraw immediately, this is the `cash` limit to overswap beyond the requested amount
    //         |-- uint:       minReqBalance            threshold of `cash` below which users are unable to partially withdraw
    //     \\-- group: tc
    //         |-- address:    adresse                  address of the token users deposit AKA `tc`
    //         |-- string:     symbol                   ticker/symbol of the `tc` token
    //         |-- uint8:      decimals                 number of decimals this currency has; denominator is 10 ^ {{ this }}
    //         |-- uint:       denominator              10 ** `decimals` above
    //         |-- uint:       balance                  total amount of TC for the BotPool; running internal total NOT tc.balanceOf(address(BotPool))
    //         |-- address:    adminWallet              expected to be the same multi-sig wallet as `addresses --> adminWallet`
    //         |-- address:    treasuryWallet           expected to be the same multi-sig wallet as `addresses --> treasuryWallet`
    //         |-- uint:       circulatingSupply        amount of `tc` not held by the admin or treasury wallets
    //         |-- uint:       operatingDepositRatio    amount of `tc` per `cash` that must be deposited
    //         |-- uint:       minReqBalance            minimum required amount of `tc` to be held on-deposit
    //     \\-- group: tcc
    //         |-- address:    adresse                  address of the token users deposit AKA `tcc`
    //         |-- string:     symbol                   ticker/symbol of the `tcc` token
    //         |-- uint8:      decimals                 number of decimals this currency has; denominator is 10 ^ {{ this }}
    //         |-- uint:       denominator              10 ** `decimals` above
    //         |-- uint:       balance                  total amount of TCC for the BotPool; IS == tcc.balanceOf(address(BotPool))
    //         |-- address:    adminWallet              expected to be the same multi-sig wallet as `addresses --> adminWallet`
    //         |-- address:    treasuryWallet           expected to be the same multi-sig wallet as `addresses --> treasuryWallet`
    //         |-- uint:       circulatingSupply        amount of `tcc` not held by the admin or treasury wallets
    //         \\-- group: rewards
    //             |-- uint:   nextUser                 == BotPool.tccNextUserToReward()
    //             |-- uint:   inEscrow                 == botPool.tccInEscrow()
    //             |-- uint:   timeFrozen               == BotPool.tccTimeFrozen()
    //             |-- uint:   timeToMelt               == BotPool.tccTimeToMelt()
    //             |-- uint:   timeEnabled              == BotPool.tccTimeEnabled()
    //     \\-- group: pct
    //         |-- uint:       oneHundred               number representing 100.0%; divisor for all below values inside this `pct` group
    //         |-- uint:       profitFee                percentage of profits sent to the `treasuryWallet` upon standard, pending withdrawal
    //         |-- uint:       profitFeePenalty         percentage of profits sent to the `treasuryWallet` when immediately withdrawn
    //         |-- uint:       apr                      percentage of `tcc` earned for `tc` deposited; 1000 TC @ 21.0% `apr` = 210 TCC earned in 1 year
    //         |-- uint:       aprBotBonus              percentage of `tcc` earned for `cash` deposited
    //         |-- uint:       slippage                 maximum amount of frontrunning price movement acceptable when swapping
    //         |-- uint:       reserve                  percentage of `cash` held outside of AAVE when in a Short position
    //         |-- uint:       borrow                   percentage of `cash` to borrow in `asset` value; 68% 1000 `cash` = $680 worth of Bitcoin @ $50/BTC = 13.6 BTC borrowed
    //         |-- uint:       dexFee                   maximum amount of liquidity provider fee acceptable when swapping
    //         |-- uint:       overSwap                 maximum percentage of a withdrawing position acceptable to overswap; 5 `cash` request = 0.15 `cash` max overswap
    //         |-- uint:       minBalQuality            minimum amount of `cash` a user must receive for a Withdraw All transaction to succeed
    //         |-- uint:       shortSlippage            approximation of slippage fees when Short; attempts to charge slippage to the withdrawing user
    //         |-- uint[]:     feeReductions            list of percentage fee reductions applied when owning an NFT; in ascending order
    //     \\-- group: adresse     
    //         |-- address:    frontend                 intended to be the same as this contract AKA `address(this)`
    //         |-- address:    botController            from where BotPool gets its values; has authority over BotPool parameters
    //         |-- address:    adminWallet              intended to be the same as the TC Main multi-sig wallet
    //         |-- address:    treasuryWallet           intended to be the same as the TC Treasury multi-sig wallet
    //         |-- address:    weeklyFeeWallet          set and managed by the editors such as Trendespresso
    //         |-- address:    nftAdmin                 smart contract administering all NFTs in use by BotPool
    //         |-- address:    presale                  the Presale smart contract address
    //         |-- address:    originalFrontend         taken from BotPool; immutable after deployment
    //         |-- address[]:  originalContracts        a list of contracts at deployment time
    //     \\-- group: sys
    //         |-- bool:       contractIsFrozen         == BotPool.contractIsFrozen()
    //         |-- uint:       presaleTimeEnded         == BotPool.presaleTimeEnded()
    //         |-- uint:       vestingEndTimeGlobal     == BotPool.vestingEndTimeGlobal()
    //         |-- uint:       minGas                   == BotPool.minGas()
    //         |-- uint:       numUsers                 == BotPool.numUsers()
    //         |-- uint:       maxUsers                 == BotPool.maxUsers()
    //         |-- uint:       timeLastModifiedProfitFee == BotController.
    //         |-- uint:       maxSingleLoopSize        maximum number of items that can be looped in a single transaction of ≈ 8m gas
    //         |-- uint:       maxPendingTX             maximum number of pending Editor multi-sig transactions that can co-exist

    function getBotTraderObject(address botPool, address sender) external view returns (BotTradersAdmins memory botTrader) {
        IBotPool BotPool = IBotPool(botPool);
        require(
            BotPool.sysGetLevel(msg.sender) || (BotPool.frontend() == msg.sender && BotPool.sysGetLevel(sender)),
            "GET INFO | AUTH: Sender of `getBotTraderObject()` must be a member of the admin team."
        );

        botTrader.list = BotPool.getBotTraders();
        botTrader.count = BotPool.numBotTraders();
        botTrader.max = BotPool.maxBotTraders();
        botTrader.available = BotPool.availableBotTrader();
        botTrader.botFactory = BotPool.botFactory();
        botTrader.tradingWallet = BotPool.getTradingWallets();

        // TradeStatus
        uint len = botTrader.count;
        // IBotTrader[] memory _botTraders = BotPool. // not sufficient bytecode in BotPool to get a raw IBotTrader[]
        int[] memory _tradeStatus = new int[](len);
        uint[] memory _activeUsers = new uint[](len);
        uint[] memory _numUsers = new uint[](len);
        bool[] memory _isRepayingLoan = new bool[](len);
        uint[] memory _entryPrice = new uint[](len);
        uint[] memory _pendingUser = new uint[](len);
        bool[] memory _pendingExecAllowed = new bool[](len);
        uint[] memory _balancesUser = new uint[](len);
        bool[] memory _balancesUpdated = new bool[](len);
        uint[] memory _tradeExitCashBalance = new uint[](len);
        uint[] memory _balancesSum = new uint[](len);

        for (uint i; i < len; ++i) {
            IBotTrader BotTrader = IBotTrader(botTrader.list[i]);
            _tradeStatus[i] = BotTrader.tradeStatus();
            _activeUsers[i] = BotTrader.activeUsers();
            _numUsers[i] = BotTrader.numUsers();
            _isRepayingLoan[i] = BotTrader.isRepayingLoan();
            _entryPrice[i] = BotTrader.entryPrice();
            _pendingUser[i] = BotTrader.pendingUser();
            _pendingExecAllowed[i] = BotTrader.pendingExecAllowed();
            _balancesUser[i] = BotTrader.balancesUser();
            _balancesUpdated[i] = BotTrader.balancesUpdated();
            _tradeExitCashBalance[i] = BotTrader.tradeExitCashBalance();
            _balancesSum[i] = BotTrader.balancesSum();

            // Check for this: 0xE5505
            // if (BotTrader.tradingWallet() != botTrader.tradingWallet[i]) {
            //     botTrader.tradingWallet[i] = addressError; // botTrader.list[i];
            // }
        }

        botTrader.tradeStatus = _tradeStatus;
        botTrader.activeUsers = _activeUsers;
        botTrader.numUsers = _numUsers;
        botTrader.isRepayingLoan = _isRepayingLoan;
        botTrader.entryPrice = _entryPrice;
        botTrader.pendingUser = _pendingUser;
        botTrader.pendingExecAllowed = _pendingExecAllowed;
        botTrader.balancesUser = _balancesUser;
        botTrader.balancesUpdated = _balancesUpdated;
        botTrader.tradeExitCashBalance = _tradeExitCashBalance;
        botTrader.balancesSum = _balancesSum;

        return botTrader;
    }

    address public constant addressError = 0x11111111111111111111111111111111111E5505;

    uint8 public constant t = 5; // MUST == BotPool.t();

    function getInfo(address botPool) external view returns (Info memory info) {
		IBotPool BotPool = IBotPool(botPool);
        IBotController BotController = BotPool.botController();

        IERC20 _cash = BotController.cash();
        IERC20 _asset = BotPool.asset();
        IERC20T _tc = BotController.tc();
        IERC20T _tcc = BotController.tcc();

        uint[t] memory vestedInfo = BotPool.getVestedValues(0);

        info = Info(
            botPool,
            BotPool.mode(),
            BotPool.timeframe(),
            BotPool.strategyName(),
            BotPool.description(),
            BotPool.version(),
            0, // BotPool.getTotalBalance() * minBalQualifyPercentage / oneHundredPct,
            0, // stack too deep -- BotPool.getTotalDebt(),
            0, // stack too deep -- BotPool.getEntryPrice(),
            0, // stack too deep -- BotPool.getEntryPriceDecimals(),
            BotTraders(
                BotPool.getBotTraders(),
                BotPool.numBotTraders(),
                BotPool.maxBotTraders(),
                BotPool.botTraderMaxUsers(),
                BotPool.availableBotTrader(),
                BotPool.botFactory()
            ),
            Upkeep(
                BotPool.nextTimeUpkeepGlobal(),
                BotController.lastTimeUpkeepModified(),
                BotController.tcUpkeep(),
                BotController.minFutureWeeksTCDeposit(),
                0
            ),
            Asset(
                address(_asset),
                _asset.symbol(),        // _asset.symbol(),
                _asset.decimals(),
                BotPool.assetDecimals() // _asset.decimals()
            ),
            Cash(
                address(_cash),
                _cash.symbol(),         // _cash.symbol(),
                _cash.decimals(),
                BotPool.cashDecimals(), // _cash.decimals(),
                BotPool.botPoolCashBalance(),
                BotController.botPoolMaxCash(),
                BotController.perUserMaxCash(),
                BotController.overswapMaxCash(),
                BotController.minReqBalCash()
            ),
            TC(
                address(_tc),
                _tc.symbol(),           // _tc.symbol(),
                _tc.decimals(),
                BotPool.tcDecimals(),   // _tc.denominator()   // _tc.decimals(),
                BotPool.totalBalanceTC(),
                _tc.adminWallet(),
                _tc.treasuryWallet(),
                _tc.getCirculatingSupply(),
                BotController.operatingDepositRatio(),
                BotController.minReqBalTC()
            ),
            TCC(
                address(_tcc),
                _tcc.symbol(),          // _tcc.symbol(),
                _tcc.decimals(),
                BotPool.tccDecimals(),  // _tcc.denominator()   // _tcc.decimals(),
                _tcc.balanceOf(botPool),
                _tcc.adminWallet(),
                _tcc.treasuryWallet(),
                _tcc.getCirculatingSupply(),
                getRewardsInfo(botPool)
            ),
            Pct(
                BotPool.oneHundredPct(),
                BotController.profitFee(),
                BotController.profitFeePenalty(),
                BotController.apr(),
                BotController.aprBotBonus(),
                BotController.slippagePct(),
                BotController.reservePct(),
                BotController.borrowPct(),
                BotController.dexFeePct(),
                BotController.overswapPct(),
                BotController.minBalQualifyPct(),
                BotController.shortSlippagePct(),
                BotController.getFeeReductions()
            ),
            Adresse(
                BotPool.frontend(),
                address(BotController),
                BotPool.adminWallet(),
                BotController.treasuryWallet(),
                BotController.weeklyFeeWallet(),
                address(BotController.nftAdmin()),
                BotPool.presale(),
                BotPool.originalFrontend(),
                BotController.getOriginalContracts()
            ),
            Vesting(
                BotPool.vestingFrozen(),
                BotPool.totalVestedTC(),
                vestedInfo[0],
                vestedInfo[1],
                vestedInfo[2],
                vestedInfo[3],
                vestedInfo[4]
            ),
            Sys(
                BotPool.contractIsFrozen(),
                BotPool.minGas(),
                BotPool.numUsers(),
                BotPool.botPoolMaxUsers(),
                BotController.lastTimeProfitFeeModified(),
                BotController.weeklyFeeTimeSlippage(),
                BotController.maxSingleLoopSize()
            )
        );

        return _getInfoStackTooDeep(BotPool, BotController, info);
    }

    function _getInfoStackTooDeep(IBotPool BotPool, IBotController BotController, Info memory info) private view returns (Info memory) {
        info.upkeep.reqFromZeroCash = BotController.tcReqUpkeepPaymentOf(address(0), int(BotPool.nextTimeUpkeepGlobal()) - int(block.timestamp));
        (info.totalBotBalanceCash, info.entryPrice, info.entryPriceDecimals, info.totalBotDebtCash) = BotPool.getTotal_balance_entryPrice_debt();

        // This gets handled automatically in `BotTraderLib_util --> getBotTotalCashBalance()`
        // info.totalBotBalanceCash *= info.pct.minBalQualify;
        // info.totalBotBalanceCash /= BotPool.oneHundredPct();

        return info;
    }

    function getRewardsInfo(address botPool) public view returns (Rewards memory) {
        IBotPool BotPool = IBotPool(botPool);

        return 
            Rewards(
                BotPool.tccNextUserToReward(),
                BotPool.tccInEscrow(),
                BotPool.tccTimeFrozen(),
                BotPool.tccTimeToMelt(),
                BotPool.tccTimeEnabled()
            );
    }

}