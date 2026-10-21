# Before App Store submission

- In App Store Connect → Business, personally accept the Paid Apps Agreement and complete banking and tax information. This is the payout account, not the payment card on your Apple ID. Apple pays proceeds after applicable fees and taxes. [Apple setup guide](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/).
- Create three repeatable consumable products: `com.harshulkuhar.dexduo.tip.small` ($0.99 US base), `.tip.medium` ($2.99), `.tip.large` ($4.99). Configure availability and submit them for review with the app. Local StoreKit testing does not establish real purchase availability.
- Confirm rights to Pokémon names, artwork and the cover design. Attribution and an unofficial disclaimer do not replace permission.
- Complete privacy labels, required privacy-manifest review, age rating, description, keywords, pricing and review notes. Use the published privacy and support URLs.
- The target currently supports iPad. Test it and supply its required screenshots, or remove support through a separate change.
- Run TestFlight, a submission-eligible Xcode archive validation, physical camera/speech/performance checks and actual Duo hardware tests when available. Simulator results do not replace hardware validation.

No financial details or agreements are handled by development automation. [Apple screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [review guidelines](https://developer.apple.com/app-store/review/guidelines/) remain the submission authority.
