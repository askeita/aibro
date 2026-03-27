# Contributing to AiBro

Thank you for your interest in contributing to AiBro – an AI‑assisted brainstorming tool built with a Spring Boot backend and a Flutter frontend.

This document expands on the short checklist in the README and explains how to set up your environment, propose changes, and open pull requests in a way that keeps the project maintainable.

---

## Ways to Contribute

- **Bug reports** – Problems you encounter while running the backend or Flutter app.
- **Feature requests** – Ideas to improve the brainstorming experience, AI behavior, or UX.
- **Documentation** – Improvements to README, QUICKSTART, deployment docs, or in‑code docs.
- **Code contributions** – Backend (Java/Spring Boot) or frontend (Flutter/Dart) changes.

Before starting work on a larger feature, consider opening an issue to discuss the approach.

---

## Development Environment

### Backend (Spring Boot)

- Java 17+
- Maven 3.6+

Setup:

```bash
cd backend
mvn clean install
mvn spring-boot:run
```

The backend runs on `http://localhost:8080`.

### Frontend (Flutter)

- Flutter 3.0+ with a working toolchain for your target platforms

Setup:

```bash
cd flutter_app
flutter pub get
flutter run -d linux   # or android / ios / windows / macos
```

Make sure you can run **both** backend and frontend locally before submitting code changes.

---

## Git Workflow

The short checklist from the README becomes:

1. **Fork the repository**
   - Click "Fork" on GitHub to create your own copy.

2. **Create a feature branch**
   - Base your work on the latest `main` branch.
   - Use a descriptive name, e.g. `feature/session-timer-ui`, `fix/audio-calibration-bug`.
   - Example:
     ```bash
     git checkout main
     git pull origin main
     git checkout -b feature/short-description
     ```

3. **Make and test your changes**
   - Keep changes focused on a single problem or feature.
   - Backend:
     - Build: `cd backend && mvn clean install`
   - Flutter app:
     - Analyze: `cd flutter_app && flutter analyze`
     - Run tests (if you add tests): `flutter test`

4. **Write clear commits**
   - Commit early and often, but keep commits coherent.
   - Use meaningful messages, e.g. `Fix STT diarization mapping edge case` rather than `fix`.
   - Example:
     ```bash
     git add .
     git commit -m "Short, descriptive summary of the change"
     ```

5. **Push your branch and open a Pull Request**
   - Push to your fork:
     ```bash
     git push origin feature/short-description
     ```
   - Open a Pull Request (PR) against the upstream `main` branch.
   - In the PR description, include:
     - What you changed and why
     - How you tested it (commands, manual steps)
     - Any impact on API contracts, WebSocket topics, or configuration

---

## Coding Guidelines

### General

- Prefer **small, focused PRs** over large, unrelated changes.
- Keep changes consistent with the existing style and structure.
- Avoid introducing new libraries unless necessary; discuss major additions in an issue first.

### Backend (Java / Spring Boot)

- Follow the existing package structure under `backend/src/main/java/com/aibro`:
  - `controller` – REST & WebSocket entrypoints
  - `service` – business logic and integrations
  - `dto` – request/response models
  - `model` & `repository` – persistence layer
- When adding new endpoints:
  - Add/extend a controller.
  - Introduce or update DTOs rather than exposing entities directly.
  - Implement business logic in a service (do not put logic in controllers).
  - Update or add configuration in `backend/src/main/resources/application.yml` if needed.
- Keep method and class names descriptive and aligned with the current naming conventions.

### Frontend (Flutter / Dart)

- Follow the structure under `flutter_app/lib`:
  - `models` – data models mirroring backend DTOs where relevant
  - `services` – API/WebSocket and domain logic
  - `screens` – top‑level UI screens
  - `widgets` – reusable components
  - `utils` – helpers
- Prefer composition of small widgets over very large widget trees in a single file.
- Keep state management consistent with the current patterns (e.g., Provider/BLoC as used in the project).

---

## Testing and Quality

- **Backend**
  - Ensure `mvn clean install` passes before opening a PR.
  - Add or update tests when you touch non‑trivial logic where practical.

- **Frontend**
  - Ensure `flutter analyze` runs cleanly.
  - Run `flutter test` when you add or modify tests.

If you cannot run certain tests (e.g., platform specific), mention that in your PR.

---

## Documentation Updates

- Update `README.md`, `QUICKSTART.md`, or other docs when behavior, configuration, or commands change.
- For new endpoints or contracts, keep DTOs and examples in sync with the implementation.

---

## Reporting Issues

When opening an issue, please include:

- **Environment** – OS, Java version, Flutter version, device/emulator details.
- **Steps to reproduce** – Clear, minimal steps.
- **Expected vs actual behavior** – What you thought would happen vs what you observed.
- **Logs / stack traces** – When available, redact any secrets.

---

## Code of Conduct

Please be respectful and collaborative. Assume good faith, and keep reviews and discussions focused on the code and product. The maintainers reserve the right to close issues or PRs that are not constructive.
