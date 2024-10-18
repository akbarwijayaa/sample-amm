// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SimpleAMM.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Dummy token contract untuk testing
contract TestToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    // Fungsi untuk mint token ke address tertentu
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SimpleAMMTest is Test {
    SimpleAMM public amm;
    TestToken public token0;
    TestToken public token1;

    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        // Membuat dua token dummy
        token0 = new TestToken("Token0", "TK0");
        token1 = new TestToken("Token1", "TK1");

        // Membuat kontrak AMM
        amm = new SimpleAMM(IERC20(address(token0)), IERC20(address(token1)));

        // Membuat beberapa address untuk testing
        owner = address(this); // Pengguna ini adalah penguji
        user1 = address(0x1);
        user2 = address(0x2);

        // Mint token untuk user
        token0.mint(owner, 1000 ether);
        token1.mint(owner, 1000 ether);
        token0.mint(user1, 1000 ether);
        token1.mint(user1, 1000 ether);

        // Set allowance untuk AMM agar bisa mengakses token user
        token0.approve(address(amm), type(uint256).max);
        token1.approve(address(amm), type(uint256).max);
        vm.prank(user1); // Simulate user1 acting in the following line
        token0.approve(address(amm), type(uint256).max);
        vm.prank(user1); // Simulate user1 acting in the following line
        token1.approve(address(amm), type(uint256).max);
    }

    // Test untuk menambahkan likuiditas
    function testAddLiquidity() public {
        uint256 token0Amount = 100 ether;
        uint256 token1Amount = 100 ether;

        amm.addLiquidity(token0Amount, token1Amount);

        // Cek reserve apakah bertambah
        assertEq(amm.reserve0(), token0Amount);
        assertEq(amm.reserve1(), token1Amount);

        // Cek apakah likuiditas pengguna bertambah
        assertEq(amm.liquidity(owner), token0Amount + token1Amount);
    }

    // Test untuk menarik likuiditas
    function testRemoveLiquidity() public {
        uint256 token0Amount = 100 ether;
        uint256 token1Amount = 100 ether;

        // Tambah likuiditas terlebih dahulu
        amm.addLiquidity(token0Amount, token1Amount);

        // Cek likuiditas total
        uint256 totalLiquidity = amm.totalLiquidity();

        // Tarik semua likuiditas
        amm.removeLiquidity(totalLiquidity);

        // Cek reserve apakah kosong setelah ditarik
        assertEq(amm.reserve0(), 0);
        assertEq(amm.reserve1(), 0);

        // Cek likuiditas pengguna apakah sudah kembali 0
        assertEq(amm.liquidity(owner), 0);
    }

    // Test untuk swap token0 ke token1
    function testSwapToken0ToToken1() public {
        uint256 token0Amount = 100 ether;
        uint256 token1Amount = 100 ether;

        // Tambahkan likuiditas terlebih dahulu
        amm.addLiquidity(token0Amount, token1Amount);

        uint256 amountIn = 10 ether;

        // Swap token0 ke token1
        amm.swap(amountIn, true);

        // Cek apakah token0 reserve bertambah dan token1 berkurang
        assertEq(amm.reserve0(), token0Amount + amountIn);
        uint256 expectedAmountOut = amm.getAmountOut(amountIn, token0Amount, token1Amount);
        assertEq(amm.reserve1(), token1Amount - expectedAmountOut);
    }

    // Test untuk swap token1 ke token0
    function testSwapToken1ToToken0() public {
        uint256 token0Amount = 100 ether;
        uint256 token1Amount = 100 ether;

        // Tambah likuiditas terlebih dahulu
        amm.addLiquidity(token0Amount, token1Amount);

        uint256 amountIn = 10 ether;

        // Swap token1 ke token0
        amm.swap(amountIn, false);

        // Cek apakah token1 reserve bertambah dan token0 berkurang
        assertEq(amm.reserve1(), token1Amount + amountIn);
        uint256 expectedAmountOut = amm.getAmountOut(amountIn, token1Amount, token0Amount);
        assertEq(amm.reserve0(), token0Amount - expectedAmountOut);
    }
}
