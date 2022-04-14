// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // Mock LZEndpoint
  const MockEndPoint = await hre.ethers.getContractFactory("LZEndpointMock");
  const mockEndPoint = await MockEndPoint.deploy(1);
  await mockEndPoint.deployed();
  console.log("MockEndPoint deployed to:", mockEndPoint.address);

  // OmnichainNFT deployed
  const ERC721ONFT = await hre.ethers.getContractFactory("ERC721OToken");
  const ERC721ONFT = await ERC721ONFT.deploy(mockEndPoint.address);
  await ERC721ONFT.deployed();

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });