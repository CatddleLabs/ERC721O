const {
  expect
} = require("chai");
const {
  ethers
} = require("hardhat");

describe("Test gas cost", function () {
  let mockEndPoint;
  let basicToken;
  before(async () => {
    // Mock LZEndpoint
    const MockEndPoint = await hre.ethers.getContractFactory("LZEndpointMock");
    mockEndPoint = await MockEndPoint.deploy(1);
    await mockEndPoint.deployed();
    console.log("MockEndPoint deployed to:", mockEndPoint.address);

    // OmnichainNFT deployed
    const BasicToken = await hre.ethers.getContractFactory("contracts/examples/ERC721OToken.sol:ERC721OToken");
    basicToken = await BasicToken.deploy(mockEndPoint.address);
    await basicToken.deployed();



  })
  it("Test", async function () {
    await basicToken.mint(1);
  });
});