# ClipStake — Complete Swift Recreation Handoff

This document covers everything needed to recreate the ClipStake mobile app end-to-end in Swift (SwiftUI + native iOS). It documents every feature, every screen, the database schema, the API layer, auth, payments, and all required environment variables.

---

## 1. What ClipStake Is

ClipStake is a **creator monetisation platform**. Brands create video-clip campaigns with a USD budget and a CPM rate. Creators ("clippers") submit TikTok/Instagram/YouTube/X video links. A background job tracks view counts on those videos. When a campaign pauses (auto or manual) the brand releases payouts — creators get paid per 1,000 views at the campaign's CPM rate, capped at the campaign budget. Money moves through SideShift (a crypto-to-fiat bridge) and lands in creator bank accounts.

### User Roles
| Role | Description |
|---|---|
| `creator` | Submits clips, earns payouts |
| `org` | Brand/operator — creates campaigns, funds them, releases payouts |
| `agency` | Agency managing multiple brands |
| `admin` | Internal staff, full access |

The mobile app is **creator-only**. Every other role is redirected to the web dashboard. The web app (`apps/web`) is the brand/admin dashboard.

---

## 2. Tech Stack (Existing React Native App)

| Layer | Technology |
|---|---|
| Mobile | React Native + Expo SDK 53 (New Architecture) |
| Router | Expo Router v4 (file-based, tab + stack) |
| API | tRPC v11 over HTTP, superjson serialisation |
| Auth | Better Auth v1 (session cookies) |
| Database | PostgreSQL via Drizzle ORM |
| Payments | SideShift API (crypto deposit → USD payout) |
| File Storage | AWS S3 + optional CloudFront CDN |
| Analytics | PostHog EU |
| Bug Reporting | Linear SDK |
| Logging | Axiom |
| Monorepo | Turborepo + pnpm workspaces |

---

## 3. Monorepo Layout

```
clip-merged/
├── apps/
│   ├── mobile/          ← Expo React Native app (creators)
│   ├── web/             ← Next.js 15 brand dashboard
│   └── tracking/        ← Internal view-tracker admin dashboard
├── packages/
│   ├── api/             ← tRPC router (shared by web + mobile)
│   ├── auth/            ← Better Auth configuration
│   ├── db/              ← Drizzle ORM schema + client
│   ├── storage/         ← AWS S3 helpers
│   ├── payments/        ← SideShift API client
│   ├── analytics-signing/ ← Ed25519 signing for view analytics
│   ├── extractkit/      ← Analytics extraction library
│   ├── ui/              ← Shared React component library
│   └── validators/      ← Shared Zod schemas
└── .env                 ← Root env file (shared by all apps)
```

The API is deployed as a Next.js app at `https://prod.clipstake.com`. Mobile calls `https://prod.clipstake.com/api/trpc/*`.

---

## 4. Environment Variables

All variables are in the root `.env`. The mobile app reads `EXPO_PUBLIC_*` prefixed vars via `apps/mobile/src/env.ts`.

### Required for Production

```
# Database
POSTGRES_URL=postgres://...

# Auth
AUTH_SECRET=<openssl rand -base64 32>
AUTH_GOOGLE_ID=
AUTH_GOOGLE_SECRET=
AUTH_APPLE_ID=
AUTH_APPLE_BUNDLE_ID=
AUTH_APPLE_SECRET=
AUTH_DISCORD_ID=
AUTH_DISCORD_SECRET=
AUTH_URL=https://prod.clipstake.com
DWEB_AUTH_URL=https://prod.clipstake.com

# Email OTP
RESEND_API_KEY=
AUTH_OTP_FROM_EMAIL=ClipStake <auth@clipstake.com>

# Payments
SIDESHIFT_API_KEY=

# AWS S3
AWS_S3_BUCKET=clipstake-uploads
AWS_S3_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_S3_CDN_URL=https://cdn.clipstake.com   # optional CloudFront

# Analytics
NEXT_PUBLIC_POSTHOG_KEY=
NEXT_PUBLIC_POSTHOG_HOST=https://ph.clipstake.com
EXPO_PUBLIC_POSTHOG_KEY=
EXPO_PUBLIC_POSTHOG_HOST=https://eu.i.posthog.com

# Bug reporting (Linear)
LINEAR_API_KEY=
LINEAR_TEAM_ID=7f3fc3c6-5a87-4360-8e04-606dce78d22b

# View tracker
VT_ADMIN_SECRET=
VT_SERVICE_URL=

# Mobile API override (optional — defaults to https://prod.clipstake.com)
EXPO_PUBLIC_API_URL=
EXPO_PUBLIC_USE_LOCAL=false
```

