// SPDX-License-Identifier: WTFPL

pragma solidity ^0.8.19;

interface IBaked {

	// ### EVENTS ###
	event AdminChange(address indexed from, address indexed to);
    event Frozen();




	// ### VIEW FUNCTIONS ###
	function adminWallet() external view returns (address adminWallet);
	function contractIsFrozen() external view returns (bool contractIsFrozen);




	// ### SETTER FUNCTIONS ###
    function setAdminWallet(address newAdminWallet) external; // Only `adminWallet` can exec.

    function setContractIsFrozen(bool newContractIsFrozen) external; // Only `adminWallet` can exec.

}