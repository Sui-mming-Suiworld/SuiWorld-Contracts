// // TODO: Implement Sui provider and wallet connection
// import { getFullnodeUrl, SuiClient } from '@mysten/sui.js/client';

// export const suiClient = new SuiClient({ url: getFullnodeUrl('devnet') });

// TODO: Implement Sui provider and wallet connection
import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';

export const suiClient = new SuiClient({ url: getFullnodeUrl('devnet') });
