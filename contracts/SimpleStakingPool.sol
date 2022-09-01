// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleStakingPool is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    // ERC20 contract address
    IERC20 public immutable tokenAddress;

    // Staker info
    struct Staker {
        uint256 deposited;
        uint256 timeOfLastUpdate;
        uint256 unclaimedRewards;
    }

    uint256 public APR = 40; // 40% APR

    // Minimum amount to stake
    uint256 public minStake = 10 * 1e18;

    // Compounding frequency limit in seconds
    uint256 public compoundFreq = 86400; //24 hours

    // Mapping of address to Staker info
    mapping(address => Staker) internal stakers;

    modifier rateLimit(address _account) {
        uint256 remainingTime = compoundRewardsTimer(_account);

        require(remainingTime == 0, "Too soon!");

        _;
    }

    // Events
    event Deposit(address indexed _from, uint256 _value);
    event ClaimRewards(address indexed _from, uint256 _value);
    event StakeRewards(address indexed _from, uint256 _value);
    event Withdraw(address indexed _from, uint256 _value);
    event Unstake(address indexed _from, uint256 _value);

    constructor(address _tokenAddress) {
        tokenAddress = IERC20(_tokenAddress);
    }

    // If address firstly stake, initiate one.
    // If address already stake,calculate unclaimedRewards, reset the last time of
    // deposit and then add _amount to the already deposited amount.
    function deposit(uint256 _amount)
        external
        nonReentrant
        rateLimit(msg.sender)
    {
        require(_amount >= minStake, "Amount smaller than minimimum deposit");

        tokenAddress.safeTransferFrom(msg.sender, address(this), _amount);

        if (stakers[msg.sender].deposited == 0) {
            stakers[msg.sender].deposited = _amount;
            stakers[msg.sender].timeOfLastUpdate = block.timestamp;
            stakers[msg.sender].unclaimedRewards = 0;
        } else {
            uint256 rewards = calculateRewards(msg.sender);

            stakers[msg.sender].unclaimedRewards += rewards;
            stakers[msg.sender].deposited += _amount;
            stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        }

        emit Deposit(msg.sender, _amount);
    }

    // Get current unclaimed reward
    function claimRewards() external nonReentrant rateLimit(msg.sender) {
        uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;

        require(rewards > 0, "You have no rewards");

        stakers[msg.sender].unclaimedRewards = 0;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;

        tokenAddress.safeTransfer(msg.sender, rewards);

        emit ClaimRewards(msg.sender, rewards);
    }

    // Stake current unclaimed reward
    function stakeRewards() external nonReentrant rateLimit(msg.sender) {
        uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;

        require(rewards > 0, "You have no rewards");

        this.deposit(rewards);

        emit StakeRewards(msg.sender, rewards);
    }

    // Only withdraw amount you deposited
    function withdraw(uint256 _amount)
        external
        nonReentrant
        rateLimit(msg.sender)
    {
        require(
            stakers[msg.sender].deposited >= _amount,
            "Can't withdraw more than you have"
        );

        uint256 _rewards = calculateRewards(msg.sender);

        stakers[msg.sender].deposited -= _amount;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = _rewards;

        tokenAddress.safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw both deposited and unclaimed reward
    function unstake() external nonReentrant rateLimit(msg.sender) {
        require(stakers[msg.sender].deposited > 0, "You have no deposit");

        uint256 _rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;
        uint256 _deposit = stakers[msg.sender].deposited;

        stakers[msg.sender].deposited = 0;
        stakers[msg.sender].timeOfLastUpdate = 0;
        stakers[msg.sender].unclaimedRewards = 0;

        uint256 _amount = _rewards + _deposit;

        tokenAddress.safeTransfer(msg.sender, _amount);

        emit Unstake(msg.sender, _amount);
    }

    function getDepositInfo(address _user)
        public
        view
        returns (uint256 _stake, uint256 _rewards)
    {
        _stake = stakers[_user].deposited;
        _rewards =
            calculateRewards(_user) +
            stakers[msg.sender].unclaimedRewards;

        return (_stake, _rewards);
    }

    //  Returns the timer for restaking rewards
    function compoundRewardsTimer(address _account)
        public
        view
        returns (uint256 _timer)
    {
        if (
            stakers[_account].timeOfLastUpdate + compoundFreq <= block.timestamp
        ) {
            return 0;
        } else {
            return
                (stakers[_account].timeOfLastUpdate + compoundFreq) -
                block.timestamp;
        }
    }

    function calculateRewards(address _staker)
        internal
        view
        returns (uint256 rewards)
    {
        return
            ((block.timestamp - stakers[_staker].timeOfLastUpdate) *
                stakers[_staker].deposited *
                APR) / (365 * 24 * 3600 * 100);
    }
}
