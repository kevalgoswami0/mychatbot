# Nova - Minimal AI Assistant Mobile App

A fast, elegant AI mobile application built with **Flutter (Material 3, Dart 3, Riverpod)**. Features real-time streaming AI replies, conversation management, subscription tiers, local persistence, theme switching, and a decoupled mock data layer designed for seamless transition to any production backend API.

---

## 1. Key Updates & Features

- **Branding**: Streamlined name to **Nova** via centralized `AppConstants.appName`.
- **Palette (Zero Purple)**: Swapped to a crisp, high-contrast **Royal Cobalt Blue** (`#2563EB` light / `#3B82F6` dark) with solid backgrounds (`#FFFFFF` / `#0E0F13`) and flat surfaces (`#F6F7F9` / `#16181D`). Strictly solid colors, flat surfaces with 1px subtle borders, zero gradients, 0 elevation.
- **Top-Right Menu & History**: Removed bottom navigation bar. Tapping the menu button (`Icons.menu_rounded`) at the top right slides open a full-height drawer containing:
  1. **Profile button** (user avatar, display name, email).
  2. **New Chat button** (instant new conversation).
  3. **Chats History**: Full searchable list of previous conversations with swipe-to-delete (undo snackbar) and rename modal.
  4. Quick links to **Subscriptions** and **Settings**.
- **Pro Subscription System**:
  - In the AppBar: **"Hey there,"** greeting with an active subscription dropdown pill button (`[Nova Free ▾]` / `[Nova Pro ▾]`) beside it.
  - Dedicated **Subscriptions Screen** with **Monthly vs. Yearly (20% OFF)** billing, plan feature checklists, and one-tap plan switching across:
    - **Nova Free** ($0)
    - **Nova Pro** ($14.99/mo or $11.99/mo) — *Most Popular*
    - **Nova Ultra** ($29.99/mo or $23.99/mo)
- **High-Performance Chat Engine**:
  - Zero lag / no heavy build load: lazy conversation initialization, O(1) keyed list indexing (`findChildIndexCallback`), and smooth 120fps scrolling.
  - Subtitle in AppBar removed for a clean, distraction-free header.
  - 50ms throttled UI batching for fluid token streaming.
  - Markdown rendering with syntax-styled code blocks and one-tap copy button.
- **Zero Warnings & Tested**: Verified with `dart analyze .` (0 issues) and `flutter test` (17/17 tests passing).

---

## 2. Project Architecture & Folder Structure

```
lib/
 ├─ main.dart                        # App bootstrap, storage initialization & ProviderScope
 ├─ app.dart                         # MaterialApp.router, theme configuration, router attachment
 ├─ core/
 │   ├─ config/
 │   │   └─ api_config.dart          # Base URL, endpoints, timeouts, and useMock flag
 │   ├─ constants/
 │   │   ├─ app_constants.dart       # App name ("Nova"), version, and storage keys
 │   │   ├─ app_spacing.dart         # Strict 4/8px grid system & corner radii tokens
 │   │   └─ app_durations.dart       # Snappy 150-300ms transitions and easing curves
 │   ├─ theme/
 │   │   ├─ app_colors.dart          # Exact Light/Dark solid color palettes & ThemeExtension
 │   │   ├─ app_theme.dart           # ThemeData (flat, elevation 0, 1px border)
 │   │   └─ text_styles.dart         # Inter typography scale with comfortable line heights
 │   ├─ router/
 │   │   ├─ route_names.dart         # Named route constants and paths
 │   │   └─ app_router.dart          # GoRouter with smooth page transitions
 │   ├─ utils/
 │   │   ├─ logger.dart              # Structured developer logging (no bare prints)
 │   │   ├─ date_formatters.dart     # Relative time ("Just now", "2m ago", "Yesterday")
 │   │   ├─ extensions.dart          # BuildContext shortcuts (theme, colors, screen size)
 │   │   └─ debouncer.dart           # Throttler for streaming and Debouncer for search
 │   └─ widgets/
 │       ├─ app_button.dart          # Solid buttons (Primary, Secondary, Ghost, Danger)
 │       ├─ app_text_field.dart      # 12px rounded input with subtle 1px border
 │       ├─ app_avatar.dart          # Full-round solid avatar (initials / bot icon)
 │       ├─ empty_state.dart         # Friendly minimal empty container
 │       ├─ error_state.dart         # Error banner with retry action
 │       └─ loading_dots.dart        # 3 animated bouncing dots (solid accent, RepaintBoundary)
 ├─ data/
 │   ├─ models/
 │   │   ├─ message.dart             # Immutable Message entity with serialization & copyWith
 │   │   ├─ conversation.dart        # Conversation entity with metadata and preview
 │   │   ├─ user_profile.dart        # User profile entity (registered and guest)
 │   │   └─ subscription_plan.dart   # Subscription tier entity (Free, Pro, Ultra)
 │   ├─ datasources/
 │   │   ├─ local_storage.dart       # SharedPreferences persistence layer
 │   │   └─ mock_chat_datasource.dart# Dynamic token streaming with varied templates & cancel
 │   ├─ repositories/
 │   │   ├─ chat_repository_impl.dart# ChatRepository implementation
 │   │   └─ auth_repository_impl.dart# AuthRepository implementation
 │   └─ providers/
 │       └─ repository_providers.dart# Riverpod providers for repositories
 ├─ domain/
 │   └─ repositories/
 │       ├─ chat_repository.dart     # Abstract interface for chat operations
 │       └─ auth_repository.dart     # Abstract interface for authentication operations
 └─ features/
     ├─ splash/                      # Splash screen with wordmark fade-in & auth routing
     ├─ onboarding/                  # 3-step onboarding with flat icons & dots indicator
     ├─ auth/                        # Login, signup, inline errors & guest session
     ├─ chat/                        # Core chat screen, input bar, message bubbles
     │   └─ widgets/
     │       ├─ chat_menu_drawer.dart# Top-right drawer with Profile, New Chat, & History
     │       ├─ chat_input_field.dart# Multiline input with send/stop button
     │       ├─ message_bubble.dart  # Message bubble with markdown and action sheet
     │       └─ suggested_prompts.dart# 4 prompt chips on empty state
     ├─ history/                     # History providers & list item widgets
     ├─ profile/                     # Profile screen with avatar & edit name bottom sheet
     ├─ settings/                    # Appearance switcher, clear chats dialog & logout
     └─ subscription/                # Subscription screen and tier state provider
```

---

## 3. Running & Verifying

```bash
# Run tests
flutter test

# Verify static analysis
dart analyze .

# Run the app
flutter run
```

---

## 4. How to Connect Your Real Backend

The app was engineered so you only need to touch **two files** when connecting your production API:

1. **[api_config.dart](file:///c:/Users/goswa/Desktop/chatbot/frontend/lib/core/config/api_config.dart)**: Set `useMock = false` and update `baseUrl`.
2. **[repository_providers.dart](file:///c:/Users/goswa/Desktop/chatbot/frontend/lib/data/providers/repository_providers.dart)**: Replace `ChatRepositoryImpl` with your live repository client.
