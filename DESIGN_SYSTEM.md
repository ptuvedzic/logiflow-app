# LogiFlow Design System

## 1. Purpose and authority

This document is the mandatory visual and responsive standard for every current and future LogiFlow V1 screen. New screens must reuse these tokens, components, and page patterns so they look and behave as part of the same product.

Authority order:

1. Approved screenshots define composition and visual intent.
2. This document defines reusable visual and responsive rules.
3. `PRD.md` defines product behavior and role permissions.
4. `ARCHITECTURE.md` defines frontend boundaries and implementation patterns.

When no approved screenshot exists, follow this design system and reuse established page patterns. Do not invent a new visual language or unrelated product behavior. Screenshots are references, not substitutes for reusable components.

## 2. Design direction

LogiFlow is a modern enterprise dashboard: business-first, functional, information-dense, and visually restrained. Clear hierarchy, warm neutral surfaces, thin borders, consistent components, and semantic operational feedback take precedence over decoration.

Mandatory principles:

- Orange is the only brand color.
- Semantic colors communicate operational states; purple is limited to approved analytical metrics.
- Cards and other permanent surfaces use borders and background contrast, not shadows.
- Motion is minimal and functional.
- Desktop tables are primary data surfaces.
- Admin and Dispatcher workflows are desktop-first.
- Driver workflows are mobile-first and remain usable on desktop.
- Status is always communicated with text, not color alone.
- V1 is light theme only. Do not add dark mode or dark-theme variants.

Prohibited treatments:

- Glassmorphism, neumorphism, decorative gradients, heavy shadows, and decorative animation
- Arbitrary colors, spacing, radii, font sizes, or one-off component styling
- Purple, blue, green, yellow, or red used as additional brand colors
- Page-specific duplicates of shared components
- Redesigning an approved screen without explicit approval

## 3. Brand

The product name is **LogiFlow**. Retain the existing wordmark: “Logi” uses the primary text color and “Flow” uses primary orange. Use only the light-theme logo in V1. Never distort, recolor, outline, shadow, or otherwise apply effects to it, and do not create a dark-logo variant.

## 4. Foundation tokens

Semantic CSS variables and corresponding semantic Tailwind utilities are implementation contracts. Do not use arbitrary color literals when a token exists.

### 4.1 Color tokens

| Purpose | CSS variable | Value | Tailwind token |
| --- | --- | --- | --- |
| Application background | `--background-app` | `#F7F3ED` | `bg-background-app` |
| Sidebar background | `--background-sidebar` | `#E9E5DD` | `bg-background-sidebar` |
| Card background | `--background-card` | `#FFFFFF` | `bg-background-card` |
| Hover background | `--background-hover` | `#F8F8F8` | `bg-background-hover` |
| Primary | `--primary` | `#FF6209` | `bg-primary`, `text-primary`, `border-primary` |
| Primary hover | `--primary-hover` | `#FF5C00` | `bg-primary-hover` |
| Active primary background | `--primary-active-background` | `rgba(255, 98, 9, 0.50)` | `bg-primary-active` |
| Primary icon | `--primary-icon` | `#FF6209` | `text-primary-icon` |
| Soft primary | `--primary-soft` | `rgba(255, 98, 9, 0.15)` | `bg-primary-soft` |
| Primary text on solid | `--primary-text-on-solid` | `#FFFFFF` | `text-primary-text-on-solid` |
| Analytics purple | `--analytics-purple` | `#8B5CF6` | `text-analytics-purple`, `bg-analytics-purple` |
| Soft analytics purple | `--analytics-purple-soft` | `rgba(139, 92, 246, 0.15)` | `bg-analytics-purple-soft` |
| Primary text | `--text-primary` | `#111111` | `text-foreground` |
| Secondary text | `--text-secondary` | `#454545` | `text-secondary` |
| Muted text | `--text-muted` | `#8F8F8F` | `text-muted` |
| Placeholder text | `--text-placeholder` | `#B8B8B8` | `placeholder:text-placeholder` |
| Text on primary | `--text-on-primary` | `#FFFFFF` | `text-on-primary` |
| Danger text | `--text-danger` | `#FF0000` | `text-danger-alert` |
| Default border | `--border-default` | `#DDD9D2` | `border-border` |
| Subtle border | `--border-subtle` | `#E7E3DC` | `border-border-subtle` |
| Input border | `--border-input` | `#CFCFCF` | `border-input` |
| Strong border | `--border-strong` | `#B8B8B8` | `border-border-strong` |

