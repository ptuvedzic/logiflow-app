# Create LogiFlow V1 Design System

## Summary

Create `DESIGN_SYSTEM.md` in the project root.

Use:

- `PRD.md` as the product and role authority;
- `ARCHITECTURE.md` as the frontend architecture authority;
- approved LogiFlow screenshots as the visual source of truth.

This is a documentation-only task.

Do not modify application code.
Do not modify PRD.md, DATABASE.md, ARCHITECTURE.md, or final-schema.md.
Do not redesign approved screens.
Do not introduce dark mode.
Do not add unrelated visual styles or brand colors.

The document must define mandatory reusable visual and responsive rules for every current and future LogiFlow screen.

---

## 1. Design Direction

LogiFlow uses a modern enterprise dashboard style.

Core principles:

- Business-first interface
- Function over decoration
- Clear visual hierarchy
- Warm neutral application surfaces
- Orange as the only brand color
- Semantic colors only for operational states
- High information density without visual clutter
- Consistent reusable components
- No shadows
- Thin borders define surfaces
- Minimal motion
- Tables are primary desktop data surfaces
- Driver workflows are mobile-first
- Admin and Dispatcher workflows are desktop-first
- Approved screenshots define visual intent
- New screens must look like part of the same product

Do not use:

- glassmorphism
- neumorphism
- decorative gradients
- heavy shadows
- excessive animation
- arbitrary new colors
- one-off component styling
- dark mode in V1

---

## 2. Brand

Product name:

LogiFlow

Logo:

- Keep the existing LogiFlow wordmark.
- “Logi” uses the primary text color.
- “Flow” uses the primary orange.
- Use only the light-theme logo in V1.
- Do not create a dark logo variant.
- Do not distort, recolor, outline, or add effects to the logo.

Brand color:

- Orange is the only primary brand color.
- Purple, blue, green, yellow, and red are semantic or analytical colors, not additional brand colors.

---

## 3. Color Tokens

Define semantic CSS variables and corresponding Tailwind tokens.

### Application surfaces

- `--background-app`: `#F7F3ED`
- `--background-sidebar`: `#E9E5DD`
- `--background-card`: `#FFFFFF`
- `--background-hover`: `#F8F8F8`

### Primary brand

- `--primary`: `#FF6209`
- `--primary-hover`: `#FF5C00`
- `--primary-active-background`: `rgba(255, 98, 9, 0.50)`
- `--primary-icon`: `#FF6209`
- `--primary-soft`: `rgba(255, 98, 9, 0.15)`
- `--primary-text-on-solid`: `#FFFFFF`

The active sidebar item uses the approved warm orange treatment from the screenshots. If 50% opacity reduces text contrast, preserve the screenshot appearance while ensuring WCAG AA contrast.

### Analytical accent

Use purple only for distance, revenue, and approved analytical metrics.

- `--analytics-purple`: `#8B5CF6`
- `--analytics-purple-soft`: `rgba(139, 92, 246, 0.15)`

Purple must not be used for primary calls to action.

### Text colors

Define:

- `--text-primary`: `#111111`
- `--text-secondary`: `#454545`
- `--text-muted`: `#8F8F8F`
- `--text-placeholder`: `#B8B8B8`
- `--text-on-primary`: `#FFFFFF`
- `--text-danger`: `#FF0000`

### Borders and dividers

Define:

- `--border-default`: `#DDD9D2`
- `--border-subtle`: `#E7E3DC`
- `--border-input`: `#CFCFCF`
- `--border-strong`: `#B8B8B8`

Default border width:

- `1px`

No standard component shadow is allowed.

---

## 4. Semantic Colors

Use semantic tokens consistently.

### Success

Base: `#22C55E`  
Background: `rgba(34, 197, 94, 0.15)`  
Border: `#22C55E`

Use for:

- available
- delivered
- valid
- completed
- approved
- successful operations

### Warning

Base: `#C9EB05`  
Background: `rgba(201, 235, 5, 0.15)`  
Border: `#C9EB05`

Use for:

- pending
- on break
- expiring soon
- out of service
- states requiring attention but not immediate danger

Because the warning base is bright, use a dark readable text color rather than white.

