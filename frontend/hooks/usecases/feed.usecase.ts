'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  fetchMessagePage,
  OnchainFeedMessage,
  MessageStatus,
} from '@/lib/sui/messages';

export type FeedSort = 'latest' | 'likes' | 'alerts' | 'under_review';

export type FeedOptions = {
  search?: string;
  tags?: string[];
  sort?: FeedSort;
};

export type FeedEntry = OnchainFeedMessage & {
  displayedStatus: MessageStatus;
  statusReason?: 'likes_threshold' | 'alerts_threshold';
  likesToThreshold?: number | null;
  alertsToThreshold?: number | null;
};

const LIKES_THRESHOLD = 20;
const ALERTS_THRESHOLD = 20;

const deriveStatus = (message: OnchainFeedMessage): Pick<FeedEntry, 'displayedStatus' | 'statusReason' | 'likesToThreshold' | 'alertsToThreshold'> => {
  if (message.status !== 'NORMAL') {
    return {
      displayedStatus: message.status,
      statusReason: undefined,
      likesToThreshold: null,
      alertsToThreshold: null,
    };
  }

  if (message.likes >= LIKES_THRESHOLD) {
    return {
      displayedStatus: 'UNDER_REVIEW',
      statusReason: 'likes_threshold',
      likesToThreshold: 0,
      alertsToThreshold: Math.max(ALERTS_THRESHOLD - message.alerts, 0),
    };
  }

  if (message.alerts >= ALERTS_THRESHOLD) {
    return {
      displayedStatus: 'UNDER_REVIEW',
      statusReason: 'alerts_threshold',
      likesToThreshold: Math.max(LIKES_THRESHOLD - message.likes, 0),
      alertsToThreshold: 0,
    };
  }

  return {
    displayedStatus: 'NORMAL',
    statusReason: undefined,
    likesToThreshold: Math.max(LIKES_THRESHOLD - message.likes, 0),
    alertsToThreshold: Math.max(ALERTS_THRESHOLD - message.alerts, 0),
  };
};

const applySearch = (messages: FeedEntry[], term: string): FeedEntry[] => {
  const lowered = term.trim().toLowerCase();
  if (!lowered) return messages;

  return messages.filter((message) => {
    return (
      message.objectId.toLowerCase().includes(lowered) ||
      message.author.toLowerCase().includes(lowered) ||
      message.titleHash.toLowerCase().includes(lowered) ||
      message.contentHash.toLowerCase().includes(lowered) ||
      message.tags.some((tag) => tag.toLowerCase().includes(lowered))
    );
  });
};

const applyTags = (messages: FeedEntry[], selected: string[]): FeedEntry[] => {
  if (selected.length === 0) return messages;
  const lowered = selected.map((tag) => tag.toLowerCase());
  return messages.filter((message) =>
    lowered.every((tag) => message.tags.some((candidate) => candidate.toLowerCase() === tag)),
  );
};

const sortMessages = (messages: FeedEntry[], sort: FeedSort): FeedEntry[] => {
  switch (sort) {
    case 'likes':
      return [...messages].sort((a, b) => {
        if (b.likes === a.likes) return b.updatedEpoch - a.updatedEpoch;
        return b.likes - a.likes;
      });
    case 'alerts':
      return [...messages].sort((a, b) => {
        if (b.alerts === a.alerts) return b.updatedEpoch - a.updatedEpoch;
        return b.alerts - a.alerts;
      });
    case 'under_review':
      return [...messages].sort((a, b) => {
        const aFlag = a.displayedStatus === 'UNDER_REVIEW' ? 1 : 0;
        const bFlag = b.displayedStatus === 'UNDER_REVIEW' ? 1 : 0;
        if (aFlag === bFlag) {
          if (b.likes === a.likes) return b.updatedEpoch - a.updatedEpoch;
          return b.likes - a.likes;
        }
        return bFlag - aFlag;
      });
    case 'latest':
    default:
      return [...messages].sort((a, b) => b.updatedEpoch - a.updatedEpoch);
  }
};

export const useFeed = (initialOptions?: FeedOptions) => {
  const [messages, setMessages] = useState<OnchainFeedMessage[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  const [search, setSearch] = useState<string>(initialOptions?.search ?? '');
  const [selectedTags, setSelectedTags] = useState<string[]>(initialOptions?.tags ?? []);
  const [sort, setSort] = useState<FeedSort>(initialOptions?.sort ?? 'latest');

  const load = useCallback(
    async (reset: boolean) => {
      if (isLoading) return;
      setIsLoading(true);
      setError(null);
      try {
        const page = await fetchMessagePage(reset ? null : cursor);
        setMessages((prev) => (reset ? page.messages : [...prev, ...page.messages]));
        setCursor(page.nextCursor);
        setHasMore(page.hasNextPage);
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Failed to load feed';
        setError(message);
      } finally {
        setIsLoading(false);
      }
    },
    [cursor, isLoading],
  );

  useEffect(() => {
    void load(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const refresh = useCallback(() => {
    setCursor(null);
    void load(true);
  }, [load]);

  const loadMore = useCallback(() => {
    if (!hasMore || isLoading) return;
    void load(false);
  }, [hasMore, isLoading, load]);

  const toggleTag = useCallback((tag: string) => {
    setSelectedTags((prev) => {
      if (prev.includes(tag)) {
        return prev.filter((item) => item !== tag);
      }
      return [...prev, tag];
    });
  }, []);

  const clearTags = useCallback(() => {
    setSelectedTags([]);
  }, []);

  const entries = useMemo<FeedEntry[]>(() => {
    const base = messages.map((message) => ({
      ...message,
      ...deriveStatus(message),
    }));

    const withSearch = search ? applySearch(base, search) : base;
    const withTags = selectedTags.length > 0 ? applyTags(withSearch, selectedTags) : withSearch;
    return sortMessages(withTags, sort);
  }, [messages, search, selectedTags, sort]);

  const availableTags = useMemo(() => {
    const tagSet = new Set<string>();
    messages.forEach((message) => {
      message.tags.forEach((tag) => tagSet.add(tag));
    });
    return Array.from(tagSet.values()).sort();
  }, [messages]);

  return {
    messages: entries,
    rawMessages: messages,
    availableTags,
    selectedTags,
    toggleTag,
    clearTags,
    search,
    setSearch,
    sort,
    setSort,
    loadMore,
    refresh,
    hasMore,
    isLoading,
    error,
  };
};