---

## 5. Database Schema

Database: PostgreSQL. ORM: Drizzle. Run migrations with `pnpm db:push` (or `pnpm db:push:staging`). Inspect with `pnpm db:studio` (Drizzle Studio UI).

### 5.1 Auth Tables (Better Auth managed)

**`user`**
```
id            text  PK (nanoid)
name          text
email         text  UNIQUE
username      text  UNIQUE (nullable, set at onboarding)
emailVerified boolean
image         text  (avatar URL)
createdAt     timestamp
updatedAt     timestamp
role          text  DEFAULT 'creator'  -- creator | org | agency | admin
banned        boolean DEFAULT false
banReason     text
banExpires    timestamp
status        text  -- active | deactivated
suspensionReason text  -- e.g. "self_deactivated"
referralCode  text  UNIQUE  -- e.g. "ABC123"
referredById  text  FK→user.id
sideshiftAccountId text  -- SideShift account for this user
```

**`session`**
```
id        text PK
userId    text FK→user.id
token     text UNIQUE
expiresAt timestamp
createdAt timestamp
updatedAt timestamp
ipAddress text
userAgent text
```

**`account`** (OAuth provider accounts)
```
id                  text PK
accountId           text  (provider's user ID)
providerId          text  (google|apple|discord|credential)
userId              text FK→user.id
accessToken         text
refreshToken        text
idToken             text
expiresAt           timestamp
password            text
```

**`verification`** (email OTP tokens)
```
id         text PK
identifier text  (email address)
value      text  (the OTP code)
expiresAt  timestamp
```

### 5.2 Campaign Tables

**`campaign`**
```
id                   uuid PK
userId               text FK→user.id  (brand owner)
brandId              uuid FK→brand.id
title                text
description          text
status               enum: draft|active|paused|completed|cancelled
budgetCents          integer
remainingBudgetCents integer
cpmCents             integer  (cost per 1000 views, in cents)
maxPayoutPerVideo    integer  (cents cap per submission)
pauseThresholdPercent integer  (auto-pause when accrued % of remaining budget)
endsAt               timestamp
thumbnail            text  (S3 key)
category             text  (e.g. "Clipping")
platforms            text[]  -- tiktok|instagram|youtube|twitter
submissionCount      integer DEFAULT 0
totalViewCount       integer DEFAULT 0
createdAt            timestamp
updatedAt            timestamp
```

**`campaign_platform`** — which platforms the campaign accepts
```
id         uuid PK
campaignId uuid FK→campaign.id
platform   enum: tiktok|instagram|youtube|twitter
```

**`campaign_resource`** — downloadable assets (brief, video files)
```
id         uuid PK
campaignId uuid FK→campaign.id
type       text
url        text
name       text
```

**`campaign_cpm_bucket`** — tiered CPM by view count range
```
id         uuid PK
campaignId uuid FK→campaign.id
minViews   integer
maxViews   integer  (nullable = unlimited)
cpmCents   integer
```

**`campaign_cpm_bucket_country`** — geo-specific CPM override
```
id       uuid PK
bucketId uuid FK→campaign_cpm_bucket.id
country  text  (ISO 2-letter)
cpmCents integer
```

**`campaign_draft`** — autosave draft for campaigns being created
```
id      uuid PK
userId  text FK→user.id
data    jsonb  (partial campaign fields)
```

### 5.3 Submission Tables

**`submission`**
```
id               uuid PK
campaignId       uuid FK→campaign.id
userId           text FK→user.id  (creator)
videoId          text UNIQUE  (platform video ID)
submissionCode   varchar(16)  (nullable)
platform         enum: tiktok|instagram|youtube|twitter
status           enum: pending|approved|rejected|not_qualified|paid
views            integer DEFAULT 0
payoutCents      integer DEFAULT 0  (cumulative net paid so far)
reviewNote       text
isFlagged        boolean DEFAULT false
vtProcessing     boolean DEFAULT false
lastViewCountUpdatedAt timestamp
nextViewUpdate   timestamp
retryCount       integer DEFAULT 0
postedAt         timestamp
videoDuration    integer  (seconds)
description      text
hashtags         text[]
thumbnailUrl     text
likesCount       integer
commentsCount    integer
sharesCount      integer
bookmarksCount   integer
socialAccountId  uuid FK→social_account.id
createdAt        timestamp
updatedAt        timestamp
```