`--primary-text-on-solid` is the component-level token for text and icons placed directly on solid primary-orange surfaces, including Primary Button content and approved solid-primary controls. Its semantic token name is `primary-text-on-solid`, and its permitted generated utility includes `text-primary-text-on-solid`.

`--text-on-primary` is the general semantic text token for readable content on a primary-colored background and may be used by higher-level semantic component variants. Its semantic token name is `text-on-primary`, and its permitted generated utility includes `text-on-primary`.

The active sidebar item uses the approved warm-orange treatment. If the specified 50% background compromises legibility, preserve its visual intent while adjusting the treatment to achieve WCAG AA contrast. Purple is for distance, revenue, and explicitly approved analytical metrics only; it is never a primary-action color.

### 4.2 Semantic colors

These named variables and corresponding Tailwind tokens are mandatory contracts:

```css
--success: #22C55E;
--success-soft: rgba(34, 197, 94, 0.15);
--success-border: #22C55E;

--warning: #C9EB05;
--warning-soft: rgba(201, 235, 5, 0.15);
--warning-border: #C9EB05;
--warning-text: #454545;

--danger: #EB0505;
--danger-soft: rgba(235, 5, 5, 0.15);
--danger-border: #EB0505;

--info: #3B82F6;
--info-soft: rgba(59, 130, 246, 0.15);
--info-border: #3B82F6;

--neutral: #8F8F8F;
--neutral-border: #B8B8B8;
```

Semantic token names generate context-specific Tailwind utilities; utility prefixes are not separate design tokens. For example, the `success-soft` token is consumed as `bg-success-soft`, while `success` and `success-border` are consumed as `text-success` and `border-success-border`.

| CSS variable | Semantic token name | Permitted Tailwind utility contexts | Intended usage |
| --- | --- | --- | --- |
| `--success` | `success` | `text-success` | Success badge text/icons and successful operational state content |
| `--success-soft` | `success-soft` | `bg-success-soft` | Success badge and state backgrounds |
| `--success-border` | `success-border` | `border-success-border` | Success badge and state borders |
| `--warning` | `warning` | `text-warning` | Warning icons and approved warning state accents |
| `--warning-soft` | `warning-soft` | `bg-warning-soft` | Warning badge and state backgrounds |
| `--warning-border` | `warning-border` | `border-warning-border` | Warning badge and state borders |
| `--warning-text` | `warning-text` | `text-warning-text` | Readable dark text on bright warning treatments |
| `--danger` | `danger` | `text-danger`, `bg-danger`, `border-danger` | Danger badge text/icons, destructive buttons, danger borders, and critical operational treatments |
| `--danger-soft` | `danger-soft` | `bg-danger-soft` | Danger badge and state backgrounds |
| `--danger-border` | `danger-border` | `border-danger-border` | Danger badge and state borders |
| `--text-danger` | `danger-alert-text` | `text-danger-alert` | Approved alert/error copy using the dedicated Alert Text typography style only |
| `--info` | `info` | `text-info`, `bg-info`, `border-info` | Information text/icons, focus borders, and active-transport accents |
| `--info-soft` | `info-soft` | `bg-info-soft`, ring-color context | Information badge backgrounds and focus rings |
| `--info-border` | `info-border` | `border-info-border` | Information badge and state borders |
| `--neutral` | `neutral` | `text-neutral` | General neutral accents where approved; not neutral badge text |
| `--neutral-border` | `neutral-border` | `border-neutral-border` | General neutral borders where approved; not neutral badge borders |

