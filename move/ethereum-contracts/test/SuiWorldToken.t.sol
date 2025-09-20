// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/SuiWorldToken.sol";

contract SuiWorldTokenTest is Test {
    SuiWorldToken public token;

    address public owner = address(1);
    address public nttManager = address(2);
    address public user1 = address(3);
    address public user2 = address(4);

    uint256 constant INITIAL_SUPPLY = 100_000_000 * 10 ** 6; // 100M with 6 decimals
    uint16 constant SUI_CHAIN_ID = 21;
    uint16 constant SEPOLIA_CHAIN_ID = 10002;

    event NTTManagerSet(address indexed oldManager, address indexed newManager);
    event TokensLocked(
        address indexed from,
        uint256 amount,
        uint16 destinationChain
    );
    event TokensUnlocked(
        address indexed to,
        uint256 amount,
        uint16 sourceChain
    );
    event TokensBurnedForTransfer(
        address indexed from,
        uint256 amount,
        uint16 destinationChain
    );
    event TokensMintedFromTransfer(
        address indexed to,
        uint256 amount,
        uint16 sourceChain
    );

    function setUp() public {
        vm.prank(owner);
        token = new SuiWorldToken();
    }

    // ============ Basic Token Tests ============

    function testInitialSetup() public {
        assertEq(token.name(), "SuiWorld Token");
        assertEq(token.symbol(), "SWT");
        assertEq(token.decimals(), 6);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
        assertEq(token.owner(), owner);
    }

    function testTransfer() public {
        uint256 amount = 1000 * 10 ** 6;

        vm.prank(owner);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
    }

    function testBurn() public {
        uint256 burnAmount = 1000 * 10 ** 6;

        vm.prank(owner);
        token.burn(burnAmount);

        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - burnAmount);
    }

    // ============ NTT Manager Tests ============

    function testSetNTTManager() public {
        vm.expectEmit(true, true, false, true);
        emit NTTManagerSet(address(0), nttManager);

        vm.prank(owner);
        token.setNTTManager(nttManager);

        assertEq(token.nttManager(), nttManager);
    }

    function testSetNTTManagerUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        token.setNTTManager(nttManager);
    }

    function testSetNTTManagerZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid address");
        token.setNTTManager(address(0));
    }

    // ============ Lock/Unlock Tests (Hub-and-Spoke) ============

    function testLockForTransfer() public {
        uint256 amount = 1000 * 10 ** 6;

        // Setup
        vm.prank(owner);
        token.setNTTManager(nttManager);

        vm.prank(owner);
        token.transfer(user1, amount);

        // User approves NTT Manager
        vm.prank(user1);
        token.approve(address(token), amount);

        // NTT Manager locks tokens
        vm.expectEmit(true, false, false, true);
        emit TokensLocked(user1, amount, SUI_CHAIN_ID);

        vm.prank(nttManager);
        bool success = token.lockForTransfer(user1, amount, SUI_CHAIN_ID);

        assertTrue(success);
        assertEq(token.totalLocked(), amount);
        assertEq(token.balanceOf(address(token)), amount);
        assertEq(token.balanceOf(user1), 0);
    }

    function testUnlockFromTransfer() public {
        uint256 amount = 1000 * 10 ** 6;

        // Setup: First lock tokens
        vm.prank(owner);
        token.setNTTManager(nttManager);

        vm.prank(owner);
        token.transfer(user1, amount);

        vm.prank(user1);
        token.approve(address(token), amount);

        vm.prank(nttManager);
        token.lockForTransfer(user1, amount, SUI_CHAIN_ID);

        // Now unlock to user2
        vm.expectEmit(true, false, false, true);
        emit TokensUnlocked(user2, amount, SUI_CHAIN_ID);

        vm.prank(nttManager);
        bool success = token.unlockFromTransfer(user2, amount, SUI_CHAIN_ID);

        assertTrue(success);
        assertEq(token.totalLocked(), 0);
        assertEq(token.balanceOf(user2), amount);
        assertEq(token.balanceOf(address(token)), 0);
    }

    function testUnlockInsufficientLocked() public {
        vm.prank(owner);
        token.setNTTManager(nttManager);

        vm.prank(nttManager);
        vm.expectRevert("Insufficient locked balance");
        token.unlockFromTransfer(user1, 1000, SUI_CHAIN_ID);
    }

    // ============ Burn/Mint Tests (Burn-and-Mint) ============

    function testBurnForTransfer() public {
        uint256 amount = 1000 * 10 ** 6;

        // Setup
        vm.prank(owner);
        token.setNTTManager(nttManager);

        vm.prank(owner);
        token.transfer(user1, amount);

        // NTT Manager burns tokens
        vm.expectEmit(true, false, false, true);
        emit TokensBurnedForTransfer(user1, amount, SUI_CHAIN_ID);

        vm.prank(nttManager);
        bool success = token.burnForTransfer(user1, amount, SUI_CHAIN_ID);

        assertTrue(success);
        assertEq(token.totalBurned(), amount);
        assertEq(token.balanceOf(user1), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function testMintFromTransfer() public {
        uint256 amount = 1000 * 10 ** 6;

        // Setup
        vm.prank(owner);
        token.setNTTManager(nttManager);

        // NTT Manager mints tokens
        vm.expectEmit(true, false, false, true);
        emit TokensMintedFromTransfer(user1, amount, SUI_CHAIN_ID);

        vm.prank(nttManager);
        bool success = token.mintFromTransfer(user1, amount, SUI_CHAIN_ID);

        assertTrue(success);
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }

    // ============ Pause Tests ============

    function testPause() public {
        vm.prank(owner);
        token.pause();

        assertTrue(token.paused());

        // Transfer should fail when paused
        vm.prank(owner);
        vm.expectRevert();
        token.transfer(user1, 1000);
    }

    function testUnpause() public {
        vm.prank(owner);
        token.pause();

        vm.prank(owner);
        token.unpause();

        assertFalse(token.paused());

        // Transfer should work after unpause
        vm.prank(owner);
        token.transfer(user1, 1000);
        assertEq(token.balanceOf(user1), 1000);
    }

    // ============ Admin Functions Tests ============

    function testMintByOwner() public {
        uint256 amount = 1000 * 10 ** 6;

        vm.prank(owner);
        token.mint(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY + amount);
    }

    function testMintUnauthorized() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, 1000);
    }

    // ============ View Functions Tests ============

    function testCirculatingSupply() public {
        uint256 amount = 1000 * 10 ** 6;

        // Lock some tokens
        vm.prank(owner);
        token.setNTTManager(nttManager);

        vm.prank(owner);
        token.transfer(address(token), amount);

        assertEq(token.circulatingSupply(), INITIAL_SUPPLY - amount);
    }

    function testGetTokenStats() public {
        uint256 lockAmount = 1000 * 10 ** 6;
        uint256 burnAmount = 500 * 10 ** 6;

        // Setup
        vm.prank(owner);
        token.setNTTManager(nttManager);

        // Lock tokens
        vm.prank(owner);
        token.transfer(user1, lockAmount);
        vm.prank(user1);
        token.approve(address(token), lockAmount);
        vm.prank(nttManager);
        token.lockForTransfer(user1, lockAmount, SUI_CHAIN_ID);

        // Burn tokens
        vm.prank(owner);
        token.transfer(user2, burnAmount);
        vm.prank(nttManager);
        token.burnForTransfer(user2, burnAmount, SUI_CHAIN_ID);

        (
            uint256 totalSupply,
            uint256 totalLocked,
            uint256 totalBurned,
            uint256 circulatingSupply
        ) = token.getTokenStats();

        assertEq(totalSupply, INITIAL_SUPPLY - burnAmount);
        assertEq(totalLocked, lockAmount);
        assertEq(totalBurned, burnAmount);
        assertEq(circulatingSupply, INITIAL_SUPPLY - burnAmount - lockAmount);
    }

    // ============ Fuzz Tests ============

    function testFuzzTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(to != address(token));
        vm.assume(amount <= INITIAL_SUPPLY);

        vm.prank(owner);
        token.transfer(to, amount);

        assertEq(token.balanceOf(to), amount);
        assertEq(token.balanceOf(owner), INITIAL_SUPPLY - amount);
    }

    function testFuzzLockUnlock(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= INITIAL_SUPPLY);

        // Setup
        vm.prank(owner);
        token.setNTTManager(nttManager);

        vm.prank(owner);
        token.transfer(user1, amount);

        vm.prank(user1);
        token.approve(address(token), amount);

        // Lock
        vm.prank(nttManager);
        token.lockForTransfer(user1, amount, SUI_CHAIN_ID);

        assertEq(token.totalLocked(), amount);

        // Unlock
        vm.prank(nttManager);
        token.unlockFromTransfer(user2, amount, SUI_CHAIN_ID);

        assertEq(token.totalLocked(), 0);
        assertEq(token.balanceOf(user2), amount);
    }
}
