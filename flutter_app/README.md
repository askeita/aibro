# AiBro Flutter App

Flutter frontend for AiBro – an AI-assisted brainstorming companion that records sessions, transcribes discussions, and generates rich reports.

## Key Screens & Features

- **Home**
	- Start a new brainstorming session (participants, objective, optional voice calibration).
	- Navigate to **Previous sessions** (local audio recordings).
	- Navigate to **View Reports** (local report files and report details).
	- Open **Settings** to configure AI model, contribution frequency, and API keys.

- **Session**
	- Real-time audio capture with optional full-session recording.
	- Live AI contributions via the configured model.
	- Optional session timer (elapsed or countdown).
	- On end, generates a session report and offers report export.

- **Previous Sessions**
	- Lists all full-session audio recordings stored under the device `aibro/audios` folder.
	- Per recording actions:
		- **Play** icon: open and play the audio with the system's default audio handler.
		- **Open location** icon: on desktop opens the containing folder; on mobile opens the file in a suitable app.
		- **Share** icon: share the audio via other apps; if generic sharing is unavailable, opens the default email client pre-filled so the recording can be sent by email.
		- **Delete** icon: remove the recording from the device.

- **View Reports**
	- Scans the local `aibro/reports` folder and lists all generated Word-compatible `.rtf` session reports (newest first).
	- Per report actions:
		- **Document icon**: open the `.rtf` file with the system's default document app.
		- **Row tap**: open a **Report detail** screen that reconstructs the report from the backend (session metadata, ideas by participant, contributions timeline, and AI summary).
		- If the related session no longer exists on the backend (e.g. after an H2 reset), the detail screen shows a clear message and advises using the file icon instead.

## Running the App

From the repository root:

```bash
cd flutter_app
flutter pub get
flutter run -d linux   # or android/ios/windows/macos
```

Make sure the backend is running at `http://localhost:8080` so that session and report APIs are available.