Neutral badges use the existing `--background-hover`, `--border-strong`, and `--text-secondary` tokens. Warning treatments use dark warning text, never white.

`--danger: #EB0505` is used for semantic Danger components, form-validation borders, icons, and inline messages, destructive buttons, danger borders, danger icons, and critical operational state treatments. `--text-danger: #FF0000` is reserved exclusively for approved alert/error copy using the dedicated Alert Text typography style; ordinary input validation does not use it.

Do not create arbitrary status colors. Every state includes a visible canonical label and may include an icon.

### 4.3 Typography

SF Pro font files are not required by LogiFlow. The implementation uses the approved system-first font stack. The project must not depend on bundled private SF Pro font files for correct rendering. When SF Pro is unavailable, the approved system fallback is used.

```css
font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display",
  "SF Pro Text", "Segoe UI", sans-serif;
```

| Style | Size | Weight | Line height | Letter spacing | Use |
| --- | ---: | ---: | ---: | ---: | --- |
| H1 | `40px` | `500` | `1.15` | `0.03em` | Page title |
| H2 | `24px` | `500` | `1.2` | `0.03em` | Card and section title |
| H3 | `18px` | `500` | `1.3` | `0.01em` | Subsection title |
| Body | `16px` | `400` | `1.5` | Normal | Body copy and input text |
| Body medium | `16px` | `500` | `1.5` | Normal | Sidebar labels and primary entity data |
| Label | `14px` | `500` | `1.3` | `0.03em` | Field and control labels |
| Small | `14px` | `400` | `1.4` | `0.03em` | Supporting content |
| Caption | `12px` | `400` | `1.4` | `0.02em` | Metadata and timestamps |
| Alert text | `14px` | `400` | `1.4` | `0.03em` | Approved alert/error copy; color `--text-danger` (`#FF0000`) |
| Large metric | `36px` | `600` | `1` | Normal | Primary KPI value |
| Medium metric | `28px` | `600` | `1.1` | Normal | Secondary metric |

Use Body medium for driver names, vehicle names, shipment IDs, registration numbers, sidebar labels, and table primary data. Do not introduce font sizes outside this scale. On small Driver screens, reduce type only by selecting another approved style.

### 4.4 Spacing

Use a 4px base scale.

| Token step | Value | Typical use |
| --- | ---: | --- |
| 1 | `4px` | Fine internal separation |
| 2 | `8px` | Icon gaps and label-to-input gap |
| 3 | `12px` | Compact table and control padding |
| 4 | `16px` | Default page/card/grid/section/form gap |
| 5 | `20px` | Approximate desktop outer padding and table cells |
| 6 | `24px` | Large section separation |
| 8 | `32px` | Large grouping |
| 10 | `40px` | Control sizing and spacious grouping |
| 12 | `48px` | Major separation |
| 16 | `64px` | Largest approved separation |

Default card padding, grid gap, page gap, and section gap are `16px`. Form fields have a `16px` vertical gap and labels sit `8px` above inputs. Use approximately `20px` desktop page padding. Random spacing values are prohibited unless required to reproduce an approved screenshot.

### 4.5 Radius

| Element | Radius |
| --- | ---: |
| Cards, inputs, buttons, dropdowns, popovers | `10px` |
| Tooltips | `8px` |
| Dialogs and drawers | `14px` |
| Status badges and avatars | `999px` |
| Mobile bottom sheets | `16px 16px 0 0` |

Do not use arbitrary radii.

### 4.6 Borders, elevation, and motion

- Default border: `1px solid #DDD9D2`; inputs use `#CFCFCF`.
- Permanent surfaces have no shadow. Separate them with background contrast, a 1px border, spacing, and hierarchy.
- A subtle temporary overlay shadow is allowed only on dialogs, dropdowns, drawers, and bottom sheets.
- Hover and focus transitions last `150ms`; dropdown, dialog, and drawer transitions last `200ms`. Use `ease-out`.
- Do not add decorative page transitions. Respect reduced-motion preferences.
- Smooth vehicle interpolation is allowed only when it does not imply inaccurate tracking.

