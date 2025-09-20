// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title SuiWorldToken
 * @dev NTT-compatible ERC20 token for cross-chain transfers with Wormhole
 */
contract SuiWorldToken is ERC20, ERC20Burnable, ERC20Permit, Ownable, Pausable {
    // Custom decimals (matching Sui token)
    uint8 private constant _DECIMALS = 6;

    // Total supply: 100M tokens
    uint256 private constant _INITIAL_SUPPLY = 100_000_000 * 10**_DECIMALS;

    // NTT Manager address (set after NTT deployment)
    address public nttManager;

    // Track cross-chain statistics
    uint256 public totalLocked;
    uint256 public totalBurned;

    // Events for NTT compatibility
    event NTTManagerSet(address indexed oldManager, address indexed newManager);
    event TokensLocked(address indexed from, uint256 amount, uint16 destinationChain);
    event TokensUnlocked(address indexed to, uint256 amount, uint16 sourceChain);
    event TokensBurnedForTransfer(address indexed from, uint256 amount, uint16 destinationChain);
    event TokensMintedFromTransfer(address indexed to, uint256 amount, uint16 sourceChain);

    // Modifiers
    modifier onlyNTTManager() {
        require(msg.sender == nttManager, "Only NTT Manager can call");
        _;
    }

    modifier onlyOwnerOrNTTManager() {
        require(msg.sender == owner() || msg.sender == nttManager, "Unauthorized");
        _;
    }

    constructor()
        ERC20("SuiWorld Token", "SWT")
        ERC20Permit("SuiWorld Token")
        Ownable(msg.sender)
    {
        // Mint initial supply to deployer
        _mint(msg.sender, _INITIAL_SUPPLY);
    }

    /**
     * @dev Returns the number of decimals used for token
     */
    function decimals() public pure override returns (uint8) {
        return _DECIMALS;
    }

    /**
     * @dev Set the NTT Manager address (one-time setup after NTT deployment)
     * @param _nttManager Address of the NTT Manager contract
     */
    function setNTTManager(address _nttManager) external onlyOwner {
        require(_nttManager != address(0), "Invalid address");
        address oldManager = nttManager;
        nttManager = _nttManager;
        emit NTTManagerSet(oldManager, _nttManager);
    }

    // ============ NTT Functions for Cross-Chain Operations ============

    /**
     * @dev Lock tokens for hub-and-spoke mode (called by NTT Manager)
     * @param from Address to lock tokens from
     * @param amount Amount of tokens to lock
     * @param destinationChain Wormhole chain ID of destination
     */
    function lockForTransfer(
        address from,
        uint256 amount,
        uint16 destinationChain
    ) external onlyNTTManager whenNotPaused returns (bool) {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer tokens from user to this contract
        _transfer(from, address(this), amount);

        totalLocked += amount;

        emit TokensLocked(from, amount, destinationChain);
        return true;
    }

    /**
     * @dev Unlock tokens for hub-and-spoke mode (called by NTT Manager)
     * @param to Address to unlock tokens to
     * @param amount Amount of tokens to unlock
     * @param sourceChain Wormhole chain ID of source
     */
    function unlockFromTransfer(
        address to,
        uint256 amount,
        uint16 sourceChain
    ) external onlyNTTManager whenNotPaused returns (bool) {
        require(amount > 0, "Amount must be greater than 0");
        require(totalLocked >= amount, "Insufficient locked balance");

        totalLocked -= amount;

        // Transfer tokens from contract to recipient
        _transfer(address(this), to, amount);

        emit TokensUnlocked(to, amount, sourceChain);
        return true;
    }

    /**
     * @dev Burn tokens for burn-and-mint mode (called by NTT Manager)
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     * @param destinationChain Wormhole chain ID of destination
     */
    function burnForTransfer(
        address from,
        uint256 amount,
        uint16 destinationChain
    ) external onlyNTTManager whenNotPaused returns (bool) {
        require(amount > 0, "Amount must be greater than 0");

        // Burn tokens from user
        _burn(from, amount);

        totalBurned += amount;

        emit TokensBurnedForTransfer(from, amount, destinationChain);
        return true;
    }

    /**
     * @dev Mint tokens from cross-chain transfer (called by NTT Manager)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     * @param sourceChain Wormhole chain ID of source
     */
    function mintFromTransfer(
        address to,
        uint256 amount,
        uint16 sourceChain
    ) external onlyNTTManager whenNotPaused returns (bool) {
        require(amount > 0, "Amount must be greater than 0");

        // Mint new tokens to recipient
        _mint(to, amount);

        if (totalBurned >= amount) {
            totalBurned -= amount;
        }

        emit TokensMintedFromTransfer(to, amount, sourceChain);
        return true;
    }

    // ============ Admin Functions ============

    /**
     * @dev Mint new tokens (owner only, for liquidity provision)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Pause token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ View Functions ============

    /**
     * @dev Get current circulating supply
     */
    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(address(this));
    }

    /**
     * @dev Get token statistics
     */
    function getTokenStats() external view returns (
        uint256 _totalSupply,
        uint256 _totalLocked,
        uint256 _totalBurned,
        uint256 _circulatingSupply
    ) {
        _totalSupply = totalSupply();
        _totalLocked = totalLocked;
        _totalBurned = totalBurned;
        _circulatingSupply = _totalSupply - balanceOf(address(this));
    }

    // ============ Internal Functions ============

    /**
     * @dev Override _update to add pausable functionality
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._update(from, to, amount);
    }
}