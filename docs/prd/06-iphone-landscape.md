# 06 — Ordinary iPhone landscape support

Status: implementation and validation in progress. Branch: `codex/iphone-landscape`. Implement before new detail features.

## Requirement

Ordinary iPhones use DexDuo in landscape only. Every app-owned screen fits without scrolling. Preserve Duo's portrait cover, landscape interior presentation, fixed fold orientation and retained artwork. The red shell fills the display, interactive content respects safe areas, and the divider between equal panels is centered within the usable content width.

## Orientation architecture

Distinguish a hinge-capable Duo from an ordinary phone using the available hardware context, not a display-name string or aspect ratio alone. Keep Duo's UIKit scene in its existing fixed orientation and apply the interior transform as before. Folding changes cover/interior state, never supported orientation masks.

Ordinary phones support landscape left and right, with no portrait app layout. Declare the necessary orientation union in the generated plist, then provide the correct capability-specific mask. Resolve hardware capability before presenting interactive content; handle delayed initial hinge context without a transient rotated cover or incorrect phone mask. Any orientation request belongs to capability initialization or an ordinary-phone landscape direction change, not a fold callback. Respect the deployment target by availability-gating newer APIs.

On an ordinary phone, cold launch shows a text-free cover sized for landscape, with the blue lens, indicator lights, stepped seam and yellow triangle. Tap anywhere to open. The Cover button retains the selected Pokémon and loaded artwork. Returning from the background preserves the open/closed state. Rotation between ordinary landscape directions must stay upright; there is no supported portrait content mode.

## Layout

Replace the oversized design-canvas `scaleEffect` approach in the interior and scanner with sizes derived from available safe width and height. Use two equal content panels and a narrow centered divider when space allows. Reduce decorative header/artwork space before reducing readable text or tap targets.

Use at least 14-point normal body text and 44-point primary hit areas. The 44-point toolbar contains the lens/indicator cluster, search, Scan and Cover. Use 12-point horizontal margins and 8-point spacing. Detail tabs are Info, Stats and Types; evolution and speech controls belong to later features. The artwork, number, name, separately colored type badges and previous/next controls remain on the left. The all-18-type grid remains on the right. Long names wrap appropriately; long descriptions and conditions use word-boundary paging with visible page controls. Stats and abilities may use separate pages on compact heights. Do not truncate away content as a substitute for scrolling.

At large accessibility sizes, switch to an explicit single-panel pager (Artwork / Details) rather than shrinking the entire interface. All content and actions remain reachable through buttons. Test Dynamic Type through XXXL and accessibility sizes with this alternative layout; VoiceOver must read complete names, values and page state.

## Search and keyboard

Keep one stable search-field instance and binding throughout typing. Keyboard appearance must not recreate the field or change the app's coordinate system. Use a focused search presentation with the field and at least one reachable result above the keyboard; show up to three results when height permits, with paging for additional matches. Hide lower-priority detail content temporarily if needed, preserving the selected entry and tab.

Autocomplete, clear/retype, paste, submit, dismissal and a failed search must work on compact phones. Search focus is dismissed on scanner presentation and fold. The keyboard must not obscure the only result/action controls or make the app scroll.

## Scanner

Use a compact landscape arrangement for image preview, Camera/Import, message, up to three candidate choices, Retry and Done. Page candidate choices if text size requires it. Preserve the selected photo and retry state while switching pages. Do not reduce the entire portrait scanner canvas to unreadable dimensions.

System Photos/camera screens follow Apple's layout behavior; the no-scroll requirement applies to DexDuo-owned views. Recognition and generation-token cancellation behavior are unchanged.

## Acceptance and tests

| Configuration | Checks |
| --- | --- |
| 667×375 landscape | All tabs/actions reachable; descriptions and abilities paginate; no overlap |
| 812×375 notched landscape | Both landscape directions; safe-area clearances and centered divider |
| Larger ordinary iPhone | Uses available width; no large dead margins or scaled-down controls |
| Duo folded | Full red text-free cover, no interior flash, no orientation animation |
| Duo unfolded | Equal panels, retained sprite, complete search and scanner behavior |
| Accessibility sizes | Single-panel paging, readable labels and full VoiceOver content |

Unit tests cover layout capacity/page boundaries and capability-specific orientation policy. UI tests cover typing multiple characters, clear/retype, keyboard result selection, all detail pages, import/candidate selection, failed lookup retry and both phone landscape directions. Check control bounds and absence of app-owned scroll views.

Repeat at least 20 Duo fold/unfold cycles, including during search and recognition; confirm no late lookup, rotation or sprite reload. Compare the known simulator fold artifacts with system apps so platform rendering issues are not mistaken for layout regressions.

Record physical-device cutout, touch-target and camera checks separately from Simulator verification. Do not claim the Xcode download or syntax parsing is an iOS runtime test.
