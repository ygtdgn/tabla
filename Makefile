-include signing.env
export UTIL_SIGN_IDENTITY

.PHONY: test app run icon

test:
	swift test

app:
	scripts/build-app.sh

# Regenerates Resources/AppIcon.icns after Resources/AppIcon.svg changes.
icon:
	scripts/make-icon.sh

# Quit politely first so applicationWillTerminate flushes pending saves (SIGTERM skips it);
# pkill is only the fallback. The pgrep guard keeps AppleScript from launching a stopped app.
# "Util" is the app's pre-rename name: it is quit and its old copy removed once, on upgrade.
run: app
	@for name in Util Tabla; do \
		if pgrep -x $$name >/dev/null; then \
			osascript -e "quit app \"$$name\"" || true; \
			for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x $$name >/dev/null || break; sleep 0.3; done; \
		fi; \
		pkill -x $$name || true; \
	done
	rm -rf /Applications/Util.app /Applications/Tabla.app
	cp -R build/Tabla.app /Applications/
	open /Applications/Tabla.app
