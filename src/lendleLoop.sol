// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {ILendlePool} from "./interfaces/IPool.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface ILendleOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

interface ProtocolDataProvider {
    function getUserReserveData(address asset, address user) external view returns (
        uint256 currentATokenBalance,
        uint256 currentStableDebt,
        uint256 currentVariableDebt,
        uint256 principalStableDebt,
        uint256 scaledVariableDebt,
        uint256 stableBorrowRate,
        uint256 liquidityRate,
        uint40 stableRateLastUpdated,
        bool usageAsCollateralEnabled
    );
}


contract LendleLoop is ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20; 

    ILendlePool public immutable LENDING_POOL; // pool address 
    ILendleOracle public immutable ORACLE; // oracle address
    ProtocolDataProvider public immutable DATA_PROVIDER; // data provider address
    uint256 public constant SAFE_BUFFER = 10;

    constructor(address _lendingPool, address _oracle, address _dataProvider) Ownable(msg.sender) {
        LENDING_POOL = ILendlePool(_lendingPool);
        ORACLE = ILendleOracle(_oracle);
        DATA_PROVIDER = ProtocolDataProvider(_dataProvider);
    }

    function getAssetPrice(address asset) public view returns (uint256) {
        return ORACLE.getAssetPrice(asset);
    }

    function getPositionData() public view returns(
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    ) {
        return LENDING_POOL.getUserAccountData(address(this)); 
    }

    function getBorrowBalance(address asset) public view returns (uint256) {
        (, uint256 totalDebtETH, , , , ) = getPositionData();
        return (totalDebtETH * (10**6)) / getAssetPrice(asset); 
    }

    function getLiquidity(address asset) public view returns (uint256) {
        (, , uint256 availableBorrowsETH, , , ) = getPositionData();
        return (availableBorrowsETH * (10**6)) / getAssetPrice(asset);
    }

    function getAssetBalance(address asset) public view returns (uint256) {
        return IERC20(asset).balanceOf(address(this)); 
    }


    // owner needs to approve this contract to transfer the asset before calling startLoop
    function allowToUseAsCollateral(address asset) external onlyOwner {
        LENDING_POOL.setUserUseReserveAsCollateral(asset, true); 
    }

    function _deposit(address asset, uint256 amount) internal {
        IERC20(asset).safeIncreaseAllowance(address(LENDING_POOL), amount);
        LENDING_POOL.deposit(asset, amount, address(this), 0);
    }

    function _borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) internal {
        LENDING_POOL.borrow(asset, amount, interestRateMode, referralCode, onBehalfOf);
    }

    function _redeemSupply(address asset, uint256 amount) internal {
        LENDING_POOL.withdraw(asset, amount, address(this)); 
    }

    function _repayBorrow(address asset, uint256 amount, uint256 interestRateMode) internal {
        IERC20(asset).safeIncreaseAllowance(address(LENDING_POOL), amount);
        LENDING_POOL.repay(asset, amount, interestRateMode, address(this));
    }

    function _withdrawToOwner(address asset) public onlyOwner returns (uint256) {
        uint256 balance = ERC20(asset).balanceOf(address(this));
        ERC20(asset).transfer(msg.sender, balance);
        return balance;
    }

    function startLoop(
    address asset, 
    uint256 initialCollateral, 
    uint256 loops, 
    uint256 interestRateMode
    ) external nonReentrant returns(uint256) {  
        require(loops > 0 && loops < 10, "loops should be between 1 and 10");

        IERC20(asset).safeTransferFrom(msg.sender, address(this), initialCollateral);

        _deposit(asset, initialCollateral);

        // loop 
        for (uint256 i = 0; i < loops; i++) {
            _borrow(asset, getLiquidity(asset) - SAFE_BUFFER, interestRateMode, 0, msg.sender);
            _deposit(asset, getAssetBalance(asset)); 
        }

        return getLiquidity(asset);           
    }

    function exitPosition(address asset, uint256 loops) external nonReentrant returns(uint256) {
        (, , , , uint256 ltv, ) = getPositionData(); 

        for (uint256 i = 0; i < loops && getBorrowBalance(asset) > 0; i++) {
            _redeemSupply(asset, ((getLiquidity(asset) * 1e4) / ltv) - SAFE_BUFFER);
            _repayBorrow(asset, getBorrowBalance(asset), 2);
        }


        if (getBorrowBalance(asset) == 0) {
            _redeemSupply(asset, type(uint256).max);
        }

        return _withdrawToOwner(asset);
    }


}



