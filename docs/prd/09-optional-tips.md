# Optional support

Use StoreKit 2 consumables `com.harshulkuhar.dexduo.tip.small`, `.medium` and `.large`, with US base prices $0.99/$2.99/$4.99 and Apple-localized display prices. No features, subscription or charitable donation is attached.

A single app-owned TipStore loads products, listens for verified updates, processes unfinished transactions and persists supporter status before finishing. In-flight purchase calls are serialized. Cancellation, pending approval, verification/network errors do not count as support. Duplicate callbacks are ignored.

The first foreground session each local calendar day can show an offer after opening/unfolding. Persist session and attempt dates; skip unavailable/busy days and never interrupt ongoing use at midnight. Inactive interruptions alone do not start a new session. Successful supporters never receive automatic prompts on this installation; the Info footer retains manual access. Local state may reset on reinstall. Narration stops for the panel and does not restart on dismissal. Not now stays outside the scrolling content, including at accessibility sizes.

Test catalog is in test bundles only. Verify calendar/DST/relaunch behavior, unavailable products, cancellation, pending/error/unverified results, duplicate callbacks, unfinished transactions, supporter suppression and native repeatable purchases. Verify phone/Duo dismissal, manual access, relaunch and larger text. Account purchases and hardware validation remain outstanding.
