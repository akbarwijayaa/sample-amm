// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleAMM {
    IERC20 public token0; // Token pertama
    IERC20 public token1; // Token kedua
    uint256 public reserve0; // Jumlah token pertama di pool
    uint256 public reserve1; // Jumlah token kedua di pool
    uint256 public totalLiquidity; // Total likuiditas dalam pool
    mapping(address => uint256) public liquidity; // Likuiditas per pengguna

    event LiquidityAdded(address indexed provider, uint256 token0Amount, uint256 token1Amount);
    event LiquidityRemoved(address indexed provider, uint256 token0Amount, uint256 token1Amount);
    event Swapped(address indexed trader, uint256 amountIn, uint256 amountOut, bool isToken0ToToken1);

    constructor(IERC20 _token0, IERC20 _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    // Fungsi untuk menambahkan likuiditas
    function addLiquidity(uint256 amount0, uint256 amount1) external {
        require(amount0 > 0 && amount1 > 0, "Invalid amount");

        // Transfer token dari pengguna ke kontrak
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        // Update reserve dan likuiditas pengguna
        reserve0 += amount0;
        reserve1 += amount1;
        uint256 liquidityMinted = amount0 + amount1; // Sederhana: total likuiditas adalah jumlah token
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;

        emit LiquidityAdded(msg.sender, amount0, amount1);
    }

    // Fungsi untuk menarik likuiditas
    function removeLiquidity(uint256 liquidityAmount) external {
        require(liquidity[msg.sender] >= liquidityAmount, "Not enough liquidity");

        uint256 token0Amount = (liquidityAmount * reserve0) / totalLiquidity;
        uint256 token1Amount = (liquidityAmount * reserve1) / totalLiquidity;

        reserve0 -= token0Amount;
        reserve1 -= token1Amount;
        liquidity[msg.sender] -= liquidityAmount;
        totalLiquidity -= liquidityAmount;

        // Transfer token kembali ke pengguna
        token0.transfer(msg.sender, token0Amount);
        token1.transfer(msg.sender, token1Amount);

        emit LiquidityRemoved(msg.sender, token0Amount, token1Amount);
    }

    // Fungsi untuk melakukan swap antara token0 dan token1
    function swap(uint256 amountIn, bool isToken0ToToken1) external {
        require(amountIn > 0, "Amount must be greater than zero");

        if (isToken0ToToken1) {
            // Swap dari token0 ke token1
            uint256 amountOut = getAmountOut(amountIn, reserve0, reserve1);
            token0.transferFrom(msg.sender, address(this), amountIn);
            token1.transfer(msg.sender, amountOut);
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            // Swap dari token1 ke token0
            uint256 amountOut = getAmountOut(amountIn, reserve1, reserve0);
            token1.transferFrom(msg.sender, address(this), amountIn);
            token0.transfer(msg.sender, amountOut);
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        emit Swapped(msg.sender, amountIn, amountOut, isToken0ToToken1);
    }

    // Fungsi untuk menghitung jumlah token yang keluar berdasarkan constant product formula
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        // Constant Product Formula: (x + dx) * (y - dy) = x * y => dy = (y * dx) / (x + dx)
        uint256 amountInWithFee = amountIn * 997; // Mengurangi 0.3% fee (997/1000)
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }
}
