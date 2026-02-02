# Deployment Guide

## Backend Deployment

### Option 1: Deploy as JAR

1. Build the JAR file:
```bash
cd backend
mvn clean package -DskipTests
```

2. Run the JAR:
```bash
java -jar target/aibro-backend-1.0.0-SNAPSHOT.jar
```

### Option 2: Docker Deployment

Create `backend/Dockerfile`:
```dockerfile
FROM openjdk:17-jdk-slim
WORKDIR /app
COPY target/aibro-backend-1.0.0-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Build and run:
```bash
docker build -t aibro-backend .
docker run -p 8080:8080 aibro-backend
```

### Option 3: Cloud Deployment

#### AWS Elastic Beanstalk
```bash
eb init -p java-17 aibro-backend
eb create aibro-env
eb deploy
```

#### Google Cloud Platform
```bash
gcloud app deploy
```

#### Heroku
```bash
heroku create aibro-backend
git push heroku main
```

## Flutter App Deployment

### Android (Google Play Store)

1. Update `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        applicationId "com.aibro.app"
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 1
        versionName "1.0.0"
    }

    signingConfigs {
        release {
            storeFile file("path/to/keystore.jks")
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

2. Build APK/AAB:
```bash
flutter build apk --release
# OR
flutter build appbundle --release
```

3. Upload to Play Console

### iOS (App Store)

1. Configure signing in Xcode
2. Update `ios/Runner/Info.plist` with app information
3. Build archive:
```bash
flutter build ipa --release
```
4. Upload to App Store Connect using Xcode or Transporter

### Windows Desktop

1. Build:
```bash
flutter build windows --release
```

2. Create installer using Inno Setup or similar tool

3. Output: `build/windows/runner/Release/`

### macOS Desktop

1. Configure signing and entitlements
2. Build:
```bash
flutter build macos --release
```

3. Create DMG installer
4. Notarize for distribution

### Linux Desktop

1. Build:
```bash
flutter build linux --release
```

2. Create AppImage, Snap, or DEB package:
```bash
# Using snapcraft
snapcraft

# Using AppImage
appimagetool build/linux/x64/release/bundle/
```

## Environment Configuration

### Production Backend (application-prod.yml)

```yaml
server:
  port: ${PORT:8080}

spring:
  datasource:
    url: ${DATABASE_URL}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}

logging:
  level:
    com.aibro: INFO
```

### Flutter Environment Variables

Create `lib/config/environment.dart`:
```dart
class Environment {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080/api',
  );
}
```

Build with environment:
```bash
flutter build apk --dart-define=API_URL=https://api.aibro.com
```

## CI/CD Pipeline

### GitHub Actions

Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy

on:
  push:
    branches: [ main ]

jobs:
  backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-java@v3
        with:
          java-version: '17'
      - run: cd backend && mvn clean package
      - name: Deploy to server
        run: |
          # Your deployment script

  android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: cd flutter_app && flutter pub get
      - run: cd flutter_app && flutter build apk --release
      
  ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: cd flutter_app && flutter pub get
      - run: cd flutter_app && flutter build ios --release
```

## Monitoring & Analytics

### Backend Monitoring
- Use Spring Boot Actuator
- Add endpoints: `/actuator/health`, `/actuator/metrics`
- Integrate with Prometheus/Grafana

### App Analytics
- Firebase Analytics
- Mixpanel
- Custom analytics service

## Security Checklist

- [ ] API keys stored securely (not in code)
- [ ] HTTPS enabled for all communications
- [ ] Rate limiting implemented
- [ ] Input validation on all endpoints
- [ ] SQL injection protection
- [ ] XSS protection
- [ ] CORS properly configured
- [ ] Authentication tokens expire
- [ ] Sensitive data encrypted
- [ ] Security headers configured

## Performance Optimization

### Backend
- Enable HTTP/2
- Configure connection pooling
- Add Redis caching for sessions
- Use CDN for static assets

### Flutter
- Enable code splitting
- Lazy load images
- Optimize bundle size
- Use const constructors
- Profile and optimize animations

## Support & Maintenance

1. Set up error tracking (Sentry, Rollbar)
2. Configure logging aggregation
3. Set up automated backups
4. Create runbooks for common issues
5. Monitor API usage and costs

