// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILendlePool {

    function borrow(
    address asset, 
    uint256 amount, 
    uint256 interestRateMode,
    uint16 referralCode, 
    address onBehalfOf
    ) external;

    function deposit(
     address asset, 
     uint256 amount, 
     address onBehalfOf, 
     uint16 referralCode
    ) external; 

    function withdraw(
        address asset, 
        uint256 amount, 
        address to
    ) external;

    function repay(
        address asset, 
        uint256 amount, 
        uint256 interestRateMode, 
        address onBehalfOf
    ) external; 

    function setUserUseReserveAsCollateral(
        address asset, 
        bool useAsCollateral
    ) external; 


    function getUserAccountData(
        address user
    ) external view returns (
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ); 
    
}