import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, utils } from 'ethers';
import { ethers } from 'hardhat';

import CollectionConfig from './../config/CollectionConfig';

enum SaleType {
  WHITELIST = CollectionConfig.whitelistSale.price,
  PRE_SALE = CollectionConfig.preSale.price,
  PUBLIC_SALE = CollectionConfig.publicSale.price,
}

function getPrice(saleType: SaleType, mintAmount: number) {
  return utils.parseEther(saleType.toString()).mul(mintAmount);
}

describe('ContractCollection', function () {
  let owner!: SignerWithAddress;
  let whitelistedUser!: SignerWithAddress;
  let holder!: SignerWithAddress;
  let externalUser!: SignerWithAddress;

  let deploymentConfig: {
    // Name of the Contract contract.
    name: string;
    // Symbol of the Contract contract.
    symbol: string;
    // The contract owner address. If you wish to own the contract, then set it as your wallet address.
    // This is also the wallet that can manage the contract on Contract marketplaces. Use `transferOwnership()`
    // to update the contract owner.
    owner: string;
    // The maximum number of tokens that can be minted in this collection.
    maxSupply: number;
    // The number of free token mints reserved for the contract owner
    reservedSupply: number;
    // Minting price per token.
    mintPrice: BigNumber;
    // The maximum number of tokens the user can mint per transaction.
    tokensPerMint: number;
    // Treasury address is the address where minting fees can be withdrawn to.
    // Use `withdrawFees()` to transfer the entire contract balance to the treasury address.
    treasuryAddress: string;
  };

  let runtimeConfig: {
    // Metadata base URI for tokens, Contracts minted in this contract will have metadata URI of `baseURI` + `tokenID`.
    // Set this to reveal token metadata.
    baseURI: string;
    // If true, the base URI of the Contracts minted in the specified contract can be updated after minting (token URIs
    // are not frozen on the contract level). This is useful for revealing Contracts after the drop. If false, all the
    // Contracts minted in this contract are frozen by default which means token URIs are non-updatable.
    metadataUpdatable: boolean;
    // Starting timestamp for public minting.
    publicMintStart: number;
    // Starting timestamp for whitelisted/presale minting.
    presaleMintStart: number;
    // Pre-reveal token URI for placholder metadata. This will be returned for all token IDs until a `baseURI`
    // has been set.
    prerevealTokenURI: string;
    // Root of the Merkle tree of whitelisted addresses. This is used to check if a wallet has been whitelisted
    // for presale minting.
    presaleMerkleRoot: string;
    // Secondary market royalties in basis points (100 bps = 1%)
    royaltiesBps: number;
    // Address for royalties
    royaltiesAddress: string;
  };

  before(async function () {
    [owner, whitelistedUser, holder, externalUser] = await ethers.getSigners();

    deploymentConfig = {
      name: CollectionConfig.tokenName,
      symbol: CollectionConfig.tokenSymbol,
      owner: await owner.getAddress(),
      maxSupply: CollectionConfig.maxSupply,
      reservedSupply: 10,
      mintPrice: getPrice(SaleType.WHITELIST, 1),
      tokensPerMint: 5,
      treasuryAddress: await owner.getAddress(),
    };

    /// Updatable by admins and owner
    runtimeConfig = {
      baseURI: 'ipfs://bafybeigbpetqzg523jenrwfkwu4izhm5rrhmyuofyar4wid6bx57logxm4/',
      metadataUpdatable: false,
      publicMintStart: 1648351848,
      presaleMintStart: 1648265448,
      prerevealTokenURI: 'ipfs://bafkreifqttle56xbho4zhbttp3afn3pgdahqpiqy6rnwez7heab5gftw7q',
      presaleMerkleRoot: '0x04a3e04eede938863f82857a51888d1095c80b4194ff003d5ae6058a8965a1a2',
      royaltiesBps: 100,
      royaltiesAddress: await owner.getAddress(),
    };

    // console.log('deploymentConfig:', deploymentConfig);
    // console.log('runtimeConfig:', runtimeConfig);
  });

  it('It should deploy the contract, mint a token, and resolve to the right URI', async () => {
    const Contract = await ethers.getContractFactory('NFTCollection');

    // code for upgradeable contracts
    // const contract = await upgrades.deployProxy(Contract, [tokenName, tokenSymbol, owner.address], { initializer: 'initialize(string,string,address)', unsafeAllow: ['constructor'] });

    const contract = await Contract.deploy();
    await contract.deployed();

    await contract.initialize(deploymentConfig, runtimeConfig);

    await expect(contract.connect(owner).mint(1)).to.be.revertedWith('Payment too small');

    // expect(await contract.tokenURI(1)).to.equal(CollectionConfig.hiddenMetadataUri);
    // const t = await contract.connect(owner).tokenURI(1);
  });

  it('It should deploy the contract, with correct name and symbol', async () => {
    const Contract = await ethers.getContractFactory('NFTCollection');
    const contract = await Contract.deploy();
    await contract.deployed();

    await contract.initialize(deploymentConfig, runtimeConfig);

    expect(await contract.name()).to.equal(CollectionConfig.tokenName);
    expect(await contract.symbol()).to.equal(CollectionConfig.tokenSymbol);
  });
});