Unique constraint: `submission_video_id_uniq` on `videoId`. This is how duplicate submissions are detected.

**`social_account`** — scraped platform profile
```
id                uuid PK
platform          enum: tiktok|instagram|youtube|twitter
username          text
displayName       text
profilePictureUrl text
biography         text
UNIQUE(platform, username)
```

### 5.4 Payout / Snapshot Tables

**`campaign_pause_snapshot`** — frozen state when a campaign pauses
```
id                    uuid PK
campaignId            uuid FK→campaign.id
reason                enum: auto_budget|manual
pauseThresholdPercent integer
budgetCents           integer
remainingBudgetCents  integer
totalUnpaidGrossCents integer
createdAt             timestamp
```

**`campaign_pause_snapshot_submission`** — per-submission frozen view/gross at pause
```
id                     uuid PK
snapshotId             uuid FK→campaign_pause_snapshot.id
submissionId           uuid FK→submission.id
views                  integer
grossCents             integer
netCents               integer  (gross - 15% fee)
lastViewCountUpdatedAt timestamp
distributedGrossCents  integer  (nullable — what would be paid from this snapshot's pool)
distributedNetCents    integer  (nullable)
proportional           boolean  (true = this submission was in the tripping batch, scaled down)
UNIQUE(snapshotId, submissionId)
```

**`campaign_payout_release`** — audit record for each release event
```
id              uuid PK
campaignId      uuid FK→campaign.id
snapshotId      uuid FK→campaign_pause_snapshot.id
attemptId       uuid  (idempotency)
totalGrossCents integer
totalNetCents   integer
feeTotalCents   integer
releasedCount   integer
createdAt       timestamp
```

### 5.5 Ledger / Payment Tables

The internal ledger is double-entry. All money moves are atomic DB transactions. SideShift is only touched at two real boundaries: deposit-in and withdrawal-out.

**`internal_account`** — one running balance per (kind, owner)
```
id           uuid PK
kind         enum: campaign|user_wallet|creator_owed|referrer_owed|company_revenue
ownerId      text  (campaign.id or user.id; sentinel value for company_revenue singleton)
balanceCents integer DEFAULT 0  -- CHECK >= 0
currency     text DEFAULT 'usd'
UNIQUE(kind, ownerId)
```

**`ledger_entry`** — double-entry money movement
```
id                   uuid PK  (also the SideShift idempotencyKey for boundary legs)
kind                 enum: deposit|campaign_fund|platform_fee|payout|payout_fee|referral|withdraw|company_sweep
status               enum: pending|confirmed|failed  DEFAULT confirmed
fromAccountId        uuid FK→internal_account.id  (null = custody boundary in)
toAccountId          uuid FK→internal_account.id  (null = custody boundary out)
amountCents          integer  CHECK > 0
grossCents           integer  (nullable — set only on payout entries)
currency             text DEFAULT 'usd'
attemptKey           text  UNIQUE(kind, attemptKey)
refType              enum: campaign|submission|release|user
refId                text
sideshiftTransferId  text  UNIQUE where not null
sideshiftEventId     text
description          text
occurredAt           timestamp
```

**`campaign_transaction`** (legacy — pre-ledger campaigns, still read for history)
```
id                  uuid PK
campaignId          uuid FK→campaign.id
kind                enum: transfer_in|platform_fee_out|payout_out|payout_fee_out|referral_out|withdraw
status              enum: pending|confirmed|failed
attemptKey          text
amountCents         integer
grossCents          integer  (payout_out rows only)
payoutReleaseId     uuid FK→campaign_payout_release.id
submissionId        uuid FK→submission.id
sideshiftTransferId text  UNIQUE where not null
description         text
UNIQUE(campaignId, kind, attemptKey)
```

**`wallet_transaction`** — user crypto deposits
```
id                  uuid PK
userId              text FK→user.id
kind                enum: deposit
status              enum: pending|confirmed|failed
amountCents         integer
feeCents            integer DEFAULT 0
netAmountCents      integer
currency            text
sideshiftDepositId  text UNIQUE
sideshiftEventId    text
occurredAt          timestamp
```