### Danger

Base: `#EB0505`  
Background: `rgba(235, 5, 5, 0.15)`  
Border: `#EB0505`

Use for:

- cancelled
- maintenance
- rejected
- expired
- destructive actions
- errors
- critical alerts

### Information / Active transport

Base: `#3B82F6`  
Background: `rgba(59, 130, 246, 0.15)`  
Border: `#3B82F6`

Use for:

- driving
- assigned
- loading
- in transit
- requested
- route progress
- current vehicle location

### Neutral

Use neutral styling for:

- inactive
- archived
- off duty
- no expiry
- unavailable non-critical states

Do not create arbitrary status colors.

Color must never be the only status indicator. Always include visible text and, when useful, an icon.

---

## 5. Typography

Use a system-first SF Pro stack:

```css
font-family:
  -apple-system,
  BlinkMacSystemFont,
  "SF Pro Display",
  "SF Pro Text",
  "Segoe UI",
  sans-serif;
```

Do not require private font files.

Define:

- H1: `40px`, weight `500`, line height `1.15`, letter spacing `0.03em`
- H2: `24px`, weight `500`, line height `1.2`, letter spacing `0.03em`
- H3: `18px`, weight `500`, line height `1.3`, letter spacing `0.01em`
- Body: `16px`, weight `400`, line height `1.5`
- Body medium: `16px`, weight `500`, line height `1.5`
- Label: `14px`, weight `500`, line height `1.3`, letter spacing `0.03em`
- Small: `14px`, weight `400`, line height `1.4`, letter spacing `0.03em`
- Caption: `12px`, weight `400`, line height `1.4`, letter spacing `0.02em`
- Alert text: `14px`, weight `400`, line height `1.4`, letter spacing `0.03em`, color `#FF0000`
- Large metric: `36px`, weight `600`, line height `1`
- Medium metric: `28px`, weight `600`, line height `1.1`

Use body medium for sidebar labels, driver names, vehicle names, shipment IDs, registration numbers, and table primary data.

Do not create arbitrary font sizes outside the approved type scale.

---

## 6. Spacing System

Use a 4px base spacing scale.

Approved values:

- `4px`
- `8px`
- `12px`
- `16px`
- `20px`
- `24px`
- `32px`
- `40px`
- `48px`
- `64px`

Core rules:

- Default page gap: `16px`
- Default card padding: `16px`
- Default grid gap: `16px`
- Default section gap: `16px`
- Large section separation: `24px`
- Desktop page outer padding: approximately `20px`
- Form field vertical gap: `16px`
- Label-to-input gap: `8px`

Do not use random spacing values unless required to match an approved screenshot.

---

## 7. Desktop Application Shell

Admin and Dispatcher are desktop-first.

- Minimum intended desktop viewport: `1280px`
- Sidebar width: approximately `276px`
- Fixed or sticky left sidebar
- Main content fills remaining width
- App background: `#F7F3ED`
- Sidebar background: `#E9E5DD`
- Cards: `#FFFFFF`
- Fluid main content
- No mandatory global max-width
- No sidebar shadow
- Use a subtle border when needed

Sidebar:

- Logo at top
- Section label such as `MENU`
- Icon plus text items
- Active item uses primary treatment
- Settings and Logout separated by divider

Topbar:

- Page search when applicable
- Message and notification icon buttons
- Avatar, full name, and role/secondary text
- Follow the approved screenshot hierarchy

---

## 8. Grid and Page Layouts

Dashboard KPI grid:

- Four equal cards on wide desktop
- Two columns when four cards no longer fit comfortably

Main dashboard layouts:

- `2fr / 1fr`
- Two equal columns
- Four equal KPI columns
- `16px` gaps

Detail pages use:

- identity header
- status badge
- primary actions
- tabs
- structured card grid
- supporting tables/history

Default detail grid:

- `2fr / 1fr`
- `16px` gap

Vehicle, Shipment, Client, and future detail screens follow the same pattern.

---

## 9. Border Radius

