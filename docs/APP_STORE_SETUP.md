# Before App Store submission

- In App Store Connect → Business, personally accept the Paid Apps Agreement and complete banking and tax information. This is the payout account, not the payment card on your Apple ID. Apple pays proceeds after applicable fees and taxes. [Apple setup guide](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/).
- Create three repeatable consumable products: `com.harshulkuhar.dexduo.tip.small` ($0.99 US base), `.tip.medium` ($2.99), `.tip.large` ($4.99). Configure availability and submit them for review with the app. Local StoreKit testing does not establish real purchase availability.
- Confirm rights to Pokémon names, artwork and the cover design. Attribution and an unofficial disclaimer do not replace permission.
- Complete privacy labels, required privacy-manifest review, age rating, description, keywords, pricing and review notes. Use the published privacy and support URLs.
- The target currently supports iPad. Test it and supply its required screenshots, or remove support through a separate change.
- Run TestFlight, a submission-eligible Xcode archive validation, physical camera/speech/performance checks and actual Duo hardware tests when available. Simulator results do not replace hardware validation.

No financial details or agreements are handled by development automation. [Apple screenshot requirements](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) and [review guidelines](https://developer.apple.com/app-store/review/guidelines/) remain the submission authority.

## Release identity and Xcode Cloud

The app uses bundle ID `com.dexduo.app`, marketing version `1.0` and build number `1`. Use the matching existing App Store Connect record and its Apple Developer team. The prior bundle ID may already belong to another team; the repository alone cannot establish its ownership. Changing bundle ID creates a separate installed app, so old caches/preferences do not migrate automatically.

The consumable product IDs remain `com.harshulkuhar.dexduo.tip.small`, `.medium` and `.large`; product IDs do not need to share the bundle-ID prefix. Create them under the new app record exactly as configured in the code.

The GitHub owner should follow [Apple’s Xcode Cloud connection flow](https://developer.apple.com/documentation/xcode/connecting-xcode-cloud-to-github): authorize the official [Xcode Cloud GitHub app](https://github.com/apps/xcode-cloud), choose **Only select repositories**, and select **harshulkuhar/dexduo**. Return to App Store Connect/Xcode to finish the workflow and choose the correct app/team. This permission is separate from inviting a human collaborator; no collaborator access is required simply to connect Apple’s app. GitHub owner authorization and Apple account configuration are not performed by the source-code change.
