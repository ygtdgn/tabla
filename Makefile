-include signing.env
export UTIL_SIGN_IDENTITY

.PHONY: test app run

test:
	swift test

app:
	scripts/build-app.sh

# Quit politely first so applicationWillTerminate flushes pending saves (SIGTERM skips it);
# pkill is only the fallback. The pgrep guard keeps AppleScript from launching a stopped Util.
run: app
	@if pgrep -x Util >/dev/null; then \
		osascript -e 'quit app "Util"' || true; \
		for i in 1 2 3 4 5 6 7 8 9 10; do pgrep -x Util >/dev/null || break; sleep 0.3; done; \
	fi
	pkill -x Util || true
	rm -rf /Applications/Util.app
	cp -R build/Util.app /Applications/
	open /Applications/Util.app