### 4.7 Focus

Standard focus uses `--info` for the border, a `2px` ring in `--info-soft`, and a `2px` ring offset. The offset color uses the token for the surface behind the control: `--background-card` on cards and form surfaces, `--background-app` on the application background, and `--background-sidebar` on the sidebar. Do not introduce a separate focus-offset color token.

Focus must remain visible on buttons, links, form fields, tabs, navigation items, icon-only controls, table actions, and dialog and drawer controls.

### 4.8 Iconography and target sizes

Use `lucide-react` outline icons only. Default icons are `20px`, small icons `16px`, and large icons `24px`; use `1.75` stroke width and `2` for active navigation. Icon controls are at least `40 × 40px`; all mobile touch targets are at least `44 × 44px`.

## 5. Application shells and layout

### 5.1 Admin and Dispatcher operations shell

Admin and Dispatcher remain desktop-first in V1. Across all breakpoints, use a fluid main area with no mandatory global max-width, `#F7F3ED` app background, `#E9E5DD` navigation surfaces, white cards, and no sidebar shadow. A subtle divider is allowed.

The sidebar contains the logo, a `MENU`-style section label, icon-and-text navigation, an orange active treatment, and Settings and Logout separated by a divider. The topbar may contain page search, message and notification icon buttons, and the signed-in user’s avatar, full name, role, and secondary text, following approved screenshot hierarchy.

| Range | Admin / Dispatcher navigation |
| --- | --- |
| Desktop `>= 1280px` | Full fixed or sticky sidebar, approximately `276px` wide, with full labels and icons, the full existing LogiFlow wordmark, and standard desktop spacing. |
| Tablet and narrower laptop `768px–1279px` | Use an icon-only navigation rail exactly `64px` wide, including its content area and borders. Each item has a minimum `44px × 44px` target; icons are horizontally centered. Labels are visually hidden but remain available through accessible labels and tooltips. Main content fills the remaining width, and rail spacing uses only approved tokens. The rail displays no logo; the full existing LogiFlow wordmark is displayed in the topbar. |
| Narrow mobile `< 768px` | Hide the sidebar. A menu button in the topbar opens a temporary navigation drawer containing the same approved hierarchy as the desktop sidebar and the full existing LogiFlow wordmark at the top. The drawer is not bottom navigation; it closes after navigation and implements keyboard focus management. |

At `768px–1279px`, provide graceful layout adaptation without creating a separate tablet design language:

- Reduce KPI grid columns when four cards no longer fit.
- Stack two-column content where necessary.
- Keep dense tables readable through horizontal scrolling.
- Tighten spacing only by selecting smaller approved spacing tokens.
- Keep the icon navigation rail and all controls usable.

Wordmark placement is mandatory: the desktop full sidebar displays the full existing LogiFlow wordmark; the tablet topbar displays it while the `64px` rail displays no logo; and the narrow-mobile navigation drawer displays it at the top. Do not create a compact logo, icon-only logo, abbreviation, cropped wordmark, redrawn wordmark, replacement, or alternate logo asset.

At `< 768px`, tables may remain horizontally scrollable, and large desktop forms and dashboards do not require a complete mobile redesign. The interface must remain usable without accidental page-level overflow. Do not introduce Admin/Dispatcher bottom navigation. Mobile-first bottom navigation plus More drawer remains exclusive to Driver users.

### 5.2 Driver shell

The complete mobile-first system applies only to Drivers.

| Range | Driver behavior |
| --- | --- |
| Mobile `<768px` | Single-column, touch-first workflow with fixed bottom navigation |
| Tablet `768–1023px` | Responsive Driver layout with additional room while retaining workflow priority |
| Desktop `>=1024px` | Expanded Driver layout that preserves mobile-first information order |

Below `768px`, hide the desktop sidebar and use fixed bottom navigation in this order: Dashboard, Shipments, Messages, Profile, More. Active items are orange; inactive items are neutral. More opens a bottom drawer containing Documents, Vehicle, Settings, and Logout. Reserve content padding so navigation never covers content; active workflow actions sit above it.

