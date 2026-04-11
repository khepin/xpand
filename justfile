plist := "~/Library/LaunchAgents/com.seb.xpand.plist"

build:
    swift build -c release

run:
    swift run xpand

install: build
    launchctl load {{plist}}

uninstall:
    launchctl unload {{plist}}

status:
    launchctl list | grep xpand

log:
    tail -f /tmp/xpand.log

restart: uninstall install