**`referral_earning`** — referral commission ledger (creator refers creator, earns 1% of their payouts for 12 months)
```
id                  uuid PK
referrerId          text FK→user.id
refereeId           text FK→user.id
kind                enum: clipper_payout
status              enum: pending|paid|failed
rateBps             integer  (100 = 1%)
baseAmountCents     integer
amountCents         integer  (floor(base * rate / 10000))
currency            text
sourceTransactionId uuid FK→campaign_transaction.id
idempotencyKey      text UNIQUE
sideshiftTransferId text
description         text
```

**`webhook_event`** — SideShift inbound webhook deduplication
```
id          uuid PK
provider    enum: sideshift
eventId     text
eventType   text
receivedAt  timestamp
processedAt timestamp
payload     jsonb
UNIQUE(provider, eventId)
```

### 5.6 Brand / Org Tables

**`brand`**
```
id           uuid PK
userId       text FK→user.id  (owner)
name         varchar(256)
description  text
websiteUrl   text
logoPath     text  (S3 key)
primaryColor varchar(32)
status       enum: active|inactive DEFAULT active
UNIQUE(userId, name)
```

### 5.7 Miscellaneous Tables

**`signing_key`** — device analytics signing keys (Ed25519)
```
id         uuid PK
userId     text FK→user.id
publicKey  text UNIQUE
status     enum: active|revoked
```

**`signing_nonce`** — one-time nonces for analytics upload
```
id        uuid PK
keyId     uuid FK→signing_key.id
nonce     text UNIQUE
usedAt    timestamp
expiresAt timestamp
```

**`view_log`** — raw view count snapshots per submission
```
id           uuid PK
submissionId uuid FK→submission.id
views        integer
recordedAt   timestamp
```

**`submission_analytics_extraction`** — analytics extraction results
```
id           uuid PK
submissionId uuid FK→submission.id
data         jsonb
createdAt    timestamp
```

**`post`** — creator-facing posts/announcements
```
id        uuid PK
title     text
body      text
platform  enum: tiktok|instagram|youtube|twitter (nullable)
createdAt timestamp
```

**`impersonation_token_use`** — admin impersonation audit log
```
id          uuid PK
adminId     text
targetId    text
usedAt      timestamp
```

**`clipper_list`** — curated lists of creator accounts
```
id        uuid PK
name      text
platform  enum
usernames text[]
createdAt timestamp
```

**`country`** — ISO country reference data
```
code text PK  (ISO 3166-1 alpha-2)
name text
```

---

## 6. Authentication

**Library:** Better Auth v1 (`better-auth` npm package)  
**Strategy:** Session-based with HTTP cookies  
**Providers:** Google OAuth, Apple Sign In, Discord OAuth, Email OTP  

### Auth Flow (Mobile)

1. User taps "Sign in with Google/Apple/Discord" or enters email
2. Better Auth handles OAuth redirect (Google/Apple/Discord) or sends OTP via Resend
3. On success, a session cookie is stored in iOS SecureStore via `expo-secure-store`
4. All subsequent API calls include `Cookie: <session>` header

### Session Injection (Mobile → API)

The mobile app uses a custom fetch wrapper that:
- Reads the stored cookie via `authClient.getCookie()`
- Sets `Cookie: <value>` header on every tRPC request
- Sets `expo-origin: clipstake://` header (Better Auth CSRF bypass for native apps)
- Uses `credentials: "omit"` to prevent iOS NSURLSession from stripping manual Cookie headers

### Auth Client Setup

```swift
// In Swift, you'll replicate this with URLSession:
// 1. After login, store the Set-Cookie response header in Keychain
// 2. On every API request, attach Cookie: <stored-cookie>
// 3. Also attach headers:
//    x-trpc-source: swift-native
//    expo-origin: clipstake://
```

### Better Auth Endpoints

All under `https://prod.clipstake.com/api/auth/`:
- `POST /sign-in/social` — OAuth (Google/Apple/Discord)
- `POST /email-otp/send-verification-otp` — send OTP email
- `POST /email-otp/verify-email` — verify OTP
- `GET /get-session` — fetch current session
- `POST /sign-out` — invalidate session

### Email OTP Special Case (App Store Review)
Email `reviewer@clipstake.com` always accepts OTP `111111` without sending a real email.

### Role Gating (Mobile)
After login, the app calls `authClient.getSession()`. If `user.role !== "creator"`, the user is shown a "creator-only" screen and cannot proceed. All users are `creator` by default; the `org`/`agency`/`admin` roles are set server-side.