Driver mobile rules:

- Use one column and prevent horizontal page overflow.
- Use a two-column KPI grid when readable; otherwise allow a deliberate horizontal KPI scroller.
- Place Current Assignment before the map.
- Make the map full width with a minimum `280px` height.
- Make primary workflow actions full width; the current status action may remain sticky above bottom navigation.
- Convert tables into readable cards or lists.
- Present filters in a drawer or bottom sheet; suitable dialogs may become bottom sheets.
- Keep timelines vertical and all touch targets at least `44px`.

### 5.3 Grids and detail pages

- Wide dashboard KPI grids use four equal columns and reduce to two when four cards no longer fit comfortably.
- Standard dashboard compositions use `2fr / 1fr`, two equal columns, or four equal KPI columns, all with `16px` gaps.
- Detail pages use an identity header, status badge, primary actions, tabs, structured cards, and supporting history or tables.
- Vehicle, Shipment, Client, and future details share a default `2fr / 1fr` grid with a `16px` gap, stacking only when necessary.

## 6. Components

### 6.1 Buttons

| Variant | Treatment | Use |
| --- | --- | --- |
| Primary | `#FF6209` background, white text; hover `#FF5C00` | Add, create, confirm |
| Outline | White/transparent, `#CFCFCF` border, `#454545` text; hover `#F8F8F8` | Secondary action |
| Ghost | Transparent, `#454545` text; hover `#F8F8F8` | Low-emphasis action |
| Danger | `#EB0505` background, white text | Confirmed destructive action only |
| Icon | Soft primary background and orange icon where appropriate | Compact icon action |

Standard buttons are `40px` high with `16px` horizontal padding, `10px` radius, and an `8px` icon gap. Icon buttons are `40 × 40px`. Disabled controls use `0.5` opacity, `not-allowed`, and no hover. Loading controls preserve their width, show a spinner, and block repeated action. Keyboard focus uses the canonical focus tokens and dimensions in section 4.7.

### 6.2 Form controls

Inputs are `40px` high with a white background, `#CFCFCF` border, `10px` radius, `14px` horizontal padding, `#111111` 16px regular text, and `#B8B8B8` placeholder text. Selects use the same height with `#454545` 14px medium text. Textareas have a `120px` minimum height, allow vertical resize, and share the same border and radius.

Focus uses `--info`, `--info-soft`, the canonical ring dimensions, and the surface-specific offset token in section 4.7. Form errors use `--danger` for the input border, error icon, and accessibly associated inline validation message through `border-danger` and `text-danger`. The separate `--text-danger` token is not used for ordinary form validation. Checkbox, radio, switch, date/time, file upload, and autocomplete/search controls follow the same sizes, states, focus system, labeling, and validation rules.

Login uses a full-page `#F7F3ED` surface and a centered `420–460px` white card with the logo, “Welcome back,” Username, Password, and a full-width primary button. It has no registration or user-managed reset. Show: “Contact your administrator if you cannot access your account.”

Admin account creation lives inside the authenticated shell in a white card. Use two desktop columns where space permits. Fields are Full name, Username, Initial password, and Role; Driver-only fields appear only for the Driver role. Actions are primary “Create account” and outline “Cancel.”

Logout is a confirmation dialog, never a separate page: title “Log out?”, message “You will need to sign in again to continue.”, and “Cancel” / “Log out” actions.

### 6.3 Cards and KPIs

Every card is white with `1px solid #DDD9D2`, `10px` radius, `16px` padding, and no shadow. Only interactive cards receive `#F8F8F8` hover. Supported variants are KPI, standard, table, detail, map, alert, timeline, empty, and form.

KPI cards contain a title, semantic icon container, large metric, supporting text, relevant trend, and optional compact chart. Approved metric accents are orange for Shipments, blue for Vehicles/In transit, green for Available drivers/Upcoming stop, and purple for Revenue/Distance. These associations do not authorize those colors elsewhere.

