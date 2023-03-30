// SPDX-License-Identifier: BUSL-1.1
// File from: @AAVE/aave-v3-core
pragma solidity ^0.8.19;

/************
@title IPriceOracle interface
@notice Interface for the Aave price oracle.*/
interface IPriceOracle {
    /***********
    @dev returns the asset price in ETH
     */
    function getAssetPrice(address _asset) external view returns (uint256);
    
}