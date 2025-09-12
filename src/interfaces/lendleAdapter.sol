// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILendleAdapter} from "../interfaces/Iadapter.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IERC20Decimals is IERC20 {
    function decimals() external view returns (uint8);
}

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract LendleAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20Decimals;

    ILendleAdapter public immutable pool;
    IAaveOracle public immutable oracle;

    uint256 public constant INTEREST_RATE_MODE = 2;
    uint16 public constant REFERRAL_CODE = 0;

    uint8 public constant MAX_LOOPS = 10;
    uint256 public constant MIN_AVAILABLE_BASE = 1e6;

    constructor(address _pool, address _oracle) {
        pool = ILendleAdapter(_pool);
        oracle = IAaveOracle(_oracle);
    }

    function startLoop(address asset, uint256 initialAmount, uint256 loops) external nonReentrant {
        require(loops <= MAX_LOOPS, "Too many loops");
        require(initialAmount > 0, "Amount must be > 0");

        IERC20Decimals token = IERC20Decimals(asset);

        // pull funds from caller
        token.safeTransferFrom(msg.sender, address(this), initialAmount);

        // approve pool
        token.safeIncreaseAllowance(address(pool), initialAmount);

        // deposit initial amount
        pool.deposit(asset, initialAmount, address(this), REFERRAL_CODE);

        // get available borrows (base currency)
        (,, uint256 availableBorrowsBase,,,) = pool.getUserAccountData(address(this));

        uint256 i = 0;
        while (i < loops && availableBorrowsBase >= MIN_AVAILABLE_BASE) {
            // get the price (in base units)
            uint256 price = oracle.getAssetPrice(asset);
            require(price > 0, "Price is 0");

            uint8 decimals = token.decimals();
            uint256 assetsDecimalFactor = 10 ** uint256(decimals);

            // convert available borrows (base) to asset units
            uint256 toBorrow = (availableBorrowsBase * assetsDecimalFactor) / price;

            // borrow at most 95% of toBorrow
            uint256 safeBorrow = (toBorrow * 95) / 100;
            if (safeBorrow == 0) break;

            // borrow and immediately deposit back
            pool.borrow(asset, safeBorrow, INTEREST_RATE_MODE, REFERRAL_CODE, address(this));

            // approve the pool to pull the borrowed tokens
            token.safeIncreaseAllowance(address(pool), safeBorrow);
            pool.deposit(asset, safeBorrow, address(this), REFERRAL_CODE);

            (,, availableBorrowsBase,,,) = pool.getUserAccountData(address(this));
            i++;
        }
    }

    function unwind(address asset) external nonReentrant {
        IERC20Decimals token = IERC20Decimals(asset);

        // check debt owed
        (uint256 totalCollateralBase, uint256 totalDebtBase, , , , uint256 hf) = pool.getUserAccountData(address(this));

        require(totalDebtBase > 0 || totalCollateralBase > 0, "nothing to unwind");

        uint256 price = oracle.getAssetPrice(asset);
        require(price > 0, "Oracle price is 0");
        uint8 decimals = token.decimals();

        uint256 assetDecimalFactor = 10 ** uint256(decimals);

        // debtAsset = totalDebtBase * assetDecimalFactor / price
        uint256 debtAssetAmount = (totalDebtBase * assetDecimalFactor) / price;

        // withdraw exactly the amount needed to repay debt (may return actual withdrawn)
        uint256 withdrawn = pool.withdraw(asset, debtAssetAmount, address(this));

        if (withdrawn > 0) {
            token.safeIncreaseAllowance(address(pool), withdrawn);
            pool.repay(asset, withdrawn, INTEREST_RATE_MODE, address(this));
        }

        // after repaying, withdraw all remaining supplied assets back
        uint256 remaining = pool.withdraw(asset, type(uint256).max, address(this));

        uint256 leftover = token.balanceOf(address(this));
        if (leftover > 0) {
            token.safeTransfer(msg.sender, leftover);
        }
    }
}
