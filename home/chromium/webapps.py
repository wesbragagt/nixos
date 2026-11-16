import argparse
import os
from pathlib import Path
import re
import sys
from urllib.parse import urlparse
from urllib.request import urlopen

import yaml


def load():
    path = Path.home() / ".config/chromium-profiles/config.yaml"
    if not path.exists():
        return {}, {}
    config = yaml.safe_load(path.read_text()) or {}
    profiles = config.get("profiles", {})
    apps = config.get("apps", {})
    for key, app in apps.items():
        if not re.fullmatch(r"[A-Za-z0-9_-]+", key):
            raise ValueError(f"Invalid app ID: {key}")
        if urlparse(app["url"]).scheme not in ("https", "http"):
            raise ValueError(f"Invalid URL for {key}")
        if app["profile"] not in profiles:
            raise ValueError(f"Unknown profile for {key}: {app['profile']}")
        for field in ("name", "url", "icon"):
            if "\n" in str(app.get(field, "")) or "\r" in str(app.get(field, "")):
                raise ValueError(f"Invalid {field} for {key}")
    return profiles, apps


def desktop_quote(value):
    value = str(value).replace("%", "%%")
    for char in ("\\", '"', "`", "$"):
        value = value.replace(char, "\\" + char)
    return '"' + value + '"'


def main():
    parser = argparse.ArgumentParser(description="Generate launchers from local Chromium web app configuration")
    parser.add_argument("action", choices=["sync", "launch"])
    parser.add_argument("app", nargs="?")
    args = parser.parse_args()
    profiles, apps = load()
    if args.action == "launch":
        app = apps[args.app]
        command = [os.environ["WEBAPP_PROFILE"], app["profile"],
                   "--window-name=" + args.app, "--app=" + app["url"],
                   "--disable-features=GlobalShortcutsPortal"]
        os.execv(command[0], command)
    data = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    entries = data / "applications"
    icons = data / "chromium-webapps/icons"
    entries.mkdir(parents=True, exist_ok=True)
    icons.mkdir(parents=True, exist_ok=True)
    desired = set()
    for key, app in apps.items():
        icon = app.get("icon", "chromium")
        if urlparse(icon).scheme in ("https", "http"):
            suffix = Path(urlparse(icon).path).suffix.lower()
            if suffix not in (".svg", ".png", ".ico", ".jpg", ".jpeg"):
                raise ValueError(f"Unsupported icon format for {key}")
            target = icons / (key + suffix)
            if not target.exists() or not target.with_suffix(suffix + ".url").exists() or target.with_suffix(suffix + ".url").read_text() != icon:
                with urlopen(icon, timeout=30) as response:
                    content = response.read()
                target.write_bytes(content)
                target.with_suffix(suffix + ".url").write_text(icon)
            icon = str(target)
        entry = entries / f"chromium-webapp-{key}.desktop"
        command = " ".join(desktop_quote(part) for part in [os.environ["WEBAPP_MANAGER"], "launch", key])
        entry.write_text("[Desktop Entry]\nType=Application\n"
                         f"Name={app.get('name', key)}\nExec={command}\nIcon={icon}\n"
                         "Terminal=false\nCategories=Network;WebBrowser;\n")
        desired.add(entry)
        print(f"Generated {entry.name} using profile {app['profile']}")
    for entry in entries.glob("chromium-webapp-*.desktop"):
        if entry not in desired:
            entry.unlink()


if __name__ == "__main__":
    try:
        main()
    except (KeyError, ValueError, OSError, yaml.YAMLError) as error:
        sys.exit(f"chromium-webapps: {error}")
