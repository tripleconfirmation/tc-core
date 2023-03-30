// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

abstract contract Baked {

    // ### EVENTS ###
    event AdminChange(address indexed from, address indexed to);
    event Frozen();




    // ### VIEW FUNCTIONS ###
    address public adminWallet;
    bool public contractIsFrozen;




    // ### AUTHORISATION FUNCTIONS ###
    modifier _adminAuth() virtual {
        require(msg.sender == adminWallet, "AUTH ERROR: Sender is not Admin Wallet.");
        _;
    }




    // ### SETTER FUNCTIONS ###
    // -> `adminWallet` only
    //    Set the `adminWallet`.
    //    Known in other smart contracts as the "Owner."
    function setAdminWallet(address newAdminWallet) external virtual _adminAuth {
        emit AdminChange(adminWallet, newAdminWallet);
        adminWallet = newAdminWallet;
    }

    /* -> `adminWallet` only
        If `contractIsFrozen` is set to false, all transfers are permitted.
        If `contractIsFrozen` is set to true, prevents all transfers except:
        • Users            -> `treasuryWallet`
        • `treasuryWallet` -> new `treasuryWallet`
        • `adminWallet`   -> new `adminWallet`

        Why?
        In the case of an exploit or desire to migrate, the `adminWallet` may
        want to ensure the security of all User tokens and consider potential
        mitigation solutions. In particular the `migrate()` function is explicitly
        permitted even when the `contractIsFrozen`. Despite all our best efforts,
        there will alway exist a non-zero possibility of an exploit being found.
        Having a mitigation strategy in place – such as secure and migrate – is wise.
    */
    function setContractIsFrozen(bool newContractIsFrozen) external _adminAuth {
        _setContractIsFrozen(newContractIsFrozen);
    }

    function _setContractIsFrozen(bool newContractIsFrozen) internal {
        contractIsFrozen = newContractIsFrozen;
        if (newContractIsFrozen) {
            emit Frozen();
        }
    }

}