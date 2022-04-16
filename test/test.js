const {
  expect
} = require("chai");
const {
  ethers
} = require("hardhat");

describe("Test gas cost", function () {
  let mockEndPointA, mockEndPointB, tokenChainA, tokenChainB;
  let owner, alice, bob;
  const chainIdA = 1;
  const chainIdB = 2;
  const zeroAddress = "0x0000000000000000000000000000000000000000";
  const adapterParams = "0x000100000000000000000000000000000000000000000000000000000000000186a0";
  before(async () => {
    signers = await ethers.getSigners();
    owner = signers[0];
    alice = signers[1];
    bob = signers[2];

    // mock endpoints
    const MockEndPoint = await hre.ethers.getContractFactory("LZEndpointMock");
    mockEndPointA = await MockEndPoint.deploy(chainIdA);
    await mockEndPointA.deployed();

    mockEndPointB = await MockEndPoint.deploy(chainIdB);
    await mockEndPointB.deployed();

    // ERC721O Token deployed
    const ERC721OToken = await hre.ethers.getContractFactory("contracts/examples/ERC721OToken.sol:ERC721OToken");
    tokenChainA = await ERC721OToken.deploy(mockEndPointA.address);
    await tokenChainA.deployed();

    tokenChainB = await ERC721OToken.deploy(mockEndPointB.address);
    await tokenChainB.deployed();

    // connect LzEndpoint
    await mockEndPointA.setDestLzEndpoint(tokenChainB.address, mockEndPointB.address)
    await mockEndPointB.setDestLzEndpoint(tokenChainA.address, mockEndPointA.address)
  })

  it("Test", async function () {
    await tokenChainA.mint(2);
    // set each remote
    await tokenChainA.setRemote(2, tokenChainB.address);
    await tokenChainB.setRemote(1, tokenChainA.address);

    // send cross chain to alice
    await tokenChainA.move(2, alice.address, 0, zeroAddress, adapterParams);
    // alice received
    expect(await tokenChainB.ownerOf(0)).to.equal(alice.address);
    expect(await tokenChainA.balanceOf(owner.address)).to.equal(1);

    // approve token
    await tokenChainB.connect(alice).approve(bob.address, 0);
    // send cross chain to alice
    await tokenChainB.connect(bob).moveFrom(alice.address, 1, owner.address, 0, bob.address, zeroAddress, adapterParams);
    // owner received
    expect(await tokenChainA.ownerOf(0)).to.equal(owner.address);
  });
});