- Cards: `10px`
- Inputs: `10px`
- Buttons: `10px`
- Dropdowns: `10px`
- Popovers: `10px`
- Tooltips: `8px`
- Dialogs: `14px`
- Drawers: `14px`
- Status badges: `999px`
- Avatars: `999px`
- Mobile bottom sheets: `16px 16px 0 0`

Do not use arbitrary radius values.

---

## 10. Elevation

No standard card shadows.

Separate surfaces through:

- background contrast
- 1px borders
- spacing
- hierarchy

A subtle temporary overlay shadow is allowed only for dialogs, dropdowns, drawers, and bottom sheets.

---

## 11. Iconography

Use `lucide-react` only.

- Default: `20px`
- Small: `16px`
- Large: `24px`
- Stroke width: `1.75`
- Active navigation stroke width: `2`
- Icon controls: minimum `40×40px`
- Mobile touch targets: minimum `44×44px`

Use outline icons and consistent semantics.

---

## 12. Buttons

Primary:

- Background `#FF6209`
- Text `#FFFFFF`
- Hover `#FF5C00`
- Height `40px`
- Horizontal padding `16px`
- Radius `10px`
- Icon gap `8px`

Use for add/create/confirm actions.

Outline:

- White or transparent background
- Border `#CFCFCF`
- Text `#454545`
- Hover `#F8F8F8`

Ghost:

- Transparent
- Text `#454545`
- Hover `#F8F8F8`

Danger:

- Background `#EB0505`
- Text white
- Only for confirmed destructive actions

Icon button:

- `40×40px`
- Radius `10px`
- Soft primary background and orange icon where appropriate

Disabled:

- Opacity `0.5`
- `not-allowed`
- No hover

Loading:

- Preserve width
- Spinner
- Disable repeated action

Focus:

- 2px blue ring
- 2px offset

---

## 13. Form Controls

Inputs:

- Height `40px`
- White background
- Border `#CFCFCF`
- Radius `10px`
- Horizontal padding `14px`
- Text `#111111`
- Placeholder `#B8B8B8`
- `16px` regular

Select:

- Height `40px`
- Text `#454545`
- `14px` medium

Textarea:

- Minimum `120px`
- Vertical resize
- Same border/radius system

Focus:

- Border `#3B82F6`
- Soft blue ring

Error:

- Border and text `#EB0505`
- Error message below field
- Accessible association

Also define checkbox, radio, switch, date/time input, file upload, and autocomplete/search using the same system.

---

## 14. Login and Account Forms

Login:

- Full page `#F7F3ED`
- Centered white card
- Width `420–460px`
- Logo
- `Welcome back`
- Username
- Password
- Full-width primary button
- No registration
- No user-managed reset
- Helper: `Contact your administrator if you cannot access your account.`

Admin account creation:

- Uses authenticated shell
- White card
- Two desktop columns when space permits
- Full name, username, initial password, role
- Driver-only fields shown only for Driver role
- Primary `Create account`
- Outline `Cancel`

Logout:

- Confirmation dialog
- Title `Log out?`
- Message `You will need to sign in again to continue.`
- Actions `Cancel` and `Log out`
- Not a separate page

---

## 15. Cards

All cards:

- White
- `1px solid #DDD9D2`
- `10px` radius
- `16px` padding
- No shadow

Variants:

- KPI
- Standard
- Table
- Detail
- Map
- Alert
- Timeline
- Empty
- Form

Only interactive cards use hover `#F8F8F8`.

---

## 16. KPI Cards

Contain:

- Title
- Semantic icon container
- Large metric
- Supporting text
- Trend when relevant
- Optional compact chart

Approved colors:

- Shipments: orange
- Vehicles / In transit: blue
- Available drivers / upcoming stop: green
- Revenue / distance: purple

Do not use these metric colors outside approved contexts.

---

## 17. Tables

Desktop tables are primary data surfaces.

- White card
- Border
- `10px` radius
- No shadow
- Card title uses H2
- Column header uses `14px` medium
- Header height about `52px`
- Row height about `54px`
- Cell horizontal padding `20px`
- Compact padding `12px`
- Avatar/thumbnail cell `54px`
- Status column minimum `120px`
- Actions `48px`
- Hover `#F8F8F8`
- Selected row uses orange at `6–8%`

Support:

