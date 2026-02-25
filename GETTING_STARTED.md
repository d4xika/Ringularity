# 🚀 Getting Started with Ringularity

<p align="center">
  <img src="ringularity/assets/logo_transparent.png" alt="Ringularity Logo" width="150"/>
</p>

This guide walks you through everything you need to get the Ringularity app running — from setting up the development environment to pairing your smart ring for the first time.

---

## 📋 Prerequisites

Before you begin, make sure you have the following installed:

| Tool | Version | Notes |
|---|---|---|
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | ≥ 3.x | Required for the mobile app |
| [Dart SDK](https://dart.dev/get-dart) | ^3.9.2 | Bundled with Flutter |
| [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) | Latest | For Android/iOS builds |
| [Ruby](https://www.ruby-lang.org/) | ≥ 3.x | Required to run the backend locally |
| [PostgreSQL](https://www.postgresql.org/) | ≥ 14 | Required for the backend database |
| [Docker](https://www.docker.com/) | Latest | Alternative to local backend setup |

> **Note:** A physical device is strongly recommended for BLE (Bluetooth) testing. Most BLE features do not work on emulators.

---

## 📁 Project Structure

```
Ringularity/
├── README.md
├── GETTING_STARTED.md       ← You are here
└── ringularity/
    ├── lib/                 ← Flutter app source code
    │   ├── main.dart
    │   ├── screens/         ← UI screens (auth, home, details, activity)
    │   ├── services/        ← Business logic (BLE, API, health, user)
    │   ├── widgets/         ← Reusable UI components
    │   ├── models/          ← Data models
    │   └── theme/           ← Colors, text styles
    ├── android/             ← Android platform files
    ├── ios/                 ← iOS platform files
    ├── assets/              ← Images, fonts, etc.
    ├── pubspec.yaml         ← Flutter dependencies
    └── backend/             ← Ruby on Rails API
```

---

## 🛠 Part 1: Setting Up the Flutter App

### Step 1 — Clone the Repository

```bash
git clone <repository-url>
cd Ringularity/ringularity
```

### Step 2 — Install Flutter Dependencies

```bash
flutter pub get
```

### Step 3 — Configure the API Endpoint

The app communicates with the Ringularity backend. You need to point it to your backend instance (local or production).

Open `lib/services/api/api_service.dart` and update the base URL:

```dart
// Example for local development:
static const String baseUrl = 'http://[IP_ADDRESS]';
```

### Step 4 — Platform Permissions

#### Android
The required permissions are already declared in `android/app/src/main/AndroidManifest.xml`. No extra steps needed.

#### iOS
Ensure the following keys are present in `ios/Runner/Info.plist`:
- `NSBluetoothAlwaysUsageDescription`
- `NSLocationWhenInUseUsageDescription`

These are already included in the project.

### Step 5 — Run the App

Connect a **physical device** via USB (recommended), then run:

```bash
flutter run
```

To run on a specific device:

```bash
flutter devices          # List available devices
flutter run -d <device-id>
```

---

## 🗄 Part 2: Setting Up the Backend

The backend is a **Ruby on Rails 7 API** backed by **PostgreSQL**. You can run it locally or via Docker.

### Option A — Local Development (Recommended for Coding)

1. **Navigate to the backend directory:**
   ```bash
   cd ringularity/backend
   ```

2. **Install Ruby dependencies:**
   ```bash
   bundle install
   ```

3. **Set up environment variables** by creating a `.env` file:
   ```env
   DB_HOST=localhost
   DB_NAME=ringularity_production
   DB_USER=postgres
   DB_PASSWORD=your_password
   RAILS_MASTER_KEY=your_generated_key
   ```

4. **Set up the database:**
   ```bash
   bin/rails db:prepare
   ```

5. **Start the server** (accessible from other local devices):
   ```bash
   bin/rails s -b 0.0.0.0
   ```

   The backend is now running at `http://localhost:3000`.

### Option B — Docker (Recommended for Consistency)

1. **Build and start containers:**
   ```bash
   docker-compose up --build
   ```

2. **Prepare the database** (first time only):
   ```bash
   docker-compose run web bin/rails db:prepare
   ```

### Verifying the Backend

Open a browser or use `curl` to check the health endpoint:

```
GET http://localhost:3000/api/alive
Expected response: {"status": "ok"}
```

For more backend details, see the [Backend README](ringularity/backend/README.md).

---

## 💍 Part 3: Connecting Your Smart Ring

The app supports **Colmi-compatible smart rings**, including:

- **Colmi R02, R06, R10, R12**
- Any ring advertising itself as "Ring", "Yawell", or "Colmi"

### Step 1 — Enable Bluetooth on Your Phone

Make sure Bluetooth is **enabled** on your phone before opening the app. On Android, also ensure **Location** is enabled (required for BLE scanning by the OS).

### Step 2 — Register or Log In

1. Launch the app on your device.
2. On the welcome screen, tap **Register** to create a new account, or **Login** if you already have one.

   > **Offline mode:** If the backend is unreachable, you'll see an "You are offline!" notice. Login/Register requires an active internet connection.

### Step 3 — Navigate to Settings

1. After logging in, you'll land on the **Dashboard**.
2. Tap the **Settings** icon (the gear icon in the navigation bar).

### Step 4 — Pair Your Ring

1. In the **Device Management** section, tap **"Connect Device"**.
2. The app will automatically begin scanning for nearby compatible rings.
3. Your ring should appear in the list within a few seconds. If it doesn't:
   - Make sure the ring is charged and powered on.
   - Try wearing the ring to ensure the sensors are active.
   - Move the ring closer to your phone.
4. Tap on your ring in the list to initiate the connection.
5. The app will **bind** to the ring — this is a one-time pairing step that registers the device.

### Step 5 — Verify Connection

Once connected, the device card in Settings will display the ring's **name** and **battery level**. The dashboard will begin showing live data shortly after.

### Auto-Reconnect

Once paired, the ring will **automatically reconnect** the next time you open the app, as long as Bluetooth is enabled. You do not need to re-pair each time.

---

## 🔄 Data Sync

After connecting, Ringularity will automatically:

- **Sync historical data** from the ring (HR, HRV, Stress, Steps, Sleep) on app launch.
- **Upload synced data** to the backend for cloud storage and cross-device access.
- **Poll for new data** in the background while the app is in use.

You can also trigger a manual sync from the Settings screen.

---

## 🐛 Troubleshooting

### The app gets stuck on the loading/splash screen
- Check that the backend is running and reachable.
- Verify the API URL in `api_service.dart` is correct.
- The app will time out and switch to offline mode after a few seconds if the backend is unreachable.

### My ring doesn't appear during scanning
- Ensure Bluetooth and Location are both enabled on your phone.
- Confirm the ring name matches one of the supported devices: `R02`, `R06`, `R10`, `R12`, `Ring`, `Yawell`, `Colmi`.
- Try restarting both the ring and the app.

### Data isn't syncing
- Check the connection status indicator on the Settings screen.
- Make sure the backend server is running and the app's base URL is correct.
- Ensure the ring stays close to your phone during an initial full sync.

### Build errors after `flutter pub get`
- Run `flutter clean` and then `flutter pub get` again.
- Make sure your Flutter SDK is up to date: `flutter upgrade`.

---

## 📚 Further Reading

- [Backend README](ringularity/backend/README.md)
