// TODO: Define TypeScript types for API payloads

export interface UserProfile {
  id: string;
  imageUrl: string;
  description: string;
}

export interface Message {
  id: string;
  content: string;
  creator: UserProfile;
  likes: number;
  alerts: number;
}
