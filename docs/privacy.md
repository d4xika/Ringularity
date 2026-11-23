# Privacy information and consent

The onboarding screen shows privacy information and requires an explicit consent checkbox before the account/cloud features start.

Every backend request goes through `ConsentHttp`. Without consent, registration, login, authorization, connectivity checks, profile/security changes, health and activity transfers, deletion of individual activities, and exports are blocked before an HTTP request is sent. Withdrawal closes active clients and invalidates their responses. It does not reverse transfers completed before withdrawal.

The privacy information and withdrawal action are available in Settings under **Privacy and consent**. Withdrawal stops backend traffic and shows the consent screen again. This does not delete cached data or existing backend records.

| Data | Storage or recipient | Purpose |
| --- | --- | --- |
| Name and email; account password hash and authorization token | Ringularity backend, PostgreSQL | Account registration, authentication, management |
| Ring measurements, sleep data, timestamps and recorded activity details, including GPS routes where available | Account-specific local caches and Ringularity backend | History and synchronization |
| Goals and daily summaries | Device preferences | Local progress display |
| Login token and user ID | Platform secure storage on the device | Keeping the session |
| Consent version and acceptance time | Account-specific device preferences | Recording the current choice |
| Map tile coordinates, zoom level, IP address, technical request information | OpenStreetMap Foundation tile servers | Displaying the selected map area |
| Font requests, IP address and technical request information | Google font servers when fonts are not cached | Font delivery |
| JSON export | Temporary device file; chosen recipient/app if shared | Export requested by the user |

Map images are requested from `https://tile.openstreetmap.org/{z}/{x}/{y}.png`, using the app identifier `app.ringularity.mobile`. The selected tiles reveal the geographic area being viewed. The route overlay is drawn locally. The privacy screen links to the [OpenStreetMap Foundation privacy policy](https://osmfoundation.org/wiki/Privacy_Policy) and [Google Fonts privacy information](https://developers.google.com/fonts/faq/privacy).

## Hosting and data retention

The Ringularity backend is available at `https://ringularity.d4xika.com/api` and is hosted by Contabo in the EU region. Account and synchronized health data are stored in PostgreSQL, with persistent storage on the database's Docker host.

## Account deletion

Under **Settings → Delete account**, users confirm permanent deletion with their current password and an explicit confirmation checkbox. `DELETE /api/users/account` requires the account ID, authorization token and current password. The backend deletes the account and all associated data collections.

Account deletion does not erase measurements stored on the ring, caches on other devices, previously shared exports, provider logs or backups. The ring can be reset separately under **Device Management → Factory Reset**.

The [account deletion test](account-deletion-test.md) documents the automated backend checks and their results for acceptance.
