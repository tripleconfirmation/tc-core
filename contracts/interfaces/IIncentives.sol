// SPDX-License-Identifier: BUSL-1.1
// File from: @AAVE/aave-v3-core
pragma solidity ^0.8.19;

/**
 * @title IIncentives
 * @author Aave
 * @notice Defines the basic interface for a Rewards Controller.
 */
interface IIncentives {

  /**
   * @dev Claims all rewards for a user to the desired address, on all the assets of the pool, accumulating the pending rewards
   * @param assets The list of assets to check eligible distributions before claiming rewards
   * @param to The address that will be receiving the rewards
   * @return rewardsList List of addresses of the reward tokens
   * @return claimedAmounts List that contains the claimed amount per reward, following same order as "rewardList"
   **/
  function claimAllRewards(address[] calldata assets, address to) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
  // function claimAllRewards(address[] memory assets, address to) external returns (address[] memory rewardsList, uint256[] memory claimedAmounts);

}