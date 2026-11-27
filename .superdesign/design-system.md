# Kas Rumah — Design System (redesign: "hangat & modern")

## Product context
Kas Rumah is an offline Android/iOS app (Flutter, Indonesian UI) for families to track household money:
income/expense transactions, manual wallets (cash, bank, e-wallet) with transfers, recurring bills & installments,
monthly budgets per category, savings goals, debts/receivables, yearly/monthly reports (PDF), encrypted backup, PIN lock.
Users: Indonesian households (often non-technical parents) logging spending daily, quickly, one-handed.
JTBD: "How much money do we have left this month?", "Record this expense in 5 seconds", "Are we over budget?", "Which bills are due?".

Navigation: one shell with an app bar (tab title, search icon, notification bell with unread badge), an add (+) action,
and a 5-tab bottom navigation bar: Ringkasan, Riwayat, Anggaran, Tabungan, Lainnya. Other screens are pushed pages
with a back arrow. Currency formatting: "Rp 1.250.000" (dot thousands separator), dates "27 Nov 2026".
Mobile-first, 360–412px width.

## Visual direction
Warm, friendly, modern, calm — feels like a tidy family notebook, not a bank. Soft cream backgrounds, white rounded
cards with very soft warm shadows, one energetic honey-orange accent, a deep warm-brown hero card for the balance,
generous whitespace, large confident numbers, colorful pastel category icons. No neon, no purple gradients, no glassmorphism.

## Color tokens
### Light (default)
| token | hex | use |
|---|---|---|
| bg | #FBF6EF | scaffold background (warm cream) |
| surface | #FFFFFF | cards, sheets, bottom nav |
| surfaceMuted | #F4ECE2 | inner boxes, chips, input fill, progress track |
| border | #EADFD2 | hairline dividers / card outline (1px) |
| ink | #2B211A | primary text |
| inkMuted | #7A6A5D | secondary text, captions |
| primary | #E8873A | brand accent: FAB, active nav, primary buttons, selected chips, links |
| primarySoft | #FCE7D3 | accent tint backgrounds, active nav pill |
| onPrimary | #FFFFFF | |
| hero | #3A2A22 → #57392A | balance hero card (linear gradient 135°), text #FFF8F1 |
| income | #2F9E6B | income amounts/icons; soft bg #DDF2E7 |
| expense | #D9534F | expense amounts/icons; soft bg #FBE1DF |
| warning | #E0A100 | budget ≥80%; soft bg #FFF1C7 |
| info | #3A86C8 | transfers; soft bg #DDEBF7 |

### Dark
bg #17120F, surface #221B17, surfaceMuted #2E251F, border #3A2F27, ink #F6EEE6, inkMuted #B4A497,
primary #F29A50, primarySoft #4A2F1C, hero #2A1F19 → #4A3226, income #5CC592, expense #F08A85, warning #F2C14E.

### Category palette (pastel tile + saturated icon)
green #3E9B6E/#E1F2E8, teal #2A9D8F/#DDF1EE, blue #3A86C8/#DDEBF7, indigo #5C6BC0/#E5E7F6, purple #8E5BB5/#EEE3F6,
pink #D45A8A/#FAE1EB, red #D9534F/#FBE1DF, orange #E8873A/#FCE7D3, yellow #D9A21B/#FBF0CF, brown #8D6E63/#EFE7E3, grey #8A8178/#EEEBE8.
Category icons sit in 40×40 rounded squares (radius 12) with the pastel tile color; icon 22px in the saturated color.

## Typography
Font: **Plus Jakarta Sans** only (400/500/600/700/800). Numbers use tabular figures.
- Display amount (hero balance): 34/40, w800, letter-spacing -0.5
- Section amount: 22/28 w800
- Screen title (app bar): 20 w700
- Card title: 16 w700
- Body: 14 w500; Caption: 12 w500 inkMuted; Overline labels: 11 w700 uppercase letter-spacing 0.6 inkMuted
- Amounts in lists: 15 w700, colored income/expense, prefixed "+ Rp" / "− Rp"

## Shape, spacing, elevation
- Radius: cards 20, hero card 24, inner boxes/tiles 14, icon tiles 12, inputs 14, buttons pill (999), bottom sheets 28 top.
- Spacing: 4-pt grid; screen gutter 20; gap between cards 14; card padding 18; list row height 60–64.
- Shadow (light only): 0 2px 10px rgba(58,42,34,0.06). Dark mode: no shadow, 1px border.
- Progress bars: 8px tall, fully rounded, track surfaceMuted.
- Bottom nav: white, 72px tall, active item = icon + label in primary on a primarySoft pill; inactive inkMuted.
- Primary action: a round 56px honey FAB (or centered "+" in the nav) — "Tambah transaksi".
- Chips/segmented controls: pill, surfaceMuted background, selected = primary bg + white text.

## Iconography
Material Symbols Rounded, 22–24px, consistent rounded style. Use the same icon meanings as the current app
(wallet, receipt, pie chart, savings/piggy, more).

## Motion
Subtle: 200ms ease-out for state changes, progress bars animate on load, count-up on the hero balance, cards fade-up 8px on first render.

## Constraints
- Must be implementable in Flutter Material 3 (ThemeData + custom widgets); no web-only effects.
- Keep all existing content/features of each screen; redesign layout, hierarchy and style only.
- Indonesian copy exactly as in the app (e.g. "Ringkasan", "Pemasukan", "Pengeluaran", "Sisa anggaran", "Tagihan jatuh tempo").