### Account Status
- Active accounts: `status = "active"`
- Deactivated: `status = "deactivated"`, `suspensionReason = "self_deactivated"`. All sessions deleted. Data preserved. User cannot log in.

---

## 7. API Layer (tRPC)

**URL:** `https://prod.clipstake.com/api/trpc`  
**Transport:** HTTP POST (batched)  
**Serialisation:** superjson (handles Date, BigInt, etc.)  

### tRPC Routers

| Router | Description |
|---|---|
| `auth` | Session management, account deactivation |
| `brand` | Brand CRUD |
| `bug` | Bug reporting → Linear |
| `campaign` | Campaign CRUD, funding, pausing, releasing payouts |
| `clipper` | Creator profile + earnings data |
| `clipper-list` | Curated creator lists |
| `dashboard` | Analytics aggregates |
| `onboarding` | Username setup, referral code redemption |
| `post` | Platform announcements |
| `referral` | Referral overview + list |
| `settings` | User settings |
| `signing` | Analytics signing key management |
| `submission` | Submit clip, list submissions, approval flow |
| `tracking` | View-tracker admin |
| `transaction` | Wallet/campaign transaction history |
| `upload` | S3 presigned URL generation |
| `user` | Profile read/update |
| `webhook` | SideShift inbound webhook handler |
| `analytics` | PostHog bridge |
| `dev` | Dev-only tools |

### Key Procedures Used by Mobile

**Onboarding**
- `onboarding.completeProfile` — set username, referral code, role confirmation

**Campaigns**
- `campaign.list` — paginated list of active campaigns (home screen)
- `campaign.getById` — single campaign detail
- `campaign.search` — search/filter campaigns

**Submissions**
- `submission.submit` — submit a video URL to a campaign
- `submission.list` — creator's submissions across all campaigns
- `submission.getBySubmissionId` — single submission detail

**Referrals**
- `referral.getOverview` — `{ code, totalReferrals, totalEarningsCents }`
- `referral.listReferrals` — list of referred users with earnings

**Profile / Wallet**
- `user.getProfile` — username, name, email, avatar, role
- `campaign.loadUserBalanceBreakdown` — `{ userWalletCents, creatorOwedCents, referrerOwedCents }`
- `transaction.listForUser` — wallet transaction history

**Settings**
- `auth.deactivateAccount` — soft-delete (sets status = deactivated)
- `user.updateProfile` — name, avatar upload
- `settings.updateNotifications` — push prefs

**Bug Reporting**
- `bug.report` — description + up to 3 base64 screenshots → Linear issue

**Signing (Analytics)**
- `signing.registerKey` — register Ed25519 public key
- `signing.getActiveKey` — fetch currently active key
- `signing.requestNonce` — one-time nonce for payload signing

### tRPC Request Format

```
POST https://prod.clipstake.com/api/trpc/campaign.list,submission.list
Content-Type: application/json
Cookie: better-auth.session_token=<token>
expo-origin: clipstake://
x-trpc-source: expo-react

[
  {"id":0,"method":"query","params":{"path":"campaign.list","input":{"0":{"json":{...}}}}},
  {"id":1,"method":"query","params":{"path":"submission.list","input":{"0":{"json":{...}}}}}
]
```

---

## 8. Mobile App Screens

### Navigation Structure
```
/ (Stack)
├── /login              ← Sign In screen (Google, Apple, Discord, Email OTP)
├── /onboarding/        ← Onboarding flow (username setup, role confirmation)
└── /(tabs)/            ← Tab bar (creators only)
    ├── home            ← Campaign marketplace
    ├── workspace       ← Creator's submissions + earnings
    ├── profile         ← Profile, wallet balance
    └── index           ← Feed / My submissions dashboard
```

Additional stack screens (pushed from tabs):
```
/campaign/[id]          ← Campaign detail + submission form
/submission/[id]        ← Single submission detail
/settings               ← Settings
/referrals              ← Referral code + earnings
/wallet                 ← Wallet balance + transaction history
/bookmarks              ← Bookmarked campaigns
/private-campaigns      ← Invite-only campaigns
/notifications          ← Notification history (currently disabled)
/post/[id]              ← Platform announcement post
```

### Screen Details

#### Login (`/login`)
- Google Sign In button (calls `authClient.signIn.social({ provider: "google" })`)
- Apple Sign In button (calls `authClient.signIn.social({ provider: "apple" })`)  
- Discord Sign In button
- Email OTP: enter email → enter 6-digit code
- On success: check role → if not creator, block with message → else navigate to `/(tabs)/home`

