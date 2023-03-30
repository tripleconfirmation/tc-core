// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./Caffeinated.sol";
import "./FoundersVestingLib_structs.sol";

import "../interfaces/IFoundersVesting.sol";
import "../interfaces/IERC20T.sol";
import "../interfaces/IERC20.sol";

library FoundersVestingLib_util {

    // struct Token {
    //     address adresse;                // address of this currency
    //     string symbol;                  // symbol of this currency
    //     uint8 decimals;                 // number of decimals this currency has
    //     uint denominator;               // divide by this number to get balance/value in decimal form
    //     address adminWallet;            // only used on TC/TCC: owner/admin wallet of this currency
    //     address treasuryWallet;         // only used on TC/TCC: treasury wallet of this currency
    //     uint circulatingSupply;         // only used on TC/TCC: circulating supply of this currency
    //     uint allocation;
    //     uint remaining;
    //     uint claimable;
    //     uint claimed;
    //     uint lastTimeClaimed;
    // }

    // struct TokenUSD {
    //     address adresse;
    //     string symbol;
    //     uint8 decimals;
    //     uint denominator;
    //     uint allocation;
    //     uint remaining;
    //     uint claimable;
    //     uint claimed;
    //     uint lastTimeClaimed;
    // }

    // struct Founder {
    //     address adresse;
    //     uint founderID;
    //     bool isFounder;
    //     Token tc;
    //     Token tcc;
    //     TokenUSD usdc;
    //     TokenUSD usdce;
    //     uint timeStart;
    //     uint timeEnd;
    // }

    modifier _presaleAuth() {
        IFoundersVesting FoundersVesting = IFoundersVesting(address(this));
        require(
            msg.sender == FoundersVesting.presale() || msg.sender == FoundersVesting.adminWallet(),
            "FOUNDERS LIB | AUTH: Sender must be either the Presale contract or the Admin Wallet."
        );
        _;
    }

    function tc() private view returns (IERC20T) {
        return IFoundersVesting(address(this)).tc();
    }
    function tcc() private view returns (IERC20T) {
        return IFoundersVesting(address(this)).tcc();
    }
    IERC20 public constant USDC = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
    IERC20 public constant USDCe = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);

    function _selfDestruct() external {
        IERC20T _tc = tc();
        IERC20T _tcc = tcc();
        _tc.transfer(_tc.treasuryWallet(), _tc.balanceOf(address(this)));
        _tcc.transfer(_tcc.treasuryWallet(), _tcc.balanceOf(address(this)));
        USDC.transfer(_tc.treasuryWallet(), USDC.balanceOf(address(this)));
        USDCe.transfer(_tc.treasuryWallet(), USDCe.balanceOf(address(this)));
    }

    function _notifyUSDFunding() external _presaleAuth {
        IFoundersVesting FoundersVesting = IFoundersVesting(address(this));

        uint _usdcRemainder = USDC.balanceOf(address(this)) - FoundersVesting.totalUSDCRemaining();
        uint _usdceRemainder = USDCe.balanceOf(address(this)) - FoundersVesting.totalUSDCeRemaining();
        // Okay to revert on these because that means the overall math here is incorrect.

        if (_usdcRemainder > 0) {
            USDC.transfer(tc().treasuryWallet(), _usdcRemainder);
        }

        if (_usdceRemainder > 0) {
            USDCe.transfer(tc().treasuryWallet(), _usdceRemainder);
        }

        require(
            FoundersVesting.totalUSDCRemaining() == USDC.balanceOf(address(this))
            && FoundersVesting.totalUSDCeRemaining() == USDCe.balanceOf(address(this)),
            "FOUNDERS | NOTIFY USD: Math did not correctly set balances."
        );
    }

    function _notifyUSDFundingTimeExpiration() external _presaleAuth {
        uint USDCBalance = USDC.balanceOf(address(this));
        uint USDCeBalance = USDCe.balanceOf(address(this));
        if (USDCBalance > 0) {
            USDC.transfer(tc().treasuryWallet(), USDCBalance);
        }
        if (USDCeBalance > 0) {
            USDCe.transfer(tc().treasuryWallet(), USDCeBalance);
        }
    }

    // function _claimableAmounts(address founder) external view returns (uint, uint) {
    //     (
    //         , // Founder memory _founder,
    //         uint tcClaimable,
    //         uint tccClaimable
    //     ) = _claimables(founder);
    //     return (tcClaimable, tccClaimable);
    // }

    function _adjustClaimables(uint founderID) public view returns (FoundersVestingLib_structs.Founder memory _founder) {
        IFoundersVesting FoundersVesting = IFoundersVesting(address(this));
        uint timeEnd = FoundersVesting.timeEnd();
        
        // return FoundersVestingLib_structs.emptyFounder();
        _founder = FoundersVesting.getRawFounderID(founderID);

        if (block.timestamp >= timeEnd) {
            _founder.tc.claimable = _founder.tc.remaining;
            _founder.tcc.claimable = _founder.tcc.remaining;
            return _founder;
        }

        if (!FoundersVesting.claimingEnabled()) {
            return _founder;
        }
        
        uint timeDuration = FoundersVesting.timeDuration();
        uint pctClaimingTC = block.timestamp >= timeEnd ? Caffeinated.precision : Caffeinated.toPercent(block.timestamp - _founder.tc.lastTimeClaimed, timeDuration);
        uint pctClaimingTCC = block.timestamp >= timeEnd ? Caffeinated.precision : Caffeinated.toPercent(block.timestamp - _founder.tcc.lastTimeClaimed, timeDuration);

        _founder.tc.claimable += Caffeinated.fromPercent(pctClaimingTC, _founder.tc.allocation);
        _founder.tcc.claimable += Caffeinated.fromPercent(pctClaimingTCC, _founder.tcc.allocation);
        return _founder;
    }

        // (
        //     address founderAddress,
        //     uint founderID,
        //     uint tcClaimable,
        //     uint tccClaimable
        // ) = FoundersVestingLib._claim();

    function _claim() external view returns (address, uint, uint, uint) {
        IFoundersVesting FoundersVesting = IFoundersVesting(address(this));
        require(FoundersVesting.funded(), "FOUNDERS | ALLOCATION: Not yet funded.");
        require(FoundersVesting.claimingEnabled(), "FOUNDES | ALLOCATION: Presale not yet ended. (1)");

        FoundersVestingLib_structs.Founder memory _founder = _adjustClaimables(FoundersVesting.founderIDs(msg.sender));
        
        require(_founder.founderID != 0 && _founder.isFounder, "FOUNDERS | AUTH: `msg.sender` is not a Founder.");
        require(_founder.tc.claimable > 0 || _founder.tcc.claimable > 0, "FOUNDERS | ALLOCATION: Presale not yet ended. (2)");

        return (
            _founder.adresse, // should == `msg.sender`
            _founder.founderID,
            _founder.tc.claimable,
            _founder.tcc.claimable
        );
    }

    function _fund() external returns (bool) {
        IFoundersVesting FoundersVesting = IFoundersVesting(address(this));
        require(!FoundersVesting.funded(), "FOUNDERS | ALLOCATION: Previously funded.");

        IERC20T _tc = tc();
        uint tcTotalAllocation = FoundersVesting.tcTotalAllocation();
        uint tcBal = _tc.balanceOf(address(this));
        if (tcBal < tcTotalAllocation) {
            _tc.transferFrom(msg.sender, address(this), tcTotalAllocation - tcBal);
        }
        else if (tcBal > tcTotalAllocation) {
            _tc.transfer(_tc.adminWallet(), tcBal - tcTotalAllocation);
        }

        IERC20T _tcc = tcc();
        uint tccTotalAllocation = FoundersVesting.tccTotalAllocation();
        uint tccBal = _tcc.balanceOf(address(this));
        if (tccBal < tccTotalAllocation) {
            _tcc.transferFrom(msg.sender, address(this), tccTotalAllocation - tccBal);
        }
        else if (tccBal > tccTotalAllocation) {
            _tcc.transfer(_tcc.adminWallet(), tccBal - tccTotalAllocation);
        }

        return _tc.balanceOf(address(this)) == tcTotalAllocation && _tcc.balanceOf(address(this)) == tccTotalAllocation;
    }

    function _claimERC20(address token) external returns (uint) {
        IFoundersVesting FoundersVesting = IFoundersVesting(address(this));
        if (FoundersVesting.someUSDHasBeenClaimed() && (token == address(USDC) || token == address(USDCe))) {
            revert("FOUNDERS | CLAIM: Only `adminWallet` can claim lost USDC or USDC.e");
        }
        IERC20 _token = IERC20(token);
        uint tokenBalance = _token.balanceOf(address(this)); // costs 3000 gas
        // bool adminClaim = msg.sender == adminWallet || msg.sender == tc.adminWallet() || msg.sender == tcc.adminWallet();

        // require(
        //     (
        //         token != address(tc)
        //         && token != address(tcc)
        //     ) || adminClaim,
        //     "FOUNDERS | CLAIM: Cannot claim internal tokens."
        // );

        uint tcRemaining = FoundersVesting.tcRemaining();
        uint tccRemaining = FoundersVesting.tccRemaining();

        if (token == address(tc())) {
            require(tokenBalance > tcRemaining, "FOUNDERS | CLAIM: No TC balance available to claim.");
            tokenBalance -= tcRemaining;
        }
        else if (token == address(tcc())) {
            require(tokenBalance > tccRemaining, "FOUNDERS | CLAIM: No TCC balance available to claim.");
            tokenBalance -= tccRemaining;
        }

        if (tokenBalance > 0) {
            _token.transfer(msg.sender, tokenBalance);
            return tokenBalance;
        }

        return 0;
    }

}