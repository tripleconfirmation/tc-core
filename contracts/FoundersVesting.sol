// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./Baked.sol";

import "./libraries/FoundersVestingLib_util.sol";
import "./libraries/FoundersVestingLib_structs.sol";
import "./libraries/Caffeinated.sol";

import "./interfaces/IERC20T.sol";
import "./interfaces/IERC20.sol";

// import "hardhat/console.sol";

contract FoundersVesting is Baked {

    // ### EVENTS ###
    event Claimed(address indexed founder, uint tcAmount, uint tccAmount);
    event LostTokens(address indexed token, uint amount, address indexed receiver);
    event AddressChange(address indexed prev, address indexed current);
    event Extinguished(uint tcTotal, uint tccTotal);

    string public constant version = "2023-01-28 | Alpha v2";

    IERC20T public immutable tc;
    IERC20T public immutable tcc;
    function TC() external view returns (IERC20T) {
        return tc;
    }
    function TCC() external view returns (IERC20T) {
        return tcc;
    }

    // IERC20(0x5425890298aed601595a70AB815c96711a31Bc65); FUJI
    // IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E); MAINNET
    IERC20 public constant USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    
    // IERC20(0x45ea5d57BA80B5e3b0Ed502e9a08d568c96278F9); FUJI
    // IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664); MAINNET
    IERC20 public constant USDCe = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);

    FoundersVestingLib_structs.Token public /* immutable */ tcInfo;
    FoundersVestingLib_structs.Token public /* immutable */ tccInfo;

    // FoundersVestingLib_structs.TokenUSD public usdcInfo = FoundersVestingLib_structs.emptyTokenUSD(USDC);       // = FoundersVestingLib_structs.TokenUSD(address(USDC), USDC.symbol(), USDC.decimals(), 10 ** USDC.decimals(), 0, 0, 0, 0, 0);
    // FoundersVestingLib_structs.TokenUSD public usdceInfo = FoundersVestingLib_structs.emptyTokenUSD(USDCe);     // = FoundersVestingLib_structs.TokenUSD(address(USDCe), USDCe.symbol(), USDCe.decimals(), 10 ** USDCe.decimals(), 0, 0, 0, 0, 0);
    uint public totalUSDCRemaining;
    uint public totalUSDCeRemaining;
    uint public lastTimeNotified;
    FoundersVestingLib_structs.Founder[] public /* immutable */ founders;
    uint public immutable tcTotalAllocation;
    uint public immutable tcPerFounder;
    uint public immutable tccTotalAllocation;
    uint public immutable tccPerFounder;
    bool public claimingEnabled;
    uint public /* immutable */ timeEnd;
    uint public constant timeDuration = 131573590; // 4 years + 2 months
    function pctTimeElapsed() external view returns (uint) {
        if (!claimingEnabled) {
            return 0;
        }

        if (block.timestamp > timeEnd) {
            return Caffeinated.precision;
        }

        return Caffeinated.precision - Caffeinated.toPercent(timeEnd - block.timestamp, timeDuration);
    }

    address public presale;
    bool public someUSDHasBeenClaimed;
    bool public funded;
    uint public tcTotalClaimed;
    uint public tccTotalClaimed;
    uint public tcRemaining;
    uint public tccRemaining;
    mapping(address => uint) public founderIDs;
    uint public numFounders;

    constructor(address[] memory _tokens, address[] memory _founders) {
        adminWallet = msg.sender;
        tc = IERC20T(_tokens[0]);
        tcc = IERC20T(_tokens[1]);
        // timeEnd = block.timestamp + timeDuration; // 4 years, 2 months incl one leap year day

        // usdcInfo = FoundersVestingLib_structs.TokenUSD(address(USDC), USDC.symbol(), USDC.decimals(), 10 ** USDC.decimals(), 0, 0, 0, 0, 0);
        // usdceInfo = FoundersVestingLib_structs.TokenUSD(address(USDCe), USDCe.symbol(), USDCe.decimals(), 10 ** USDCe.decimals(), 0, 0, 0, 0, 0);

        uint _tcDenominator = 10 ** tc.decimals();
        uint _tccDenominator = 10 ** tcc.decimals();
        uint _tcTotal = 14200000 * _tcDenominator;
        uint _tccTotal = 142069000 * _tccDenominator;

        tcPerFounder = _tcTotal / _founders.length;
        tccPerFounder = _tccTotal / _founders.length;

        tcTotalAllocation = tcPerFounder * _founders.length;
        tccTotalAllocation = tccPerFounder * _founders.length;
        tcRemaining = tcTotalAllocation;
        tccRemaining = tccTotalAllocation;

        tcInfo = FoundersVestingLib_structs.Token(
            _tokens[0],
            tc.symbol(),
            tc.decimals(),
            _tcDenominator,
            tc.adminWallet(),
            tc.treasuryWallet(),
            tc.getCirculatingSupply(),
            tcPerFounder,
            tcPerFounder,
            0,
            0,
            block.timestamp
        );

        tccInfo = FoundersVestingLib_structs.Token(
            _tokens[1],
            tcc.symbol(),
            tcc.decimals(),
            _tccDenominator,
            tcc.adminWallet(),
            tcc.treasuryWallet(),
            tcc.getCirculatingSupply(),
            tccPerFounder,
            tccPerFounder,
            0,
            0,
            block.timestamp
        );

        FoundersVestingLib_structs.Token memory tcInfoEmpty = tcInfo;
        delete tcInfoEmpty.allocation;
        delete tcInfoEmpty.remaining;
        tcInfoEmpty.lastTimeClaimed = 0;

        FoundersVestingLib_structs.Token memory tccInfoEmpty = tccInfo;
        delete tccInfoEmpty.allocation;
        delete tccInfoEmpty.remaining;
        tccInfoEmpty.lastTimeClaimed = 0;

        founders.push(
            FoundersVestingLib_structs.Founder(
                address(0),
                0,
                false,
                tcInfoEmpty,
                tccInfoEmpty,
                FoundersVestingLib_structs.emptyTokenUSD(USDC),
                FoundersVestingLib_structs.emptyTokenUSD(USDCe),
                block.timestamp,
                timeEnd
            )
        );

        for (uint i; i < _founders.length; ++i) {
            ++numFounders;
            founders.push(
                FoundersVestingLib_structs.Founder(
                    _founders[i],
                    numFounders,
                    true,
                    tcInfo,
                    tccInfo,
                    FoundersVestingLib_structs.emptyTokenUSD(USDC),
                    FoundersVestingLib_structs.emptyTokenUSD(USDCe),
                    block.timestamp,
                    timeEnd
                )
            );
            founderIDs[_founders[i]] = numFounders;
        }
    }




    modifier _presaleAuth() {
        require(
            msg.sender == presale || msg.sender == adminWallet,
            "FOUNDERS | AUTH: Sender must be either the Presale contract or the Admin Wallet."
        );
        _;
    }

    function setPresale(address newPresale) external _adminAuth {
        require(presale == address(0), "FOUNDERS | SET PRESALE: Can only be set once.");
        presale = newPresale;
    }




    // ### GETTER FUNCTIONS ###
    function getFoundersList() external view returns (FoundersVestingLib_structs.Founder[] memory) {
        // FoundersVestingLib.Founder[] memory _founders = new FoundersVestingLib.Founder[](founders.length);
        // _founders[0] = founders[0];
        FoundersVestingLib_structs.Founder[] memory _founder = founders;

        // Return the adjusted claimable amounts depending on present time.
        for (uint i = 1; i < _founder.length; ++i) {
            _founder[i] = getFounderID(i);
        }

        return _founder;
    }

    function getRawFoundersList() external view returns (FoundersVestingLib_structs.Founder[] memory) {
        return founders;
    }

    function getFounderID(uint founderID) public view returns (FoundersVestingLib_structs.Founder memory) {
        // Return the adjusted claimable amounts depending on present time.
        return FoundersVestingLib_util._adjustClaimables(founderID);
    }

    function getRawFounderID(uint founderID) external view returns (FoundersVestingLib_structs.Founder memory) {
        return founders[founderID];
    }

    function getFounder(address account) external view returns (FoundersVestingLib_structs.Founder memory) {
        return getFounderID(founderIDs[account]);
    }




    // ### SETTER FUNCTIONS ###
    function setNewAddress(address newAddress) external { 
        uint founderID = founderIDs[msg.sender];
        require(founderID != 0 && founders[founderID].isFounder, "FOUNDERS | AUTH: `msg.sender` is not a Founder.");

        founderIDs[newAddress] = founderID;
        delete founderIDs[msg.sender];

        founders[founderIDs[newAddress]].adresse = newAddress;
        emit AddressChange(msg.sender, newAddress);
    }




    // ### FUNDING FUNCTIONS ###
    function fund() public {
        funded = FoundersVestingLib_util._fund();
    }

    function notifyUSDFunding() external _presaleAuth {
        uint USDCBalancePerUser = USDC.balanceOf(address(this));
        uint USDCeBalancePerUser = USDCe.balanceOf(address(this));
        if (
            timeEnd == 0
            || !claimingEnabled
            || lastTimeNotified == 0
            || USDCBalancePerUser > totalUSDCRemaining
            || USDCeBalancePerUser > totalUSDCeRemaining
        ) {
            if (timeEnd == 0) {
                timeEnd = block.timestamp + timeDuration;

                // i = 0 implicitly thereby including global
                for (uint8 i; i < founders.length; ++i) {
                    founders[i].tc.lastTimeClaimed = block.timestamp;
                    founders[i].tcc.lastTimeClaimed = block.timestamp;
                    founders[i].usdc.lastTimeClaimed = block.timestamp;
                    founders[i].usdce.lastTimeClaimed = block.timestamp;
                    founders[i].timeStart = block.timestamp;
                    founders[i].timeEnd = timeEnd;
                }
            }
            // claimingEnabled = true;
            // return;
            lastTimeNotified = 2 days + block.timestamp;
        }

        if (!someUSDHasBeenClaimed) {
            USDCBalancePerUser = (USDCBalancePerUser - totalUSDCRemaining) / numFounders;
            USDCeBalancePerUser = (USDCeBalancePerUser - totalUSDCeRemaining) / numFounders;
            // uint _usdcBal = totalUSDCRemaining;
            // uint _usdceBal = totalUSDCeRemaining;
            for (uint8 i = 1; i <= numFounders; ++i) {
                founders[i].usdc.allocation += USDCBalancePerUser;
                founders[i].usdc.remaining += USDCBalancePerUser;
                founders[i].usdc.claimable += USDCBalancePerUser;
                totalUSDCRemaining += USDCBalancePerUser;

                founders[i].usdce.allocation += USDCeBalancePerUser;
                founders[i].usdce.remaining += USDCeBalancePerUser;
                founders[i].usdce.claimable += USDCeBalancePerUser;
                totalUSDCeRemaining += USDCeBalancePerUser;
            }

            FoundersVestingLib_util._notifyUSDFunding();

            lastTimeNotified = 2 days + block.timestamp;
        }
        // If 2 days have passed since the beginning of Founders Vesting, then the USDC can be withdrawn by the TC's TreasuryWallet().
        else if (block.timestamp > lastTimeNotified) {
            // require( "FOUNDES | USD FUNDING: Cannot notify and reset balances " );
            FoundersVestingLib_util._notifyUSDFundingTimeExpiration();
        }
    }

    

    // contract.decreaseLiquidity({ tokenId: 12345, liquidity: 100, amount0Min: 100, amount1Min: 100, deadline: 100 }).send()
    // https://docs.uniswap.org/contracts/permit2/reference/signature-transfer
    // https://github.com/Uniswap/permit2/blob/main/src/SignatureTransfer.sol
    // https://www.web3.university/article/how-to-verify-a-signed-message-in-solidity
    // https://leon-do.github.io/ecrecover/
    function fundWithPermit(FoundersVestingLib_structs.Permit calldata tcPermit, FoundersVestingLib_structs.Permit calldata tccPermit) external {
        if (tcPermit.approveAmount > 0) {
            tc.permit(tcPermit.account, address(this), tcPermit.approveAmount, tcPermit.deadline, tcPermit.v, tcPermit.r, tcPermit.s);
        }
        if (tccPermit.approveAmount > 0) {
            tcc.permit(tcPermit.account, address(this), tccPermit.approveAmount, tccPermit.deadline, tccPermit.v, tccPermit.r, tccPermit.s);
        }
        fund();
    }




    // ### CLAIM FUNCTIONS ###
    // function claimableAmounts(address founder) public view returns (uint, uint) {
    //     (
    //         , // uint founderID,
    //         uint tcClaimable,
    //         uint tccClaimable
    //     ) = claimables(founder);
    //     return (tcClaimable, tccClaimable);
    // }

    // function claimables(address founder) public view returns (uint, uint, uint) {
    //     uint founderID = founderIDs[founder];

    //     if (!claimingEnabled) {
    //         return (founderID, 0, 0);
    //     }

    //     uint pctClaimingTC = block.timestamp >= timeEnd ? Caffeinated.precision : Caffeinated.toPercent(block.timestamp - founders[founderID].tc.lastTimeClaimed, timeDuration);
    //     uint pctClaimingTCC = block.timestamp >= timeEnd ? Caffeinated.precision : Caffeinated.toPercent(block.timestamp - founders[founderID].tcc.lastTimeClaimed, timeDuration);
    //     return (
    //         founderID,
    //         Caffeinated.fromPercent(pctClaimingTC, founders[founderID].tc.allocation) + founders[founderID].tc.claimable,
    //         Caffeinated.fromPercent(pctClaimingTCC, founders[founderID].tcc.allocation) + founders[founderID].tcc.claimable
    //     );
    // }

    function claimAllUSDC() external {
        claimUSDC(type(uint).max, type(uint).max);
    }

    function claimUSDC(uint amountUSDC, uint amountUSDCe) public {
        uint founderID = founderIDs[msg.sender];
        require(founderID != 0 && founders[founderID].isFounder, "FOUNDERS | AUTH: `msg.sender` is not a Founder.");

        if (amountUSDC > founders[founderID].usdc.remaining) {
            amountUSDC = founders[founderID].usdc.remaining;
        }

        if (amountUSDCe > founders[founderID].usdce.remaining) {
            amountUSDCe = founders[founderID].usdce.remaining;
        }

        if (!someUSDHasBeenClaimed) {
            someUSDHasBeenClaimed = amountUSDC > 0 || amountUSDCe > 0;
        }

        if (amountUSDC > 0) {
            founders[founderID].usdc.remaining -= amountUSDC;
            founders[founderID].usdc.claimable -= amountUSDC;
            founders[founderID].usdc.claimed += amountUSDC;
            USDC.transfer(founders[founderID].adresse, amountUSDC);
            totalUSDCRemaining -= amountUSDC;
        }

        if (amountUSDCe > 0) {
            founders[founderID].usdce.remaining -= amountUSDCe;
            founders[founderID].usdce.claimable -= amountUSDCe;
            founders[founderID].usdce.claimed += amountUSDCe;
            USDCe.transfer(founders[founderID].adresse, amountUSDCe);
            totalUSDCeRemaining -= amountUSDCe;
        }
    }

    function claimAll() external {
        claim(type(uint).max, type(uint).max);
    }

    function claim(uint amountTC, uint amountTCC) public {
        // require(funded, "FOUNDERS | ALLOCATION: Not yet funded.");
        // require(claimingEnabled, "FOUNDES | ALLOCATION: Presale not yet ended. (1)");

        // (
        //     uint founderID,
        //     uint tcClaimable,
        //     uint tccClaimable
        // ) = claimables(msg.sender);

        // require(founderID != 0 && founders[founderID].isFounder, "FOUNDERS | AUTH: `msg.sender` is not a Founder.");
        // require(tcClaimable > 0 || tccClaimable > 0, "FOUNDERS | ALLOCATION: Presale not yet ended. (2)");

        (
            address founderAddress,
            uint founderID,
            uint tcClaimable,
            uint tccClaimable
        ) = FoundersVestingLib_util._claim();

        if (amountTC > 0) {
            if (amountTC > tcClaimable) {
                amountTC = tcClaimable;
            }
            if (amountTC > founders[founderID].tc.remaining) {
                amountTC = founders[founderID].tc.remaining;
            }

            founders[founderID].tc.remaining -= amountTC;
            founders[founderID].tc.claimed += amountTC;
            founders[founderID].tc.claimable = tcClaimable - amountTC;
            founders[founderID].tc.lastTimeClaimed = block.timestamp;
            tc.transfer(founderAddress, amountTC);
            tcTotalClaimed += amountTC;
            tcRemaining -= amountTC;
        }

        if (amountTCC > 0) {
            if (amountTCC > tccClaimable) {
                amountTCC = tccClaimable;
            }
            if (amountTCC > founders[founderID].tcc.remaining) {
                amountTCC = founders[founderID].tcc.remaining;
            }

            founders[founderID].tcc.remaining -= amountTCC;
            founders[founderID].tcc.claimed += amountTCC;
            founders[founderID].tcc.claimable = tccClaimable - amountTCC;
            founders[founderID].tcc.lastTimeClaimed = block.timestamp;
            tcc.transfer(founderAddress, amountTCC);
            tccTotalClaimed += amountTCC;
            tccRemaining -= amountTCC;
        }

        emit Claimed(founderAddress, amountTC, amountTCC);
    }




    // ### MISC FUNCTIONS ###
    // Allows anyone to claim tokens that were accidentally received at this address.
    function claimERC20(address token) external {
        uint tokenBalance = FoundersVestingLib_util._claimERC20(token);
        if (tokenBalance > 0) {
            emit LostTokens(token, tokenBalance, msg.sender);
        }
    }

    function selfDestruct() external {
        require(
            block.timestamp > timeEnd,
            string.concat(
                "FOUNDERS | TIME: Ending hasn't yet occurred. Current: ",
                Caffeinated.uintToString(block.timestamp),
                ". End: ",
                Caffeinated.uintToString(timeEnd),
                "."
            )
        );

        bool fullyAllocated = true;
        for (uint i; i <= numFounders; ++i) {
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tc.remaining:  ", Caffeinated.uintToString(founders[i].tc.remaining)));
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tc.claimed:    ", Caffeinated.uintToString(founders[i].tc.claimed)));
            // console.log(string.concat("tcTotalClaimed:            ", Caffeinated.uintToString(tcTotalClaimed)));

            tc.transfer(founders[i].adresse, founders[i].tc.remaining);
            founders[i].tc.claimed += founders[i].tc.remaining;
            tcTotalClaimed += founders[i].tc.remaining;
            delete founders[i].tc.claimable;
            delete founders[i].tc.remaining;

            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tcc.remaining: ", Caffeinated.uintToString(founders[i].tcc.remaining)));
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tcc.claimed:   ", Caffeinated.uintToString(founders[i].tcc.claimed)));
            // console.log(string.concat("tccTotalClaimed:           ", Caffeinated.uintToString(tccTotalClaimed)));

            tcc.transfer(founders[i].adresse, founders[i].tcc.remaining);
            founders[i].tcc.claimed += founders[i].tcc.remaining;
            tccTotalClaimed += founders[i].tcc.remaining;
            delete founders[i].tcc.claimable;
            delete founders[i].tcc.remaining;

            // console.log("");
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tc.remaining:  ", Caffeinated.uintToString(founders[i].tc.remaining)));
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tc.claimed:    ", Caffeinated.uintToString(founders[i].tc.claimed)));
            // console.log(string.concat("tcTotalClaimed:            ", Caffeinated.uintToString(tcTotalClaimed)));
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tcc.remaining: ", Caffeinated.uintToString(founders[i].tcc.remaining)));
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tcc.claimed:   ", Caffeinated.uintToString(founders[i].tcc.claimed)));
            // console.log(string.concat("tccTotalClaimed:           ", Caffeinated.uintToString(tccTotalClaimed)));
            // console.log("");
            // console.log(string.concat("fullyAllocated: ", fullyAllocated ? "TRUE" : "FALSE"));
            // console.log("");

            if (founders[i].tc.claimed < founders[i].tc.allocation || founders[i].tcc.claimed < founders[i].tcc.allocation) {
                founders[i].tc.remaining = founders[i].tc.allocation - founders[i].tc.claimed;
                founders[i].tcc.remaining = founders[i].tcc.allocation - founders[i].tcc.claimed;
                founders[i].tc.claimable = founders[i].tc.remaining;
                founders[i].tcc.claimable = founders[i].tcc.remaining;
                fullyAllocated = false;
            }

            // console.log("");
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tc.remaining:  ", Caffeinated.uintToString(founders[i].tc.remaining)));
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tc.claimed:    ", Caffeinated.uintToString(founders[i].tc.claimed)));
            // console.log(string.concat("tcTotalClaimed:            ", Caffeinated.uintToString(tcTotalClaimed)));
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tcc.remaining: ", Caffeinated.uintToString(founders[i].tcc.remaining)));
            // console.log(string.concat("founders[", Caffeinated.uintToString(i), "].tcc.claimed:   ", Caffeinated.uintToString(founders[i].tcc.claimed)));
            // console.log(string.concat("tccTotalClaimed:           ", Caffeinated.uintToString(tccTotalClaimed)));
            // console.log("");
            // console.log(string.concat("fullyAllocated: ", fullyAllocated ? "TRUE" : "FALSE"));
            // console.log("");

        }

        if (fullyAllocated && tcTotalClaimed >= tcTotalAllocation && tccTotalClaimed >= tccTotalAllocation) {
            FoundersVestingLib_util._selfDestruct();
            
            emit Extinguished(tcTotalClaimed, tccTotalClaimed);
            // selfdestruct(payable(tc.treasuryWallet()));
        }
    }

}