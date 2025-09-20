import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';

const DEFAULT_NETWORK = 'testnet';
const rpcUrl = process.env.NEXT_PUBLIC_SUI_RPC_URL ?? getFullnodeUrl(DEFAULT_NETWORK);

export const suiClient = new SuiClient({ url: rpcUrl });

export const SUI_ENV = {
  network: DEFAULT_NETWORK,
  rpcUrl,
  packageId: process.env.NEXT_PUBLIC_SUI_PACKAGE_ID ?? '',
  messageBoardId: process.env.NEXT_PUBLIC_SUI_MESSAGE_BOARD_ID ?? '',
};
