const { expect } = require("chai");
const { ethers } = require("hardhat");
// const {BigNumb} = require("ethers")

describe("GadgetShop Contract", function () {
  let GadgetShop;
  let gadgetShop;
  let owner;
  let buyer;
  let seller;
  let addrs;

  beforeEach(async function () {
    GadgetShop = await ethers.getContractFactory("GadgetShop");
    [owner, buyer, seller, ...addrs] = await ethers.getSigners();
    gadgetShop = await GadgetShop.deploy(10); // Assuming 10% commission rate
    await gadgetShop.waitForDeployment();
    const transaction = {
      to: gadgetShop.getAddress(),
      value: ethers.parseEther("1.0")
    }
    buyer.sendTransaction(transaction);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await gadgetShop.owner()).to.equal(owner.address);
    });

    it("Should set the right commission rate", async function () {
      expect(await gadgetShop.commission_rate()).to.equal(10);
    });
  });

  describe("Transactions", function () {
    it("Should emit ProductAdded event when a new product is added", async function () {
      const productID = await gadgetShop.generateID("Gadget", seller.address);
      await expect(gadgetShop.connect(seller).addProduct("Gadget", "Features", ethers.parseEther("1"), seller.address))
        .to.emit(gadgetShop, "ProductAdded")
        .withArgs(seller.address, "Gadget", productID, ethers.parseEther("1"));
    });

    it("Should allow a buyer to purchase a product and emit ProductBought event", async function () {
      const productID = await gadgetShop.generateID("Gadget", seller.address);
      gadgetShop.connect(seller).addProduct("Gadget", "Features", ethers.parseEther("1"), seller.address);
      await expect(gadgetShop.connect(buyer).buyProduct(productID, { value: ethers.parseEther("1") }))
        .to.emit(gadgetShop, "ProductBought")
        .withArgs(buyer.address, seller.address, ethers.parseEther("0.1"), "Gadget", productID);
    });

    it("Should fail if the product does not exist", async function () {
      const fakeProductID = ethers.encodeBytes32String("fake");
      await expect(gadgetShop.connect(buyer).buyProduct(fakeProductID, { value: ethers.parseEther("1") }))
        .to.be.revertedWith("Product does not exist");
    });

    it("Should allow owner to withdraw balance", async function () {
      buyer.transfer({
        to: gadgetShop.getAddress(),
        value: ethers.parseEther("1.0")
      })
      const ownerBalanceBefore = await ethers.provider.getBalance(owner.getAddress());
      const contract_balance = await ethers.provider.getBalance(gadgetShop.getAddress());
      
      // Capture the transaction details to calculate gas cost
      const tx = await gadgetShop.connect(owner).withdraw();
      // const receipt = await tx.wait(); // Wait for the transaction to be mined
      // const gasUsed = ethers.toBigInt(receipt.gasUsed) * ethers.toBigInt(receipt.effectiveGasPrice);
    
      const ownerBalanceAfter = await ethers.provider.getBalance(owner.address);
    
      // The owner's balance after should be the initial balance plus the contract balance minus the gas cost
      expect(ownerBalanceAfter).to.equal(ownerBalanceBefore.add(contract_balance).sub(gasUsed));
    });
    

    it("Should fail if non-owner tries to withdraw", async function () {
      await expect(gadgetShop.connect(buyer).withdraw()).to.be.revertedWith("You cannot do this!");
    });

    // Add more tests for buyProduct, takeCommission, paySeller, etc.
  });

  // Add tests for edge cases like buying a product that doesn't exist,
  // buying without enough funds, paying a seller with no balance, etc.
});
