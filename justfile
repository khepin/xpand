domain := "gui/" + `id -u`
service := "com.seb.xpand"
plist := home_directory() / "Library/LaunchAgents/com.seb.xpand.plist"

build:
    swift build -c release

run:
    swift run xpand

install: build
    launchctl bootstrap {{domain}} {{plist}}

uninstall:
    launchctl bootout {{domain}}/{{service}}

status:
    launchctl list | grep xpand

log:
    tail -f /tmp/xpand.log

stop:
    launchctl stop com.seb.xpand

start:
    launchctl start com.seb.xpand

restart: uninstall install