#### Onboarding (`/onboarding/`)
- Step 1: Set username (unique, alphanumeric + underscores)
- Step 2: Optional referral code
- Step 3: Role confirmation (mobile = creator only)
- Calls `onboarding.completeProfile`

#### Home Tab (`/(tabs)/home`)
- Fetches paginated campaigns via `campaign.list`
- Campaign cards show: thumbnail, brand logo, title, platforms (TikTok/Instagram/YouTube/X icons), CPM label, budget progress bar, end date
- Pull-to-refresh
- Infinite scroll (PAGE_SIZE = 5)
- Tapping a card → `/campaign/[id]`

#### Campaign Detail (`/campaign/[id]`)
- Campaign header with brand logo, title, status badge
- Description, platforms, requirements brief
- Submit form: paste video URL (TikTok, Instagram Reels, YouTube Shorts, X)
- Submit button → calls `submission.submit({ campaignId, videoUrl })`
- Duplicate video detection: if error has PG constraint `submission_video_id_uniq`, shows "You've already submitted this video" message inline (not an alert)
- Shows list of creator's existing submissions for this campaign

#### Workspace Tab (`/(tabs)/workspace`)
- Lists all the creator's submissions (any campaign, any status)
- Grouped by campaign
- Status chips: pending (yellow) | approved (green) | rejected (red) | paid (mint/teal)
- Each row shows: thumbnail, view count, payout amount, status

#### Profile Tab (`/(tabs)/profile`)
- Avatar (loads from `user.image` — S3 URL)
- Username, name, email
- Wallet balance card: `userWalletCents + creatorOwedCents + referrerOwedCents`
- Menu items: Referrals, Settings, Help & Support, Sign Out

#### Referrals (`/referrals`)
- Mint gradient card showing referral code with Copy + Share buttons
- Stats: total referrals, total earnings
- List of referred users with name, username, role, date, earnings
- Share generates: `https://clipstake.com/onboarding?ref=<CODE>`
- Module-level cache (`_cachedOverview`, `_cachedReferrals`) cleared on logout

#### Settings (`/settings`)
- Profile edit (name, avatar)
- Notification preferences
- Theme toggle (auto/light/dark)
- Sign out

#### Help & Support (bottom sheet)
Options:
1. **Book a call** → opens Calendly link
2. **Send a message** → 100-char text field → sends support message
3. **Deactivate account** → type username to confirm → calls `auth.deactivateAccount` → clears all caches → signs out

#### Bug Report (bottom sheet — accessible from profile/settings)
- Text description (max 500 chars)
- Attach up to 3 screenshots from photo library (JPEG/PNG, base64 encoded)
- Submit → `bug.report({ description, attachments })` → images uploaded to S3 `bug-reports/<uuid>.<ext>` → Linear issue created with reporter name/email/username
- Linear team: "Bugs" (ID: `7f3fc3c6-5a87-4360-8e04-606dce78d22b`)

---

## 9. Payments System (SideShift)

SideShift is a crypto exchange. ClipStake uses it as a payment rail:
- Brands deposit USDC/USDT/etc. → SideShift converts to USD → ClipStake internal ledger credits the brand's `user_wallet` account
- Creators withdraw USD → SideShift sends to their connected bank account

### Key SideShift Concepts
- Each user gets a SideShift **account** (`user.sideshiftAccountId`) on registration
- Deposits arrive via SideShift's iframe embed on the web dashboard
- Withdrawals are initiated via the web dashboard (not mobile currently)
- SideShift sends webhooks to `POST /api/trpc/webhook.sideshift` — these confirm deposits and withdrawals and update the internal ledger

### Creator Payout Flow
1. Brand creates campaign, funds it with USD balance
2. View-tracker (Go service) watches video URLs, updates `submission.views`
3. When accrued payout value crosses `pauseThresholdPercent` of remaining budget → campaign auto-pauses
4. Brand logs into web dashboard → sees "Release Payouts" button → clicks it
5. `campaign.releaseAllPayouts` distributes the budget to creators proportionally
6. Each creator's `creator_owed` internal account is credited
7. Creator initiates withdrawal from web dashboard → SideShift sends to bank

---

## 10. File Storage (AWS S3)

Bucket: `clipstake-uploads` (US East 1)  
CDN: Optional CloudFront at `AWS_S3_CDN_URL`

