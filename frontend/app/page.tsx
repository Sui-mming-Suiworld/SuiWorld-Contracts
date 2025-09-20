'use client';

import { useMemo } from 'react';
import { Chip } from './components/Chip';
import { FeedCard } from './components/FeedCard';
import { useFeed, type FeedSort } from '@/hooks/usecases/feed.usecase';

const SORT_LABELS: Record<FeedSort, string> = {
  latest: 'Latest',
  likes: 'Most Likes',
  alerts: 'Most Alerts',
  under_review: 'Under Review',
};

export default function HomePage() {
  const {
    messages,
    availableTags,
    selectedTags,
    toggleTag,
    clearTags,
    search,
    setSearch,
    sort,
    setSort,
    loadMore,
    hasMore,
    isLoading,
    error,
  } = useFeed({ sort: 'latest' });

  const [highlights, rest] = useMemo(() => {
    if (messages.length <= 2) {
      return [messages, []];
    }
    return [messages.slice(0, 2), messages.slice(2)];
  }, [messages]);

  return (
    <div className="space-y-6 pb-24">
      <section className="space-y-4">
        <div>
          <input
            value={search}
            onChange={(event) => setSearch(event.target.value)}
            placeholder="Search by address, hash, or tag"
            className="w-full rounded-xl bg-white/10 border border-white/20 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:outline-none focus:ring-2 focus:ring-brand-blue"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {availableTags.length > 0 ? (
            <>
              {availableTags.map((tag) => (
                <Chip
                  key={tag}
                  label={`#${tag}`}
                  active={selectedTags.includes(tag)}
                  onClick={() => toggleTag(tag)}
                />
              ))}
              {selectedTags.length > 0 && (
                <button
                  type="button"
                  onClick={clearTags}
                  className="text-xs text-white/60 underline hover:text-white"
                >
                  Clear tags
                </button>
              )}
            </>
          ) : (
            <span className="text-xs text-white/40">No tags detected on-chain yet</span>
          )}
        </div>

        <div className="flex gap-2 flex-wrap">
          {(Object.keys(SORT_LABELS) as FeedSort[]).map((key) => (
            <Chip
              key={key}
              label={SORT_LABELS[key]}
              active={sort === key}
              onClick={() => setSort(key)}
            />
          ))}
        </div>
      </section>

      {error && (
        <div className="rounded-xl border border-red-500/40 bg-red-500/10 px-4 py-3 text-sm text-red-300">
          {error}
        </div>
      )}

      <section className="space-y-3">
        {highlights.length > 0 && (
          <div className="space-y-3">
            <h2 className="text-sm font-semibold text-white/80">Top Messages</h2>
            <div className="grid gap-3 md:grid-cols-2">
              {highlights.map((entry) => (
                <FeedCard key={entry.objectId} entry={entry} onTagClick={toggleTag} />
              ))}
            </div>
          </div>
        )}

        <div className="space-y-3">
          {rest.map((entry) => (
            <FeedCard key={entry.objectId} entry={entry} onTagClick={toggleTag} />
          ))}
        </div>

        {!isLoading && messages.length === 0 && (
          <div className="rounded-xl border border-white/10 bg-white/5 px-4 py-6 text-center text-sm text-white/60">
            No on-chain messages yet. Be the first to post!
          </div>
        )}

        <div className="flex justify-center pt-2">
          {hasMore ? (
            <button
              type="button"
              onClick={loadMore}
              disabled={isLoading}
              className="px-4 py-2 rounded-full bg-white/10 text-sm text-white/80 border border-white/20 hover:bg-white/20 disabled:opacity-50"
            >
              {isLoading ? 'Loading...' : 'Load more'}
            </button>
          ) : (
            <span className="text-xs text-white/40">You reached the end of the feed</span>
          )}
        </div>
      </section>
    </div>
  );
}
