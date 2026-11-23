import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api/api_service.dart';

/// Explains which account, health and activity data is stored locally or transferred.
///
/// Describes the backend, OpenStreetMap tile requests, Google Fonts and user-triggered
/// exports, including separate recipients, caching and retention considerations.
/// Policy links only open an external browser when the user selects them.
class PrivacyInformation extends StatelessWidget {
  /// Creates privacy information shared by consent onboarding and settings.
  const PrivacyInformation({super.key});

  /// Builds the storage and recipient sections together with the configured backend origin.
  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('privacy-information'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Privacy information",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final section in const [
          (
            id: "account",
            title: "Account information",
            body:
                "Registration sends your name, email address and password to the backend. The backend stores account information, a password hash and an authorization token.",
          ),
          (
            id: "health",
            title: "Health and activity information",
            body:
                "When synchronized, your ring measurements (heart rate, HRV, stress values, steps, distance, sleep stages and measurement times) and recorded activities are assigned to your account in the backend. Activities can include type, title, duration, distance, steps, heart-rate measurements and a recorded GPS route with position information and timestamps.",
          ),
          (
            id: "device",
            title: "On this device and on the ring",
            body:
                "The app caches profiles, activities, recent measurements, daily summaries and goals on this device, separated by account. These app preferences are not additionally encrypted by Ringularity. Login tokens are stored separately using the platform’s secure storage. The consent version and acceptance time are saved locally for each account. Signing out clears login credentials but retains account-specific caches. The ring can also retain measurements in its own memory.",
          ),
          (
            id: "backend",
            title: "Ringularity backend",
            body:
                "The backend is hosted with Contabo in the EU region and managed through Portainer. Account, health and activity records are stored in the backend’s PostgreSQL database, whose data directory is persistently mounted on the Docker host. Backend transfers use HTTPS. Technical requests can also appear in server logs; their contents and retention depend on the server configuration. The app currently uses this backend address:",
          ),
          (
            id: "maps",
            title: "Maps from OpenStreetMap",
            body:
                "Opening a recorded route loads map images directly from the OpenStreetMap Foundation’s tile service. Its servers receive your IP address, the requested map tiles and zoom level, request times and technical request information such as the app identifier. The selected tiles reveal the displayed geographic area and may indicate parts of your route. The route line is drawn locally on your device; tile images may be cached locally. Map requests go to this external service separately from the Ringularity backend.",
          ),
          (
            id: "fonts",
            title: "Fonts from Google",
            body:
                "The app uses Google Fonts. Fonts that are not yet cached may be downloaded from Google’s font servers, such as fonts.gstatic.com. Google then receives your IP address and technical information about the font request. Downloaded font files may be cached on your device.",
          ),
          (
            id: "exports",
            title: "Exporting your data",
            body:
                "A requested JSON export downloads your account, health and activity data from the backend and saves a temporary file on this device. If you share it, the chosen app or recipient receives that file.",
          ),
          (
            id: "retention",
            title: "Retention and withdrawal",
            body:
                "The app periodically removes older detailed measurements from its short-term cache. Other account-specific caches and backend records have no automatic deletion deadline. Under Settings → Delete account, you can permanently delete your account and all associated health and activity records from the backend database by confirming your current password. This also removes the account’s caches and temporary exports on this device and signs you out. Data on the ring, other devices, provider logs, backups and files already shared is not erased. Withdrawing consent alone stops further backend transfers; local caches and existing backend records remain. Provider logs and backups can have separate retention periods.",
          ),
        ]) ...[
          const SizedBox(height: 20),
          Text(section.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(section.body),
          if (section.id == 'backend') ...[
            const SizedBox(height: 8),
            SelectableText(ApiService.backendOrigin),
          ],
          if (section.id == 'maps') ...[
            const SizedBox(height: 8),
            const SelectableText('tile.openstreetmap.org'),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://osmfoundation.org/wiki/Privacy_Policy'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text("OpenStreetMap privacy policy"),
            ),
          ],
          if (section.id == 'fonts')
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse('https://developers.google.com/fonts/faq/privacy'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text("Google Fonts privacy information"),
            ),
        ],
      ],
    );
  }
}
