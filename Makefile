-include signing.env
export UTIL_SIGN_IDENTITY

.PHONY: test app run

test:
	swift test

app:
	scripts/build-app.sh

run: app
	pkill -x Util || true
	rm -rf /Applications/Util.app
	cp -R build/Util.app /Applications/
	open /Applications/Util.app
