import MarketplaceConfigInterface from '../lib/MarketplaceConfigInterface';
import NetworkConfigInterface from '../lib/NetworkConfigInterface';

interface SaleConfig {
  price: number;
  maxMintAmountPerTx: number;
}

export default interface CollectionConfigInterface {
  testnet: NetworkConfigInterface;
  mainnet: NetworkConfigInterface;
  contractName: string;
  tokenName: string;
  tokenSymbol: string;
  hiddenMetadataUri: string;
  maxSupply: number;
  whitelistSale: SaleConfig;
  preSale: SaleConfig;
  publicSale: SaleConfig;
  contractAddress: string | null;
  whitelistAddresses: string[];
  marketplaceIdentifier: string;
  marketplaceConfig: MarketplaceConfigInterface;
  reservedSupply: number;
  royaltyFeesInBips: number;
}
