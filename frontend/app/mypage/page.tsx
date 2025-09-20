"use client";

import { useState } from "react";
import Image from "next/image";

import { FeedCard } from "../components/FeedCard";

const tabs = [
  { id: "posts", label: "게시물" },
  { id: "replies", label: "답글" },
  { id: "likes", label: "좋아요" },
] as const;

type TabId = (typeof tabs)[number]["id"];

type SimplePost = {
  id: string;
  text: string;
};

const profile = {
  name: "오승준",
  handle: "@oh",
  address: "0xf2abe...8b4b4",
  status: "안녕하세요, PDAO의 대장 오승준입니다.",
  following: "123",
  followers: "456",
  avatar: "/oh-seungjun.png",
};

const myPosts: SimplePost[] = [
  {
    id: "oh-1",
    text: "마라 홀딩스 홀더입니다. 비트 가즈아",
  },
];

const tabEmptyCopy: Record<TabId, string> = {
  posts: "아직 작성한 게시물이 없어요.",
  replies: "아직 남긴 답글이 없습니다.",
  likes: "좋아요한 게시물이 여기에 모입니다.",
};

const postsByTab: Record<TabId, SimplePost[]> = {
  posts: myPosts,
  replies: [],
  likes: [],
};

const settingsOptions = ["프로필 수정", "지갑 연결", "로그아웃"];
const adminMenuItems = ["글 관리하기", "신고글", "쿠킹 글 확인"];

type AdminMember = {
  name: string;
  address: string;
  avatar: string;
};

const adminMembers: AdminMember[] = [
  { name: "김영웅", address: "0xh3aba...8a3hy", avatar: "/admin-kim.png" },
  { name: "이재현", address: "0xf2tcb...0n16c", avatar: "/admin-lee.png" },
  { name: "디아즈", address: "0xfv8bx...9n8ya", avatar: "/admin-diaz.png" },
];