### 6.4 Data tables

Desktop tables sit in a bordered, shadowless white card with a `10px` radius. Card titles use H2; headers use 14px medium. Use approximately `52px` header height, `54px` row height, `20px` horizontal cell padding (`12px` compact), `54px` avatar/thumbnail cells, at least `120px` for status, and `48px` for actions. Row hover is `#F8F8F8`; selection uses orange at `6–8%` opacity.

Tables support search, filters, sorting, pagination, empty state, skeleton/loading rows, row actions, and sticky headers for long data sets. Preserve readable column sizing; use horizontal scrolling for narrow Admin/Dispatcher layouts and cards/lists for Driver mobile.

### 6.5 Status badges

Use one reusable `StatusBadge`: pill radius, compact padding, 1px semantic border, soft semantic background, readable text, and an optional icon. Ordinary badges never use saturated solid fills.

| Semantic variant | Canonical identifiers and UI labels |
| --- | --- |
| Success | `available` → Available; `active` → Active; `delivered` → Delivered; `valid` → Valid; `completed` → Completed; `approved` → Approved |
| Warning | `pending` → Pending; `on_break` → On break; `expiring` / expiring-soon condition → Expiring soon; `out_of_service` → Out of service; `delayed` condition → Delayed |
| Danger | `cancelled` → Cancelled; `maintenance` → Maintenance; `rejected` → Rejected; `expired` → Expired; destructive failure |
| Information | `driving` → Driving; `assigned` → Assigned; `loading` → Loading; `in_transit` → In transit; `requested` → Requested; `in_use` → In use |
| Neutral | `inactive` → Inactive; `archived` → Archived; `off_duty` → Off duty; `no_expiry` → No expiry |

`in_use` uses the Information treatment exactly: `--info-soft` background, `--info-border`, and `--info` text and icon.

`delayed` is a Shipment condition, not a shipment status. Render its `Delayed` label as a separate Warning badge using `--warning-soft` background, `--warning-border`, `--warning-text`, and an optional warning/alert icon. A delayed Shipment must display its normal status badge, such as `In transit`, together with the separate `Delayed` Warning condition badge. Never replace the Shipment status with `Delayed`.

Client `active` renders as `Active` with the Success treatment: `--success-soft` background, `--success-border`, and `--success` text and icon. Client `archived` renders as `Archived` with the Neutral treatment: `--background-hover` background, `--border-strong`, and `--text-secondary` text and icon.

All Neutral badges use `--background-hover` background, `--border-strong`, and `--text-secondary` text and icon.

Danger `StatusBadge` components use `--danger-soft` background, `--danger-border`, and `--danger` text and icon.

The shared badge system covers Shipment statuses, Driver statuses, Vehicle statuses, Client statuses, derived Document states, status-request states, and the Shipment delayed condition. Do not create page-specific status styling.

### 6.6 Navigation

Desktop detail pages use breadcrumbs such as `Vehicles / BG123AB` and `Shipments / SHP-2026-203`. Detail tabs use shared patterns such as Overview, Maintenance, Documents, and History; the active tab has orange text and underline. Pagination shows Previous, page numbers, and Next, with the active page on a bordered white surface.

### 6.7 Map and tracking

- Route: blue `#3B82F6`, approximately `4px` wide.
- Vehicle: blue circle with a white truck icon.
- Destination: orange. Pickup/completed: green. Stale/failed: red.
- Zoom, recenter, and other map controls align right.
- Supporting details may include speed, heading, distance remaining, ETA, route progress, and last update.
- Provide loading skeleton, no active route, unavailable, reconnecting, stale, and provider-error states.
- Keep motion restrained and label simulated tracking as required by the product.

### 6.8 Timelines and activity

Use one vertical timeline for Today’s schedule, shipment progress, recent activity, maintenance history, and status-request history. It contains a vertical line, semantic step icon, time, primary label, and secondary description, with visually distinct completed, active, and future states.

### 6.9 Alerts and notifications

