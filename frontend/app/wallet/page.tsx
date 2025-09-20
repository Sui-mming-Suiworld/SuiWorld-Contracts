import { TokenCard } from "../components/TokenCard";
import { AddressBox } from "../components/AddressBox";

export default function WalletPage() {
  return (
    <div className="space-y-5 pb-28">
      <div className="space-y-3">
        <TokenCard name="Sui World Token" price="$0.001" sub="10,000 Swt" right="$100" />
        <TokenCard name="Sui" price="$3.66" sub="100 Sui" right="$366.2" />
        <TokenCard name="Bitcoin" price="$155,500" sub="1 BTC" right="$155,500" />
        <TokenCard name="Ethereum" price="$4,500" sub="3 ETH" right="$13,500" />
      </div>

      <AddressBox />
    </div>
  );
}