- search
- filters
- sorting
- pagination
- empty state
- loading rows
- row actions
- sticky header for long tables

Do not compress desktop tables into unreadable layouts.

---

## 18. Status Badges

One reusable `StatusBadge`.

- Pill radius
- Compact padding
- 1px semantic border
- Soft semantic background
- Readable text
- Optional icon
- No saturated solid fills for ordinary badges

Mappings:

Success:

- available
- delivered
- valid
- completed
- approved

Warning:

- pending
- on break
- expiring soon
- out of service

Danger:

- cancelled
- maintenance
- rejected
- expired
- destructive failure

Information:

- driving
- assigned
- loading
- in transit
- requested

Neutral:

- inactive
- archived
- off duty
- no expiry

Use canonical labels.

---

## 19. Navigation

Desktop sidebar remains persistent.

Breadcrumbs on detail pages, e.g.:

- Vehicles / BG123AB
- Shipments / SHP-2026-203

Detail tabs:

- Overview
- Maintenance
- Documents
- History

Active tab:

- Orange text
- Orange underline

Pagination:

- Previous
- Page numbers
- Next
- Active page with border and white surface

---

## 20. Driver Mobile Navigation

Below `768px`, hide desktop sidebar.

Use fixed bottom navigation:

1. Dashboard
2. Shipments
3. Messages
4. Profile
5. More

More opens a bottom drawer:

- Documents
- Vehicle
- Settings
- Logout

Rules:

- Active item orange
- Inactive neutral
- Minimum target `44px`
- Content bottom padding prevents overlap
- Active workflow actions sit above navigation

---

## 21. Driver Responsive Rules

Breakpoints:

- Mobile `<768px`
- Driver tablet `768–1023px`
- Driver desktop `>=1024px`

Mobile:

- Single column
- No horizontal page overflow
- KPI 2-column grid when readable, otherwise horizontal scroll
- Current Assignment before map
- Map full width, minimum height `280px`
- Primary workflow actions full width
- Status action can be sticky above bottom nav
- Tables become cards/lists
- Filters use drawer/bottom sheet
- Dialogs may become bottom sheets
- Timeline remains vertical
- Minimum touch target `44px`
- Moderate typography reduction only

Admin/Dispatcher remain desktop-first. They need laptop safety but not a full mobile redesign.

---

## 22. Map and Tracking UI

Route:

- Blue `#3B82F6`
- About `4px`

Vehicle marker:

- Blue circle
- White truck icon

Destination:

- Orange

Pickup/completed:

- Green

Stale/failed:

- Red

Controls:

- Zoom in/out
- Recenter
- Right aligned

Supporting data can show:

- Speed
- Heading
- Distance remaining
- ETA
- Route progress
- Last update

States:

- Loading skeleton
- No active route
- Tracking unavailable
- Reconnecting
- Stale
- Provider error

Keep motion restrained.

---

## 23. Timelines and Activity

One reusable timeline for:

- Today’s schedule
- Shipment progress
- Recent activity
- Maintenance history
- Status-request history

Use:

- Vertical line
- Semantic step icon
- Time
- Primary label
- Secondary description
- Distinct completed, active, future states

---

## 24. Alerts and Notifications

Alerts:

- Warning/danger semantics
- Clear title/message
- Entity context
- Resolution action where permitted

Notifications:

- Lighter than alerts
- Icon
- Title
- Short message
- Timestamp
- Read/unread state
- Unread may use soft primary background

Do not visually equate notifications with critical alerts.

---

## 25. Loading, Empty, Error, and Success

Loading:

- Skeleton cards
- Skeleton rows
- Skeleton map
- Button spinner

Empty:

- Relevant Lucide icon
- Short title
- One concise sentence
- Optional CTA

Error:

- Clear title
- Safe message
- Retry
- Inline form errors
- Toast for mutation failure

Success:

- Toast
- Updated UI
- Avoid success modals

Realtime/offline:

- Reconnecting
- Stale indicator
- Offline banner

---

## 26. Dialogs, Drawers, Toasts

Dialog for confirmations, destructive actions, and short forms.

Drawer for filters, Driver More menu, supporting panels.

