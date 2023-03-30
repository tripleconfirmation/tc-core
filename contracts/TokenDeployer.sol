// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

// import "./libraries/TokenDeployerLib_deploy.sol";
import "./libraries/Caffeinated.sol";

import "./interfaces/IERC20T.sol";
import "./interfaces/IPresale.sol";
import "./interfaces/IFoundersVesting.sol";

// import "hardhat/console.sol";

contract TokenDeployer {

    event Funded(address indexed account, address indexed tc, address indexed tcc);
    event Remembered(address indexed account, address indexed tc, address indexed tcc);

    IERC20T public TC;
    IERC20T public TCC;

    bool public confirmFunded;
    bool public extinguished;
    string public constant error_extinguished = "TOKEN DEPLOYER | STATE: Contract has fulfilled its duty is now extinguished.";
    string public constant error_notExtinguished = "TOKEN DEPLOYER | STATE: Contract is still active. Try when `extinguished` == true.";

    address public delegate;
    address[] public teamWallets;
    address public adminWallet;
    address public presale;
    address public foundersVesting;

    address[] public teamWalletsTC = [0xAFE585f173Fd6130Fb181da58cB1A34E5c97Bd64, 0xFD0D496486f406c834B3f64e5159dc00CBC67e7d, 0x732A7415B0783bdbec16835D19FfD0F8E5EdCF40];
    uint[] public teamAmountsTC = [21300000000000, 21300000000000, 14200000000000];
    uint[] public teamAmountsTCC = [142069000000000, 142069000000000, 142069000000000];

	constructor(address _delegate) {
        adminWallet = msg.sender;

        teamWallets.push(0xC25f0B6BdBB2b3c9e8ef140585c664727B3B9D60);
        teamWallets.push(0xAFE585f173Fd6130Fb181da58cB1A34E5c97Bd64);
        teamWallets.push(0xFD0D496486f406c834B3f64e5159dc00CBC67e7d);
        teamWallets.push(0x732A7415B0783bdbec16835D19FfD0F8E5EdCF40);
        teamWallets.push(0xe524Ae868B899a9D3cf7259B2579afFD66c46823);
        teamWallets.push(0x005CE906e04A14a3dD485231FDabb23BA8DC0d6d);
        teamWallets.push(0xcd5C94654AFCbB599386D2503542F7F86eB344fe);
        teamWallets.push(0xE7a07B01ec5A855a5Dae67AA7Fc5303BA4400471);
        teamWallets.push(0xA1b6d0C954d73E66FF5Da179C8db45b65a0D006a);
        teamWallets.push(0x5E0B570Ed4c0e1a7b238e4b3029c4BB0b6D53f32);
        teamWallets.push(0xFb0F7EAf3b67587D0dE73374154A6c8380D07930);
        teamWallets.push(0xC250CC98593Ed7bAb1c750B2F741B64651db3640);

        if (_delegate == msg.sender) {
            delegate = msg.sender;
        }
        else {
            delegate = teamWallets[0];
        }
    }




    // ### AUTHORISATION FUNCTIONS ###
    modifier _adminAuth() {
        require(msg.sender == adminWallet, "AUTH ERROR: Sender must be the Admin Wallet.");
        _;
    }

    function _verifyTC(address _contract) private view returns (bool) {
        return address(TC) == address(IPresale(_contract).TC());
    }

    function _verifyTCBal() private view returns (bool) {
        return 
            _verifyTC(presale)
            && _verifyTC(foundersVesting)
            && presale != address(0)
            && foundersVesting != address(0)
            && TC.balanceOf(presale) >= IPresale(presale).requiredTC()
            && IPresale(presale).requiredTC() > 0
            && TCC.balanceOf(presale) >= IPresale(presale).requiredTCC()
            && IPresale(presale).requiredTCC() > 0
            && TC.balanceOf(foundersVesting) >= IFoundersVesting(foundersVesting).tcTotalAllocation()
            && IFoundersVesting(foundersVesting).tcTotalAllocation() > 0
            && TCC.balanceOf(foundersVesting) >= IFoundersVesting(foundersVesting).tccTotalAllocation()
            && IFoundersVesting(foundersVesting).tccTotalAllocation() > 0;
    }




    // ### GETTER FUNCTIONS ###
    function getTeamWallets() external view returns (address[] memory) {
        return teamWallets;
    }




    // ### SETTER FUNCTIONS ###
    function setPresale(address _presale) external _adminAuth {
        require(!extinguished, error_extinguished);
        presale = _presale;

        require(
            _verifyTC(presale),
            "DEPLOYER | SET: The TC token on the Presale contract does not match the one I deployed."
        );

        TC.transfer(presale, IPresale(presale).requiredTC() - TC.balanceOf(presale));
        TCC.transfer(presale, IPresale(presale).requiredTCC() - TCC.balanceOf(presale));
    }

    function setFoundersVesting(address _foundersVesting) external _adminAuth {
        require(!extinguished, error_extinguished);
        foundersVesting = _foundersVesting;

        require(
            _verifyTC(foundersVesting),
            "DEPLOYER | SET: The TC token on the FoundersVesting contract does not match the one I deployed."
        );

        TC.transfer(foundersVesting, IFoundersVesting(foundersVesting).tcTotalAllocation() - TC.balanceOf(foundersVesting));
        TCC.transfer(foundersVesting, IFoundersVesting(foundersVesting).tccTotalAllocation() - TCC.balanceOf(foundersVesting));
    }




    // ### DEPLOYMENT FUNCTIONS ###
    function rememberTokens(address _tc, address _tcc) public _adminAuth {
        require(!extinguished, error_extinguished);
        bool didSomething;

        if (address(TC) == address(0)) {
            TC = IERC20T(_tc);
            // TC = IERC20T(TokenDeployerLib_deploy._deployTokenBase("Prototype Token A v2", "PTav2", 142000000, teamWallets));
            // TC.transfer(adminWallet, 110000000 * 10 ** TC.decimals()); // REMOVE AFTER TESTING
            TC.multiTransfer(teamWalletsTC, teamAmountsTC);

            // Already being transferred in Presale
            // for (uint i; i < teamWalletsTC.length; ++i) {
            //     TC.transfer(teamWalletsTC[i], teamAmountsTC[i]);
            // }

            didSomething = true;
        }

        if (address(TCC) == address(0)) {
            TCC = IERC20T(_tcc);
            // TCC = IERC20T(TokenDeployerLib_deploy._deployTokenBase("Prototype Token B v2", "PTbv2", 1420690000, teamWallets));
            // TCC.transfer(adminWallet, 150000000 * 10 ** TC.decimals()); // REMOVE AFTER TESTING
            TCC.multiTransfer(teamWalletsTC, teamAmountsTCC);

            didSomething = true;
        }

        if (didSomething) {
            emit Remembered(msg.sender, address(TC), address(TCC));
        }
    }

	function confirmPresaleFunding(address _tc, address _tcc) external _adminAuth {
        require(!extinguished, error_extinguished);
        if (confirmFunded) {
            return;
        }

        rememberTokens(_tc, _tcc);

        if (_verifyTCBal()) {
            TC.setAdminWallet(delegate);
            TC.transfer(TC.treasuryWallet(), TC.balanceOf(address(this)));

            TCC.setAdminWallet(delegate);
            TCC.transfer(TCC.treasuryWallet(), TCC.balanceOf(address(this)));
            
            confirmFunded = true;
            emit Funded(msg.sender, address(TC), address(TCC));
        }
	}

	// function disburseTCC(address[] calldata recipientsTCC, uint[] calldata amountsTCC) external _adminAuth {
    //     if (deployedTCC) {
    //         return;
    //     }

    //     uint _currentRecipientTCC = currentRecipientTCC;
    //     uint _total = disbursedTotalTCC;

    //     for (; _currentRecipientTCC < recipientsTCC.length; ++_currentRecipientTCC) {
    //         if (gasleft() < 200000) {
    //             currentRecipientTCC = _currentRecipientTCC;
    //             disbursedTotalTCC = _total;
    //             return;
    //         }

    //         TCC.transfer(recipientsTCC[_currentRecipientTCC], amountsTCC[_currentRecipientTCC]);
    //         _total += amountsTCC[_currentRecipientTCC];
    //     }

    //     currentRecipientTCC = _currentRecipientTCC;
    //     disbursedTotalTCC = _total;

    //     if (currentRecipientTCC >= recipientsTCC.length && presale != address(0) && _verifyTCBal()) {
    //         TCC.setAdminWallet(teamWallets[0]);
    //         TCC.transfer(TCC.treasuryWallet(), TCC.balanceOf(address(this)));
    //         deployedTCC = true;
    //         emit CompleteTC(msg.sender, address(TCC));
    //     }
	// }




    // ### SELF DESTRUCT FUNCTIONS ###
    function selfDestruct() external _adminAuth {
        require(
            _verifyTCBal(),
            "DEPLOYER | SELF-DESTRUCT: Presale TC token does not match the one I deployed."
        );

        if (!confirmFunded || presale == address(0) || foundersVesting == address(0)) {
            return;
        }

        TC.transfer(teamWallets[0], TC.balanceOf(address(this)));
        TCC.transfer(teamWallets[0], TCC.balanceOf(address(this)));

        extinguished = true;
        claimToken(address(0));
        
        // TokenDeployerLib_deploy._selfDestruct(teamWallets[0]);
        // selfdestruct(payable(teamWallets[0]));
    }

    function claimToken(address _token) public {
        require(extinguished, error_notExtinguished);
        address _treasuryWallet = teamWallets[0]; // TC.treasuryWallet();

        if (_token != address(0)) {
            IERC20T token = IERC20T(_token);
            token.transfer(_treasuryWallet, token.balanceOf(address(this)));
        }

        if (address(this).balance == 0) { return; }
        (
            bool _success,
            // bytes
        ) = payable(_treasuryWallet).call{value: address(this).balance}("");
        require(_success, "TOKEN DEPLOYER | SEND AVAX: Sending failed.");
    }

}