export default function MyPage() {
  const [activeTab, setActiveTab] = useState<TabId>("posts");
  const [showSettings, setShowSettings] = useState(false);
  const [showAdminTools, setShowAdminTools] = useState(false);
  const [showAdminPanel, setShowAdminPanel] = useState(false);

  const activeIndex = tabs.findIndex((tab) => tab.id === activeTab);
  const activePosts = postsByTab[activeTab];

  const toggleAdminTools = () => {
    setShowAdminTools((prev) => !prev);
    setShowSettings(false);
  };

  const openAdminPanel = () => {
    setShowAdminPanel(true);
    setShowSettings(false);
  };

  const closeAdminPanel = () => {
    setShowAdminPanel(false);
  };

  return (
    <div className="space-y-6 pb-24 text-slate-900">
      <section className="relative rounded-3xl border border-slate-200 bg-card p-5 shadow-sm">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-start gap-4">
            <div className="h-16 w-16 overflow-hidden rounded-full bg-white shadow-sm">
              <Image
                src={profile.avatar}
                alt={`${profile.name} profile image`}
                width={64}
                height={64}
                className="h-full w-full object-cover"
              />
            </div>
            <div className="space-y-1 text-sm text-slate-600">
              <div className="text-lg font-semibold text-slate-900">{profile.name}</div>
              <div className="text-slate-500">{profile.handle}</div>
              <p className="text-slate-600">{profile.status}</p>
              <div className="flex gap-4 pt-1 text-slate-500">
                <span>
                  <span className="font-semibold text-slate-900">{profile.following}</span> 팔로잉
                </span>
                <span>
                  <span className="font-semibold text-slate-900">{profile.followers}</span> 팔로워
                </span>
              </div>
            </div>
          </div>

          <div className="relative flex items-center gap-2 pl-8">
            <button
              type="button"
              onClick={toggleAdminTools}
              className="absolute left-0 top-1/2 h-10 w-10 -translate-y-1/2 rounded-full focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-blue/50"
              aria-label="관리자 도구 아이콘 표시"
            />
            {showAdminTools ? (
              <button
                type="button"
                onClick={openAdminPanel}
                className="flex h-10 w-10 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-600 transition hover:text-slate-900"
                aria-label="관리자 메뉴 열기"
              >
                <Image src="/manager-select-icon.png" alt="관리자 아이콘" width={20} height={20} />
              </button>
            ) : null}
            <button
              type="button"
              onClick={() => setShowSettings((prev) => !prev)}
              className="flex h-10 w-10 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-600 transition hover:text-slate-900"
              aria-haspopup="true"
              aria-expanded={showSettings}
              aria-label="설정 메뉴 열기"
            >
              <SettingsIcon className="h-5 w-5" />
            </button>
            <button
              type="button"
              className="flex h-10 w-10 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-600 transition hover:text-slate-900"
              aria-label="프로필 공유"
            >
              <ShareIcon className="h-5 w-5" />
            </button>
          </div>
        </div>

        {showSettings ? (
          <div className="absolute right-5 top-20 z-10 w-48 rounded-2xl border border-slate-200 bg-white p-3 shadow-lg">
            <div className="text-sm font-medium text-slate-500">설정</div>
            <div className="mt-2 space-y-1">
              {settingsOptions.map((label) => (
                <button
                  key={label}
                  type="button"
                  onClick={() => setShowSettings(false)}
                  className="w-full rounded-xl px-3 py-2 text-left text-sm text-slate-600 transition hover:bg-slate-100"
                >
                  {label}
                </button>
              ))}
            </div>
          </div>
        ) : null}
      </section>

      <section className="space-y-3">
        <div className="space-y-2">
          <div className="flex items-center text-sm font-medium">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setActiveTab(tab.id)}
                className={`flex-1 px-2 py-1 text-center transition ${
                  activeTab === tab.id ? "text-slate-900" : "text-slate-500 hover:text-slate-700"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>
          <div className="relative h-1 overflow-hidden rounded-full bg-slate-200">
            <div
              className="absolute top-0 h-full rounded-full bg-brand-blue transition-all duration-200"
              style={{
                width: `${100 / tabs.length}%`,
                left: `${activeIndex * (100 / tabs.length)}%`,
              }}
            />
          </div>
        </div>

        {activePosts.length > 0 ? (
          <div className="space-y-3">
            {activePosts.map((post) => (
              <FeedCard
                key={post.id}
                id={post.id}
                name={profile.name}
                text={post.text}
                avatarSrc={profile.avatar}
                avatarAlt={`${profile.name} profile image`}
                footer={
                  <div className="flex items-center gap-4 text-sm text-slate-500">
                    <span aria-hidden="true">♡</span>
                    <span aria-hidden="true">💬</span>
                  </div>
                }
              />
            ))}
          </div>
        ) : (
          <div className="rounded-2xl border border-dashed border-slate-200 bg-white p-6 text-center text-sm text-slate-500">
            {tabEmptyCopy[activeTab]}
          </div>
        )}
      </section>

      {showAdminPanel ? (
        <AdminPanel
          profile={profile}
          menuItems={adminMenuItems}
          members={adminMembers}
          onClose={closeAdminPanel}
        />
      ) : null}
    </div>
  );
}

type IconProps = {
  className?: string;
};

function SettingsIcon({ className }: IconProps) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="m19.4 13.5-.63 1.1a1.5 1.5 0 0 0 .16 1.7l.05.07a1.5 1.5 0 0 1-1.06 2.4l-1.27.05a1.5 1.5 0 0 0-1.33.88l-.47 1.2a1.5 1.5 0 0 1-2.8 0l-.47-1.2a1.5 1.5 0 0 0-1.33-.88l-1.27-.05a1.5 1.5 0 0 1-1.06-2.4l.05-.07a1.5 1.5 0 0 0 .16-1.7l-.63-1.1a1.5 1.5 0 0 1 .55-2.03l1.1-.63a1.5 1.5 0 0 0 .72-1.3l-.03-1.27a1.5 1.5 0 0 1 2.4-1.06l.07.05a1.5 1.5 0 0 0 1.7.16l1.1-.63a1.5 1.5 0 0 1 2.03.55l.63 1.1a1.5 1.5 0 0 0 1.3.72l1.27-.03a1.5 1.5 0 0 1 1.06 2.4l-.05.07a1.5 1.5 0 0 0-.16 1.7l.63 1.1a1.5 1.5 0 0 1-.55 2.03l-1.1.63a1.5 1.5 0 0 0-.72 1.3"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function ShareIcon({ className }: IconProps) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      <path
        d="M15 4h5v5"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M14.5 9.5 20 4"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M11 5h-3a4 4 0 0 0-4 4v8a4 4 0 0 0 4 4h8a4 4 0 0 0 4-4v-3"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

type AdminPanelProps = {
  profile: typeof profile;
  menuItems: string[];
  members: AdminMember[];
  onClose: () => void;
};

function AdminPanel({ profile, menuItems, members, onClose }: AdminPanelProps) {
  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-6 py-10"
      role="dialog"
      aria-modal="true"
      onClick={onClose}
    >
      <div
        className="relative w-full max-w-md rounded-3xl bg-white text-slate-900 shadow-2xl"
        onClick={(event) => event.stopPropagation()}
      >
        <button
          type="button"
          onClick={onClose}
          className="absolute right-5 top-5 h-8 w-8 rounded-full text-slate-400 transition hover:bg-slate-100 hover:text-slate-700"
          aria-label="관리자 패널 닫기"
        >
          ×
        </button>

        <div className="space-y-6 p-6">
          <div className="flex items-center gap-4">
            <div className="h-16 w-16 overflow-hidden rounded-full bg-slate-100">
              <Image
                src={profile.avatar}
                alt={`${profile.name} profile image`}
                width={64}
                height={64}
                className="h-full w-full object-cover"
              />
            </div>
            <div className="space-y-1 text-sm text-slate-600">
              <div className="text-base font-semibold text-slate-900">{profile.name}</div>
              <div className="font-mono text-xs text-slate-500">{profile.address}</div>
            </div>
          </div>

          <div className="space-y-0 rounded-3xl border border-slate-200 bg-white p-4 text-sm text-slate-700 shadow-inner">
            {menuItems.map((label, index) => (
              <div
                key={label}
                className={`py-3 ${index > 0 ? "border-t border-slate-200" : "pt-1"}`}
              >
                {label}
              </div>
            ))}
          </div>

          <div className="rounded-3xl bg-slate-100 px-4 py-2 text-sm font-medium text-slate-600">
            관리자
          </div>

          <div className="space-y-4">
            {members.map((member) => (
              <div
                key={member.name}
                className="flex items-center gap-3 rounded-2xl border border-slate-200 bg-white px-4 py-3"
              >
                <div className="h-12 w-12 overflow-hidden rounded-full bg-slate-100">
                  <Image
                    src={member.avatar}
                    alt={`${member.name} profile image`}
                    width={48}
                    height={48}
                    className="h-full w-full object-cover"
                  />
                </div>
                <div className="text-sm text-slate-600">
                  <div className="font-semibold text-slate-900">{member.name}</div>
                  <div className="font-mono text-xs text-slate-500">{member.address}</div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
