# Midwife Support Mobile - Midwife Tools

Flutter app for midwife case management and alerts.

## Configuration

### Backend URL

The app connects to the Położne backend at a configurable base URL. Update this based on your environment:

**Development (local):**
```bash
flutter run -d chrome --dart-define=BASE_URL=http://localhost:8000
flutter run -d emulator --dart-define=BASE_URL=http://10.0.2.2:8000
flutter run -d ios-simulator --dart-define=BASE_URL=http://localhost:8000
```

**With physical device (Android/iOS):**
Replace `<YOUR_MACHINE_IP>` with your development machine's IP address:
```bash
flutter run -d <device-id> --dart-define=BASE_URL=http://<YOUR_MACHINE_IP>:8000
```

**Example with IP:**
```bash
flutter run -d emulator --dart-define=BASE_URL=http://192.168.1.100:8000
```

The default is `http://localhost:8000` if not specified.

### Configuration Location

Backend URL and other settings are defined in [lib/config/config.dart](lib/config/config.dart).

## Running the App

```bash
# Web (connects to localhost:8000 by default)
flutter run -d chrome

# Android emulator (must use 10.0.2.2 for host machine)
flutter run -d emulator --dart-define=BASE_URL=http://10.0.2.2:8000

# iOS simulator
flutter run -d ios-simulator

# Physical device (use machine IP)
flutter run -d <device-id> --dart-define=BASE_URL=http://<YOUR_MACHINE_IP>:8000
```

## Backend Setup

Start the backend locally:
```bash
cd ../
python scripts/run_backend.py --no-docker --reset-env
```

Create a test account:
```bash
python scripts/create_test_account.py --email test@example.com --password test
```

Then log in via the app with those credentials.

## Troubleshooting

**"Connection refused" errors:**
- Make sure the backend is running (`python scripts/run_backend.py`)
- Check the BASE_URL matches your backend location
- For Android emulator, use `10.0.2.2` not `localhost`
- For physical devices, use your machine's LAN IP (check `ipconfig` on Windows)

**Token not persisting:**
- Ensure secure storage is working (may need Android/iOS setup for secure storage)
- Check browser storage for web (should use localStorage)