Bottom sheet on mobile for filters, More, compact forms, and suitable confirmations.

Toast for non-blocking success/failure only.

---

## 27. Motion

- Hover/focus `150ms`
- Dropdown/dialog/drawer `200ms`
- `ease-out`
- No decorative page transitions
- Respect reduced motion
- Smooth vehicle interpolation only when it does not reduce accuracy

---

## 28. Accessibility

- WCAG AA
- Visible focus
- Keyboard navigation
- Semantic HTML
- Proper table headers
- Labels and error associations
- `aria-label` for icon buttons
- Minimum 44px mobile targets
- Status never color-only
- Reduced motion
- Logical heading order
- Dialog focus trap
- Escape closes non-destructive overlays

---

## 29. Tailwind Rules

Use semantic Tailwind tokens.

Avoid:

```tsx
className="bg-[#FF6209]"
```

Prefer:

```tsx
className="bg-primary"
```

Define tokens for backgrounds, primary, text, borders, status colors, purple, radius, spacing, and focus.

Rules:

- No arbitrary approved colors
- No arbitrary shadows
- No inline duplication
- No random spacing when tokens exist
- Reusable typed variants
- Consistent class-merging utility
- No page-specific duplicates of shared components

---

## 30. Reusable Component Inventory

Foundation:

- Button
- IconButton
- Input
- Textarea
- Select
- Checkbox
- Radio
- Switch
- DateTimeInput
- FileUpload
- SearchInput
- Avatar
- Badge
- StatusBadge
- Divider
- Spinner
- Skeleton

Navigation:

- Sidebar
- MobileBottomNavigation
- MoreDrawer
- Breadcrumbs
- Tabs
- Pagination
- DropdownMenu

Layout/content:

- PageHeader
- Card
- KPICard
- DetailCard
- TableCard
- EmptyState
- ErrorState
- AlertCard
- NotificationItem
- ActivityTimeline
- ScheduleTimeline

Data:

- DataTable
- TableToolbar
- FiltersDrawer

Tracking:

- MapCard
- VehicleMarker
- RouteSummary
- TrackingStatus

Overlays:

- Dialog
- Drawer
- BottomSheet
- Toast

Forms:

- FormField
- FormError
- AccountForm
- LoginForm
- ShipmentForm
- VehicleForm
- DriverForm
- ExpenseForm
- DocumentUploadForm

New screens must compose these components rather than one-off equivalents.

---

## 31. Figma Rules

- Auto Layout
- Reusable components
- Variants
- Named color variables
- Named text styles
- Approved spacing scale
- No detached one-offs
- Clear layer/frame names
- Match implementation names where practical
- Desktop and mobile Driver frames
- Desktop-first Admin/Dispatcher
- Screenshots are visual references, not substitutes for components

---

## 32. Design Authority

Authority order:

1. Approved screenshots for composition
2. `DESIGN_SYSTEM.md` for reusable visual rules
3. `PRD.md` for product behavior
4. `ARCHITECTURE.md` for frontend boundaries

When no screenshot exists:

- follow the design system
- reuse existing page patterns
- do not invent a new visual language
- preserve hierarchy, spacing, typography, cards, tables, and navigation

---

## 33. Document Output

`DESIGN_SYSTEM.md` must include:

- token tables
- typography table
- spacing table
- radius table
- semantic status mapping
- component rules
- responsive rules
- accessibility rules
- Tailwind rules
- reusable component inventory
- approved/prohibited examples
- implementation acceptance criteria

Do not include application code beyond short examples.

Do not create components.
Do not edit screenshots.
Do not modify any file except `DESIGN_SYSTEM.md`.

---

## 34. Verification

After writing:

- Verify every approved color
- Verify orange is the only brand color
- Verify no dark mode
- Verify no standard card shadows
- Verify SF Pro system stack without private font files
- Verify Lucide only
- Verify radius system
- Verify Driver mobile bottom nav plus More
- Verify Admin/Dispatcher desktop-first
- Verify semantic colors
- Verify tables, maps, cards, forms, timelines, login, account creation, and logout
- Verify no unrelated product or schema decisions

Return a concise summary and confirm that only `DESIGN_SYSTEM.md` was modified.