### Key S3 Paths
| Path Pattern | Content |
|---|---|
| `avatars/<userId>.<ext>` | User avatar images |
| `campaign-thumbnails/<campaignId>.<ext>` | Campaign thumbnail images |
| `campaign-resources/<campaignId>/<filename>` | Campaign brief/assets |
| `brand-logos/<brandId>.<ext>` | Brand logo images |
| `bug-reports/<uuid>.<ext>` | Bug report screenshots |

### Upload Flow (Mobile)
1. Mobile picks image from library (`expo-image-picker`)
2. Calls `upload.getPresignedUrl` → gets S3 presigned PUT URL
3. Mobile `PUT`s the file directly to S3 (no server in the middle for user uploads)
4. Mobile sends the resulting S3 key/URL to the API to save on the user/campaign record

---

## 11. Analytics

**Library:** PostHog EU  
**Key:** `EXPO_PUBLIC_POSTHOG_KEY` (starts with `phc_`)  
**Host:** `https://eu.i.posthog.com` (mobile talks direct, no proxy)  

### Analytics Signing
View analytics uploads use Ed25519 signing to prevent fake view injection:
1. Device generates Ed25519 keypair on first use
2. Private key stored in iOS Keychain/SecureStore (never leaves device)
3. Public key registered via `signing.registerKey`
4. Each analytics payload is signed: `nonce + timestamp + canonicalize(payload)`
5. Server verifies signature with stored public key before accepting data

---

## 12. Mobile-Specific Implementation Details

### URL Scheme
`clipstake://` — used for OAuth deep links and Better Auth expo plugin

### Bundle ID
- iOS: `com.clipstake.app`
- Android: `com.clipstake.app`

### EAS Project ID
`1da75801-9467-478c-a6a3-0266d5311f2d`

### Over-the-Air Updates
Expo Updates enabled at: `https://u.expo.dev/1da75801-9467-478c-a6a3-0266d5311f2d`  
Runtime version: `1.0.0`

### Theme System
The app supports light/dark/auto themes. Theme tokens come from `@bedrock/tailwind-config/tokens` (`palette`, `fonts`, `radius`, `space`). Key color tokens:
- `colors.bg` / `colors.bgSecondary` / `colors.bgCard` — backgrounds
- `colors.text` / `colors.textSecondary` / `colors.textTertiary` — text
- `colors.accent` — primary action color (red/coral)
- `colors.accentDark` — darker variant
- `colors.success` — green for earnings
- `colors.border` / `colors.borderSecondary` — borders
- `colors.bgAccent` — tinted background for icons
- `palette.mint[500/600]` — referral code card gradient

### Session Cache Invalidation on Logout
The following module-level caches must be cleared on logout and account deactivation:
1. `resetAvatarCache()` — avatar URLs
2. `resetSubmissionsCache()` — workspace submissions
3. `clearCampaignPreviews()` — campaign card data
4. `resetWorkspaceCaches()` (lazy import from workspace screen)
5. `resetCampaignCaches()` (lazy import from campaign detail screen)
6. `resetReferralCache()` (lazy import from referrals screen)
7. `clearFavourites()` — SecureStore bookmarks
8. `Image.clearDiskCache()` + `Image.clearMemoryCache()` — expo-image

In Swift, replicate this by notifying all view models to clear their state on `NotificationCenter` post or via a global `SessionManager`.

### Platforms / Video URL Validation
Supported submission platforms: `tiktok`, `instagram`, `youtube`, `twitter`  
The submission router validates the video URL matches the expected platform domain before creating the submission.

### Submission Deduplication
The `videoId` field on `submission` has a `UNIQUE` constraint (`submission_video_id_uniq`). When a creator submits a video URL already in the database (any campaign), the insert fails with PG error code `23505` and constraint name `submission_video_id_uniq`. The mobile app catches this and shows an inline error message below the URL input, not a modal alert.

---

## 13. Web App (Brand Dashboard)

URL: `https://obsidian.clipstake.com`  
Framework: Next.js 15 App Router  
Same tRPC API, same Better Auth session system.

### Brand Flow
1. Sign up / log in (Google/Discord/Email OTP)
2. Create brand profile (name, logo, colors)
3. Create campaign (title, description, budget, CPM, platforms, end date, thumbnail)
4. Share campaign link with creators
5. Monitor submissions: approve/reject/flag
6. Release payouts when campaign pauses
7. Withdraw remaining budget

---

## 14. Infrastructure

