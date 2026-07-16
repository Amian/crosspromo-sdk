# App Store Connect privacy choices

CrossPromo records anonymous ad impressions and clicks. It does not store a device ID,
installation ID, account ID, IP address, user agent, or locale, and it does not track
people across apps.

Before submitting an app version that contains CrossPromo:

1. Open **App Store Connect → Apps → your app → App Privacy**.
2. Beside **Data Types**, choose **Edit**. Keep every choice your app already needs.
3. Under **Usage Data**, add **Product Interaction** and **Advertising Data**.
4. Open each of those two data types and choose the same answers:
   - **Purposes:** select **Third-Party Advertising** and **Analytics**.
   - **Linked to the user’s identity:** **No**.
   - **Used for tracking:** **No**.
5. Choose **Publish** when every data type is complete.

For CrossPromo, do **not** add **Device ID** and do **not** enable an App Tracking
Transparency prompt. These instructions cover CrossPromo only; do not remove privacy
answers required by the rest of your app or its other SDKs.

[Apple’s official App Privacy instructions](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
