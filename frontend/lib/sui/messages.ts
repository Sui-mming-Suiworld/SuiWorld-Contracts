import type { DynamicFieldInfo, SuiObjectResponse } from '@mysten/sui/client';
import { suiClient, SUI_ENV } from './provider';

export type MessageStatus = 'NORMAL' | 'UNDER_REVIEW' | 'HYPED' | 'SPAM' | 'DELETED';

export type OnchainFeedMessage = {
  objectId: string;
  author: string;
  titleHash: string;
  contentHash: string;
  tags: string[];
  likes: number;
  alerts: number;
  status: MessageStatus;
  statusRaw: number;
  createdEpoch: number;
  updatedEpoch: number;
};

export type MessagePage = {
  messages: OnchainFeedMessage[];
  nextCursor: string | null;
  hasNextPage: boolean;
};

const STATUS_LABELS: MessageStatus[] = ['NORMAL', 'UNDER_REVIEW', 'HYPED', 'SPAM', 'DELETED'];

const PAGE_LIMIT = 20;

const toNumber = (value: unknown): number => {
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    if (value.startsWith('0x')) {
      return Number.parseInt(value, 16);
    }
    return Number.parseInt(value, 10);
  }
  if (typeof value === 'bigint') {
    return Number(value);
  }
  return 0;
};

const extractMessageId = (field: DynamicFieldInfo): string | null => {
  const raw = field.name.value as unknown;
  if (!raw) return null;
  if (typeof raw === 'string') return raw;
  if (typeof raw === 'object' && raw !== null) {
    const maybeId = (raw as { id?: string; fields?: { id?: string } }).id ??
      (raw as { fields?: { id?: string } }).fields?.id;
    if (maybeId) return maybeId;
  }
  return null;
};

const parseTags = (value: unknown): string[] => {
  if (!value) return [];
  if (Array.isArray(value)) {
    return value
      .map((item) => {
        if (typeof item === 'string') return item;
        if (item && typeof item === 'object' && 'toString' in item) return String(item);
        return null;
      })
      .filter((tag): tag is string => typeof tag === 'string' && tag.length > 0);
  }
  return [];
};

const toStatus = (raw: unknown): { status: MessageStatus; raw: number } => {
  const numeric = toNumber(raw);
  const status = STATUS_LABELS[numeric] ?? 'NORMAL';
  return { status, raw: numeric };
};

const parseMessageObject = (object: SuiObjectResponse): OnchainFeedMessage | null => {
  if (!object.data) return null;
  const { content, objectId } = object.data;
  if (!content || content.dataType !== 'moveObject') return null;
  const fields = (content as typeof content & { fields: Record<string, unknown> }).fields;
  if (!fields) return null;

  const { status, raw } = toStatus(fields.status);

  return {
    objectId,
    author: typeof fields.author === 'string' ? fields.author : '',
    titleHash: typeof fields.title_hash === 'string' ? fields.title_hash : '',
    contentHash: typeof fields.content_hash === 'string' ? fields.content_hash : '',
    tags: parseTags(fields.tags),
    likes: toNumber(fields.likes),
    alerts: toNumber(fields.alerts),
    status,
    statusRaw: raw,
    createdEpoch: toNumber(fields.created_at),
    updatedEpoch: toNumber(fields.updated_at),
  };
};

export const fetchMessagePage = async (
  cursor: string | null,
  limit: number = PAGE_LIMIT,
): Promise<MessagePage> => {
  if (!SUI_ENV.messageBoardId) {
    return { messages: [], nextCursor: null, hasNextPage: false };
  }

  const page = await suiClient.getDynamicFields({
    parentId: SUI_ENV.messageBoardId,
    cursor: cursor ?? undefined,
    limit,
  });

  const messageIds = page.data
    .map((field) => extractMessageId(field))
    .filter((id): id is string => Boolean(id));

  if (messageIds.length === 0) {
    return {
      messages: [],
      nextCursor: page.nextCursor ?? null,
      hasNextPage: page.hasNextPage ?? false,
    };
  }

  const objects = await suiClient.multiGetObjects({
    ids: messageIds,
    options: {
      showContent: true,
      showType: true,
    },
  });

  const messages = objects
    .map((object) => parseMessageObject(object))
    .filter((message): message is OnchainFeedMessage => message !== null);

  return {
    messages,
    nextCursor: page.nextCursor ?? null,
    hasNextPage: page.hasNextPage ?? false,
  };
};
