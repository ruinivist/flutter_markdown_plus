# Launches the Plane comparison preview from the local example app.
# Used during renderer development with Flutter hot reload.
.PHONY: preview

preview:
	cd example && CHROME_EXECUTABLE=/usr/bin/chromium flutter run -d chrome --web-port 7357 -t lib/plane_preview.dart
