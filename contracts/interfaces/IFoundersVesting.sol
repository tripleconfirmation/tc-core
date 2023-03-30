// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

import "./IBaked.sol";
import "./IERC20T.sol";
import "./IERC20.sol";

import "../libraries/FoundersVestingLib_structs.sol";

interface IFoundersVesting is IBaked {

    // ### EVENTS ###
    event Claimed(address indexed founder, uint tcAmount, uint tccAmount);
    event LostTokens(address indexed token, uint amount, address indexed receiver);
    event AddressChange(address indexed prev, address indexed current);
    event Extinguished(uint tcTotal, uint tccTotal);




	// ### VIEW FUNCTIONS ###
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
    //     uint timeStart;
    //     uint timeEnd;
    // }

    function version() external view returns (string memory version);
    
	function tc() external view returns (IERC20T tc);
	function tcc() external view returns (IERC20T tcc);
    function TC() external view returns (IERC20T TC);
    function TCC() external view returns (IERC20T TCC);
	function tcInfo() external view returns (FoundersVestingLib_structs.Token memory tcInfo);
	function tccInfo() external view returns (FoundersVestingLib_structs.Token memory tccInfo);
    function USDC() external view returns (IERC20 USDC);
    function USDCe() external view returns (IERC20 USDce);
    function usdcInfo() external view returns (FoundersVestingLib_structs.TokenUSD memory usdcInfo);
    function usdceInfo() external view returns (FoundersVestingLib_structs.TokenUSD memory usdceInfo);
    function totalUSDCRemaining() external view returns (uint totalUSDCRemaining);
    function totalUSDCeRemaining() external view returns (uint totalUSDCeRemaining);
	function founders(uint index) external view returns (FoundersVestingLib_structs.Founder memory founder);
	function tcTotalAllocation() external view returns (uint tcTotalAllocation);
	function tcPerFounder() external view returns (uint tcPerFounder);
	function tccTotalAllocation() external view returns (uint tccTotalAllocation);
	function tccPerFounder() external view returns (uint tccPerFounder);
    function claimingEnabled() external view returns (bool claimingEnabled);
	function timeEnd() external view returns (uint timeEnd);
	function timeDuration() external view returns (uint timeDuration);
    function pctTimeElapsed() external view returns (uint[2] memory pcts);
    function presale() external view returns (address presale);
    function someUSDHasBeenClaimed() external view returns (bool someUSDHasBeenClaimed);
	function funded() external view returns (bool funded);
	function tcTotalClaimed() external view returns (uint tcTotalClaimed);
	function tccTotalClaimed() external view returns (uint tccTotalClaimed);
	function tcRemaining() external view returns (uint tcRemaining);
	function tccRemaining() external view returns (uint tccRemaining);
	function founderIDs(address account) external view returns (uint founderID);
	function numFounders() external view returns (uint numFounders);




	// ### GETTER FUNCTIONS ###
	function getFoundersList() external view returns (FoundersVestingLib_structs.Founder[] memory founders);

    function getRawFoundersList() external view returns (FoundersVestingLib_structs.Founder[] memory founders);

	function getFounderID(uint founderID) external view returns (FoundersVestingLib_structs.Founder memory founder);

    function getRawFounderID(uint founderID) external view returns (FoundersVestingLib_structs.Founder memory founder);

	function getFounder(address account) external view returns (FoundersVestingLib_structs.Founder memory founder);




	// ### SETTER FUNCTIONS ###
	function setNewAddress(address newAddress) external;

    function notifyUSDFunding() external;




	// ### FUNDING FUNCTIONS ###
	function fund() external;

    struct Permit {
        address account;
        uint approveAmount;
        uint deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

	function fundWithPermit(FoundersVestingLib_structs.Permit calldata tcPermit, FoundersVestingLib_structs.Permit calldata tccPermit) external;




	// ### CLAIM FUNCTIONS ###
	function claimableAmounts(address founder) external view returns (uint tcClaimable, uint tccClaimable);

	function claimAll() external;

	function claim(uint amountTC, uint amountTCC) external;




	// ### MISC FUNCTIONS ###
	function claimERC20(address token) external;

	function selfDestruct() external;

}