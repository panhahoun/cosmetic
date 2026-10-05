# Cosmetic E-Commerce App

Flutter app built with GetX and Dio for state management and networking. Features include product browsing, cart, authentication, wishlist, and theme/language switching.

## Features

- GetX architecture (Controllers, Bindings, Views, Routes)
- Dio for API calls with logging
- Authentication (login/register)
- Product catalog with search and categories
- Cart management with local fallback
- Theme (light/dark) and language (English/Khmer)
- Responsive Material 3 UI

## Project Structure

```
lib/
  ├── core/
  │   ├── network/      # Dio client
  │   ├── routes/       # App routes and pages
  │   └── ...
  ├── features/         # Feature-based modules
  │   ├── auth/
  │   ├── home/
  │   ├── cart/
  │   ├── profile/
  │   ├── wishlist/
  │   └── splash/
  ├── models/           # Data models
  └── main.dart
```

## Backend

FastAPI backend is located in `backend/`. See `backend/README.md` for setup instructions.

## UI Palette

Defined once in `lib/config/app_colors.dart`. Keep the interface mostly ivory/white
and use rose only for buttons, selected states, prices and important actions.

| Purpose | Token | Hex |
| --- | --- | --- |
| Primary (rose) | `AppColors.primary` | `#C98F9B` |
| Secondary (soft blush) | `AppColors.secondary` | `#F4E4E7` |
| Background (warm ivory) | `AppColors.background` | `#FCF9F7` |
| Surface / card | `AppColors.surface` | `#FFFFFF` |
| Main text (deep brown) | `AppColors.textPrimary` | `#2D2526` |
| Secondary text (warm gray) | `AppColors.textMuted` | `#7D7374` |
| Accent (champagne gold) | `AppColors.accent` | `#C6A15B` |
| Border (soft beige) | `AppColors.border` | `#E8DDDA` |
| Success (sage green) | `AppColors.success` | `#6F8A72` |
| Error (soft red) | `AppColors.error` | `#C65D63` |
| Bottom nav unselected | `AppColors.navUnselected` | `#A69B9C` |

Do not hardcode `Color(0x...)` in views. Use the tokens above or the `ThemeData`
in `lib/main.dart`, which already wires app bar, cards, bottom navigation,
buttons, inputs and chips.

### Accessibility caveat

`#C98F9B` on white is 2.66:1 and `#A69B9C` on white is 2.70:1 — both below the
WCAG AA 4.5:1 threshold, so white text on primary buttons and unselected
bottom-nav labels are hard to read. `AppColors.primaryPressed` (`#B07683`) and
`AppColors.primaryDark` (`#D8A6B0`) are the accessible alternatives for surfaces
that carry white text.

## Getting Started

1. Get dependencies: `flutter pub get`
2. Run app: `flutter run`
3. Run tests: `flutter test`
4. Analyze: `flutter analyze`

## API Configuration

Default API base points to `http://10.0.2.2:8000/api` for Android emulator. Override via `--dart-define=API_HOST=yourhost`.
