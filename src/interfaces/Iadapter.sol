// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILendleAdapter {
    /// @notice Supply `amount` of `asset` on behalf of `onBehalfOf`.
    /// @dev referralCode optional; return value is amount actually deposited (protocol-dependent).
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external returns (uint256);

    /// @notice Borrow `amount` of `asset` for `onBehalfOf`.
    /// @param interestRateMode 1 = stable, 2 = variable (documented convention)
    /// @param referralCode optional referral
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external returns (uint256);

    /// @notice Repay up to `amount` of `asset` on behalf of `onBehalfOf`.
    /// @param rateMode 1 = stable, 2 = variable
    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);

    /// @notice Withdraw up to `amount` of `asset` to `to`. 
    /// @return withdrawn actual withdrawn amount
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /* --- Helpful view getters for integrations (recommended) --- */

    /// @notice Get user account data like totalCollateral, totalDebt, availableBorrows, healthFactor
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );

    /// @notice Get reserve/market data for asset (liquidity, LTV, liquidation penalty, etc)
    function getReserveData(address asset) external view returns (
        uint256 availableLiquidity,
        uint256 totalStableDebt,
        uint256 totalVariableDebt,
        uint256 liquidityRate,
        uint256 variableBorrowRate,
        uint256 stableBorrowRate,
        uint256 ltv,
        uint256 liquidationThreshold,
        uint256 liquidationBonus
    );
}