| Service | Purpose |
|---|---|
| Vercel | Hosts web + API (Next.js) |
| Neon / Supabase | PostgreSQL database |
| AWS S3 | File storage |
| SideShift | Payment rail |
| Linear | Bug tracking |
| PostHog EU | Analytics |
| Axiom | Server-side logging |
| Resend | Transactional email (OTP) |
| Go Lambda | View-tracker (watches video URLs, updates view counts) |

---

## 15. Swift Recreation Notes

### Architecture Recommendation
- **SwiftUI** for all UI
- **Swift Concurrency** (async/await) for all async operations
- **Observation framework** (`@Observable`) for view models — iOS 17+ or `@ObservableObject` for iOS 15+
- **URLSession** for all network requests with a custom session that injects the auth cookie + required headers
- **Keychain** (via `Security` framework or `KeychainAccess` pod) instead of SecureStore
- **MVVM** pattern with a `SessionManager` singleton for auth state

### tRPC Client in Swift
tRPC is just POST over HTTP with JSON. You don't need a Swift tRPC library — implement a thin `APIClient`:

```swift
struct TRPCClient {
    let baseURL = URL(string: "https://prod.clipstake.com/api/trpc")!
    
    func query<T: Decodable>(_ path: String, input: Encodable?) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        // ... attach cookie, expo-origin header
        // Body: {"0":{"json":<input>}}
        // Response: {"result":{"data":{"json":<T>}}}
    }
}
```

The response envelope from tRPC with superjson is:
```json
[{"result":{"data":{"json":<the actual data>,"meta":{...}}}}]
```

Dates come back as ISO strings when using superjson (superjson encodes Date as `{"json":"2024-01-01T...","meta":{"values":{"":["Date"]}}}` — you'll need to handle this or ask the API team to switch to a simpler transformer).

### Auth in Swift
1. After login, extract `Set-Cookie` from Better Auth response
2. Store in Keychain: `better-auth.session_token=<value>`
3. On every request, attach: `Cookie: better-auth.session_token=<value>`

### Key Libraries to Replace
| Expo/RN library | Swift equivalent |
|---|---|
| `expo-secure-store` | Keychain Services |
| `expo-image-picker` | `PHPickerViewController` |
| `expo-clipboard` | `UIPasteboard` |
| `expo-image` | `AsyncImage` or `Kingfisher` |
| `expo-linear-gradient` | SwiftUI `LinearGradient` |
| `@gorhom/bottom-sheet` | Custom sheet or `UISheetPresentationController` |
| `react-native-safe-area-context` | `.safeAreaInset()` |
| `expo-router` | SwiftUI `NavigationStack` |
| PostHog RN SDK | PostHog iOS SDK |
| `react-native-svg` | SwiftUI `Canvas` / SF Symbols |

---

## 16. Critical Business Rules

1. **15% platform fee** — taken at campaign funding time AND at payout release time
2. **1% referral commission** — creator earns 1% of every referred creator's payout for their first 12 months; carved out of the 15% release fee (brand doesn't pay extra)
3. **CPM cap** — `maxPayoutPerVideo` limits how much any single submission can earn regardless of view count
4. **Auto-pause** — campaign automatically pauses when accrued payout value reaches `pauseThresholdPercent`% of remaining budget
5. **Proportional distribution** — when a campaign pauses mid-batch, submissions in the tripping batch get proportional shares of the remaining pool; earlier batches are paid in full first
6. **Incremental top-ups** — brands can add budget while paused; the next release only pays the delta not already paid
7. **Unique video constraint** — one video URL can only ever be submitted once across the entire platform
8. **Submission status flow**: `pending` → `approved` → `paid` or `rejected` / `not_qualified`
9. **No double-payout** — each payout release uses an `attemptKey` idempotency key; retries within the same release click are safe

---

## 17. Contact / Access

- **GitHub:** github.com/ClipStake (org)
- **Linear:** Bug tickets go to team ID `7f3fc3c6-5a87-4360-8e04-606dce78d22b`
- **Vercel:** Production at `prod.clipstake.com` (API) and `obsidian.clipstake.com` (web)
- **EAS (Expo):** Project `1da75801-9467-478c-a6a3-0266d5311f2d`
- **DB Studio:** Run `pnpm db:studio` in the repo to open Drizzle Studio (visual DB browser)
- **Logs:** Axiom dashboard — filter by `NEXT_PUBLIC_AXIOM_DATASET`
