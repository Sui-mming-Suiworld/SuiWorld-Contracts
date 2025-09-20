'use client';

import type { FeedEntry } from '@/hooks/usecases/feed.usecase';

const STATUS_CLASS: Record<FeedEntry['displayedStatus'], string> = {
  NORMAL: 'bg-white/10 text-white',
  UNDER_REVIEW: 'bg-yellow-500/20 text-yellow-300',
  HYPED: 'bg-emerald-500/20 text-emerald-300',
  SPAM: 'bg-red-500/20 text-red-300',
  DELETED: 'bg-gray-500/20 text-gray-300',
};

const formatAddress = (address: string) => {
  if (!address) return 'Unknown';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
};

const formatHash = (hash: string) => {
  if (!hash) return '0x';
  if (hash.length <= 14) return hash;
  return `${hash.slice(0, 10)}...${hash.slice(-4)}`;
};

type Props = {
  entry: FeedEntry;
  onTagClick?: (tag: string) => void;
};

export function FeedCard({ entry, onTagClick }: Props) {
  return (
    <article className="bg-white/5 rounded-2xl p-4 space-y-4 border border-white/10">
      <header className="flex items-start justify-between gap-4">
        <div className="space-y-1">
          <div className="text-sm font-semibold text-white">{formatAddress(entry.author)}</div>
          <div className="text-xs text-white/50">ID: {formatHash(entry.objectId)}</div>
        </div>
        <span className={`px-2 py-1 text-xs font-semibold rounded-full ${STATUS_CLASS[entry.displayedStatus]}`}>
          {entry.displayedStatus}
        </span>
      </header>

      <div className="rounded-xl bg-white text-black p-3 text-sm space-y-2">
        <p className="font-mono text-xs text-black/60">title_hash: {formatHash(entry.titleHash)}</p>
        <p className="font-mono text-xs text-black/60">content_hash: {formatHash(entry.contentHash)}</p>
        <p className="text-xs text-black/70">
          Message content lives off-chain. Once resolved, the UI will hydrate the hash with the actual text.
        </p>
      </div>

      <div className="flex flex-wrap gap-2">
        {entry.tags.length === 0 && <span className="text-xs text-white/40">No tags</span>}
        {entry.tags.map((tag) => (
          <button
            key={tag}
            type="button"
            onClick={() => onTagClick?.(tag)}
            className="px-2 py-1 rounded-full bg-white/10 text-xs text-white/70 hover:bg-white/20"
          >
            #{tag}
          </button>
        ))}
      </div>

      <footer className="flex flex-wrap items-center gap-4 text-xs text-white/70">
        <span>Likes: {entry.likes}</span>
        <span>Alerts: {entry.alerts}</span>
        <span>Epoch {entry.createdEpoch}</span>
        {entry.statusReason === 'likes_threshold' && <span>Reached like threshold</span>}
        {entry.statusReason === 'alerts_threshold' && <span>Reached alert threshold</span>}
      </footer>
    </article>
  );
}
