import argparse
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import sys

import yaml

CONFIG = Path.home() / '.config/chromium-profiles/config.yaml'
DEFAULTS = {'vertical_tabs': True}


def write_json(path, data):
    temporary = path.with_name(path.name + '.chromium-profile.tmp')
    temporary.write_text(json.dumps(data))
    os.replace(temporary, path)


def main():
    parser = argparse.ArgumentParser(description='Launch a configured Chromium profile')
    parser.add_argument('profile', help=f'Profile name from {CONFIG}')
    parser.add_argument('arguments', nargs=argparse.REMAINDER, help='Arguments passed to Chromium')
    args = parser.parse_args()
    if args.profile in ('.', '..') or '/' in args.profile:
        parser.error('profile must be a single directory name')
    config = yaml.safe_load(CONFIG.read_text()) if CONFIG.exists() else {}
    config = config or {}
    profiles = config.get('profiles', {})
    if args.profile not in profiles:
        parser.error(f'profile {args.profile!r} is not configured in {CONFIG}')
    settings = DEFAULTS | (config.get('defaults') or {}) | (profiles[args.profile] or {})
    directory = Path(os.path.expandvars(os.path.expanduser(settings.get('data_dir', f'~/.config/chromium-profiles/{args.profile}')))).absolute()
    directory.mkdir(parents=True, exist_ok=True)
    profile_dir = settings.get('profile_directory', 'Default')
    if profile_dir in ('', '.', '..') or '/' in profile_dir:
        parser.error('profile_directory must be a single directory name')
    command = [os.environ['CHROMIUM_PROFILE_BROWSER'], f'--user-data-dir={directory}', f'--profile-directory={profile_dir}', '--remote-debugging-port=0', '--no-default-browser-check', *args.arguments]
    with (directory / '.chromium-profile.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            os.execv(command[0], command)
        singleton = directory / 'SingletonLock'
        if singleton.is_symlink():
            target = os.readlink(singleton)
            host, _, pid = target.rpartition('-')
            if host != socket.gethostname():
                sys.exit(f'Chromium profile may be in use on {host}: {directory}')
            try:
                os.kill(int(pid), 0)
            except ProcessLookupError:
                pass
            except (ValueError, PermissionError):
                sys.exit(f'Cannot verify Chromium profile lock: {singleton}')
            else:
                os.execv(command[0], command)
        profile = directory / profile_dir
        profile.mkdir(exist_ok=True)
        prefs_path = profile / 'Preferences'
        prefs = json.loads(prefs_path.read_text()) if prefs_path.exists() else {}
        prefs.setdefault('vertical_tabs', {})['enabled'] = settings['vertical_tabs']
        prefs.setdefault('profile', {})['name'] = settings.get('name', args.profile)
        if 'color' in settings:
            color = settings['color']
            if not isinstance(color, str) or len(color) != 7 or not color.startswith('#'):
                sys.exit('Profile color must be a quoted #RRGGBB value')
            try:
                color_value = int(color[1:], 16) - 0x1000000
            except ValueError:
                sys.exit('Profile color must be a quoted #RRGGBB value')
            prefs.setdefault('browser', {}).setdefault('theme', {})['user_color2'] = color_value
        write_json(prefs_path, prefs)
        state_path = directory / 'Local State'
        state = json.loads(state_path.read_text()) if state_path.exists() else {}
        info = state.setdefault('profile', {}).setdefault('info_cache', {}).setdefault(profile_dir, {
            'avatar_icon': 'chrome://theme/IDR_PROFILE_AVATAR_26',
            'is_using_default_avatar': True,
        })
        info.update(name=settings.get('name', args.profile), is_using_default_name=False)
        if 'color' in settings:
            info['profile_color_seed'] = color_value
        write_json(state_path, state)
        sys.exit(subprocess.call(command))


if __name__ == '__main__':
    main()