Alerts use warning/danger semantics and include a clear title or message, entity context, and permitted resolution action. Notifications are visually lighter and include an icon, title, short message, timestamp, and read/unread state; unread notifications may use a soft primary background. Never make ordinary notifications look like critical alerts.

### 6.10 System states

- Loading: skeleton cards, rows, and maps; button spinner.
- Empty: relevant Lucide icon, short title, one sentence, and optional CTA.
- Error: clear title, safe message, retry action, inline form errors, and mutation-failure toast.
- Success: toast plus updated UI; avoid success modals.
- Realtime/offline: reconnecting state, stale indicator, and offline banner.

### 6.11 Overlays and feedback

Use dialogs for confirmations, destructive actions, and short forms; drawers for filters, Driver More, and supporting panels; bottom sheets on Driver mobile for filters, More, compact forms, and suitable confirmations. Toasts are only for non-blocking success or failure. Dialogs trap focus; Escape closes non-destructive overlays.

## 7. Accessibility

All screens must meet WCAG AA and include:

- Visible keyboard focus and complete keyboard navigation
- Semantic HTML, logical heading order, and proper table headers
- Explicit labels and accessible error associations
- `aria-label` on icon-only controls
- Minimum `44px` mobile targets
- Text labels, and icons when useful, so status is never color-only
- Reduced-motion support
- Focus trapping in dialogs and safe Escape behavior
- Contrast validation for orange active treatments, warning states, text, controls, and badges

## 8. Tailwind and implementation rules

Tailwind must expose semantic tokens for backgrounds, brand, text, borders, semantic statuses, analytics purple, radius, spacing, and focus. Brand/text contracts include both `primary-text-on-solid` and `text-on-primary`, generating `text-primary-text-on-solid` and `text-on-primary` respectively. Status contracts include `success`, `success-soft`, `success-border`, `warning`, `warning-soft`, `warning-border`, `warning-text`, `danger`, `danger-soft`, `danger-border`, `danger-alert-text`, `info`, `info-soft`, `info-border`, `neutral`, and `neutral-border`. Context-specific utilities are generated from these semantic token names as defined in section 4.2; for example, `success-soft` generates `bg-success-soft`, not a second design token. Shared components use reusable typed variants and one consistent class-merging utility.

Approved:

```tsx
<Button className="bg-primary text-on-primary">Create shipment</Button>
<StatusBadge className="bg-success-soft border-success-border text-success" />
<StatusBadge className="bg-danger-soft border-danger-border text-danger" />
```

Prohibited:

```tsx
<button className="rounded-[7px] bg-[#FF6209] shadow-xl">Create shipment</button>
<StatusBadge className="bg-[rgba(235,5,5,0.15)] border-[#EB0505]" />
```

Do not use arbitrary approved colors, arbitrary shadows, inline style duplication, random spacing when a token exists, or page-specific copies of shared components. Reusable components must use semantic tokens rather than their raw values.

## 9. Reusable component inventory

New screens compose these primitives rather than one-off equivalents.

| Area | Components |
| --- | --- |
| Foundation | Button, IconButton, Input, Textarea, Select, Checkbox, Radio, Switch, DateTimeInput, FileUpload, SearchInput, Avatar, Badge, StatusBadge, Divider, Spinner, Skeleton |
| Navigation | Sidebar, MobileBottomNavigation, MoreDrawer, Breadcrumbs, Tabs, Pagination, DropdownMenu |
| Layout/content | PageHeader, Card, KPICard, DetailCard, TableCard, EmptyState, ErrorState, AlertCard, NotificationItem, ActivityTimeline, ScheduleTimeline |
| Data | DataTable, TableToolbar, FiltersDrawer |
| Tracking | MapCard, VehicleMarker, RouteSummary, TrackingStatus |
| Overlays | Dialog, Drawer, BottomSheet, Toast |
| Forms | FormField, FormError, AccountForm, LoginForm, ShipmentForm, VehicleForm, DriverForm, ExpenseForm, DocumentUploadForm |

