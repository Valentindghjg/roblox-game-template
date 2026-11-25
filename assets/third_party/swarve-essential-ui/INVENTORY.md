# Essential UI Pack (Swarve Studios): inventory

What the pack contains, read with Lune on 2026-11-25 from the owner's local `Essential UI Pack - Swarve Studios.rbxl` (the pack's scripts were not run). Licence: `LICENSE.md` in this folder. The `.rbxl` itself stays local and gitignored; put a copy into this folder to inspect it.

## Structure
- `StarterGui.GUI` (one ScreenGui):
  - `HUD`: left button rail `Left.Buttons1` (Index, Rebirth, Shop) and `Left.Buttons2` (Invite, Wheel), a currency bar (`Currency`), a promo button `Right.Random` with a rotating sunburst, a `Drop` banner.
  - `Frames`: `Shop` (title bar with close, scrolling cards: StarterPack, ProPack, ItemsOnly, CashOnly), `Upgrades` (upgrade card with before/after stats, money and Robux buttons), `Rebirth`, `Index` (Normal, Golden, Diamond tabs), `Wheel` (paid spin wheel), `Notifications` (fading text toast).
  - `Effect`: four decorative images.
- Counts: 68 Frame, 82 TextLabel, 29 TextButton, 78 ImageLabel, 1 ImageButton, 6 ScrollingFrame, 113 UIStroke, 22 UIGradient, 58 UIAspectRatioConstraint, 24 UIListLayout, 3 UIGridLayout.
- Scripts (not to be used): per-button hover LocalScripts, `NotificationService`, configs (Shop, Rebirth, Wheel, CoinPack), server `PurchaseHandler`, `RebirthHandler`, `WheelHandler`, `CoinPackHandler`, `ReceiptHandler`, `leaderstats`, 11 RemoteEvents, `Workspace.Parts` coin and strength pickups.

## Style values
- Fonts: `GothamSSm` Heavy (72 labels), font asset `rbxassetid://11702779517` Heavy (10 labels), `SourceSansPro` Regular on buttons (text hidden behind images).
- Strokes: all 113 `UIStroke` have Thickness 3.
- Button interaction (every HUD and frame button): hover scales the size to 110 % in 0.2 s, press to 90 % in 0.1 s, release back to hover size, EasingStyle Quad, Out. Hover sound `rbxassetid://139800881181209` at volume 0.5, click sound `rbxassetid://88442833509532` at volume 0.7. Wheel spin sound `rbxassetid://140489335105298`.
- Notification: text fades in 0.5 s (Quad Out), stays `duration` (default 3 s), fades out 0.5 s (Quad In).

## Images (author's uploads, `rbxassetid://`)
| ID | Used for |
|---|---|
| 131343092776040 | Shop title background |
| 100627035489276 | Index and Upgrades title background |
| 120692375639753 | Rebirth title background |
| 86216771097425 | close button background (5 frames) |
| 87326447332057 | primary action button background (7 uses) |
| 139418228897608 | Robux and money button background (6 uses) |
| 100506345795869 | upgrade money button background |
| 82312491077959 | Rebirth skip button background |
| 131798641019550 | Robux button and Diamond tab background |
| 105351427848376 | second Robux button background |
| 110828187234554 / 115624555582768 | Index Normal / Golden tab background |
| 120342677944790 | shop card background (4 uses) |
| 119496692548587 | cash pack image (5 uses) |
| 130412104971687 | shop item image (7 uses) |
| 97493315422791 / 138787751104353 / 127981244153803 / 138297996642417 / 72230557461051 | HUD icons Shop / Index / Rebirth / Wheel / Invite |
| 126698472806052 / 101335357428300 | promo image and its sunburst |
| 92958786684902 | Drop banner background |
| 139223624814827 | upgrade card image |
| 87652362787600 / 88353043959572 | money icon / before-after arrows |
| 103598277905609 / 102978147512911 / 85077398338133 / 116523829948125 | strength icons and "?" (Index) |
| 131708002708097 | decorative effect image (4 uses) |
| 15961470200 / 108336300645944 / 77319404533832 / 94539448210782 | wheel, wheel background, wheel segment icons, wheel arrow |

All ImageLabels use ScaleType Stretch (no 9-slice). The images are pre-coloured; `ImageColor3` can only darken or tint them.
