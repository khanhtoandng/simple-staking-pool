import { ethers } from 'hardhat';

async function main() {
  // Deploy token
  const SimpleToken = await ethers.getContractFactory('SimpleToken');
  const simpleToken = await SimpleToken.deploy();

  await simpleToken.deployed();

  console.log('SimpleToken deployed to:', simpleToken.address);

  // Deploy simple staking pool
  const StakingPool = await ethers.getContractFactory('SimpleStakingPool');
  const stakingPool = await StakingPool.deploy(simpleToken.address);

  await stakingPool.deployed();

  console.log('StakingPool deployed to:', stakingPool.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