`MobileBottomNavigation`, `MoreDrawer`, and Driver-mobile bottom-sheet patterns belong to the Driver experience. Their presence in the shared inventory does not authorize an Admin/Dispatcher mobile navigation system.

## 10. Figma rules

Use Auto Layout, reusable components and variants, named color variables, named text styles, the approved spacing scale, and clear layer/frame names. Match implementation component names where practical. Do not detach one-off elements. Maintain desktop Admin/Dispatcher frames and desktop/mobile Driver frames. Approved screenshots remain visual references, not substitutes for componentized designs.

## 11. Implementation acceptance criteria

An implementation conforms only when all of the following are true:

- All approved colors are represented by semantic tokens and orange is the only brand color.
- Purple appears only for approved revenue, distance, or analytical metrics.
- V1 contains no dark mode or dark-logo variant.
- Cards use white, a 1px default border, `10px` radius, `16px` padding, and no shadow.
- SF Pro files are not required, rendering does not depend on bundled private SF Pro files, and the approved system-first stack and fallback are used with the approved type scale.
- All icons are from `lucide-react` with approved sizes and stroke weights.
- Spacing, control sizes, radii, focus, motion, and temporary elevation use the approved values.
- Buttons, forms, tables, badges, maps, cards, timelines, notifications, loading/empty/error/success states, login, account creation, and logout follow their documented variants.
- Semantic statuses use the canonical CSS-variable-to-token-to-utility table; utilities such as `bg-success-soft` are generated contexts rather than separate design tokens, and reusable components do not use raw semantic values.
- Form-validation borders, icons, and inline text use `--danger: #EB0505` through `border-danger` and `text-danger`.
- `--text-danger: #FF0000` and `text-danger-alert` are reserved exclusively for approved copy using the dedicated 14px Alert Text typography contract.
- Neutral badges use `--background-hover`, `--border-strong`, and `--text-secondary` without an added soft-neutral color token.
- Focus uses `--info` for the border, a 2px `--info-soft` ring, a 2px offset using the surrounding surface token, and remains visible on every documented interactive control.
- Both `--primary-text-on-solid` and `--text-on-primary` remain `#FFFFFF` with distinct `primary-text-on-solid` / `text-on-primary` semantic contracts and `text-primary-text-on-solid` / `text-on-primary` generated utilities.
- `StatusBadge` covers Shipment, Driver, Vehicle, Client, Document, status-request, and delayed-condition mappings with canonical labels, semantic borders/backgrounds, readable text, and no color-only meaning or page-specific variants.
- Vehicle `in_use` renders as an Information `In use` badge using `--info-soft`, `--info-border`, and `--info` exactly.
- Client `active` and `archived` render as the canonical Success `Active` and Neutral `Archived` badges.
- Shipment `delayed` renders as a separate Warning `Delayed` condition badge without replacing the normal Shipment status badge.
- Admin and Dispatcher use the full approximately `276px` sidebar at `>= 1280px`, an exact `64px` icon rail with centered icons and minimum `44px × 44px` targets at `768px–1279px`, and the focus-managed temporary navigation drawer at `< 768px`; they never use bottom navigation or require a full mobile redesign.
- Wordmark placement is fixed: full wordmark in the desktop sidebar, full wordmark in the tablet topbar with no rail logo, and full wordmark atop the narrow-mobile drawer; no compact, icon-only, abbreviated, cropped, redrawn, replacement, or alternate logo exists.
- Driver uses the `<768px`, `768–1023px`, and `>=1024px` responsive ranges; fixed mobile bottom navigation and the More drawer remain exclusive to Driver mobile.
- Tracking, dialogs, drawers, bottom sheets, toasts, and realtime/offline states include their required fallback and accessibility behavior.
- Tailwind usage is semantic, shared variants are typed, and new screens reuse the component inventory.
- The implementation meets WCAG AA, supports keyboard interaction and reduced motion, and maintains readable contrast.
- No visual rule introduces unrelated product behavior, schema decisions, or an unapproved visual language.
