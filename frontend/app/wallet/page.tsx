import Image from "next/image";
import { TokenCard } from "../components/TokenCard";
import { AddressBox } from "../components/AddressBox";

export default function WalletPage() {
  return (
    <div className="space-y-5 pb-28">
      <div className="space-y-3">
        <TokenCard
          icon={<Image src="/SWT.png" alt="Sui World Token" width={40} height={40} className="h-10 w-10 object-contain" />}
          name="Sui World Token"
          price="$0.001"
          sub="10,000 Swt"
          right="$100"
        />
        <TokenCard
          icon={<Image src="/SUI.png" alt="Sui" width={40} height={40} className="h-10 w-10 object-contain" />}
          name="Sui"
          price="$3.66"
          sub="100 Sui"
          right="$366.2"
        />
        <TokenCard
          icon={<Image src="/SOL.png" alt="Solana" width={40} height={40} className="h-10 w-10 object-contain" />}
          name="Solana"
          price="$240"
          sub="1.7 SOL"
          right="$408"
        />
        <TokenCard
          icon={<Image src="/ETH.png" alt="Ethereum" width={40} height={40} className="h-10 w-10 object-contain" />}
          name="Ethereum"
          price="$4,500"
          sub="3 ETH"
          right="$13,500"
        />
      </div>

      <AddressBox />
    </div>
  );
}
