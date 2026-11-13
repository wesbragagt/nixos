import json
import os
from pathlib import Path
import subprocess
import shlex
import sys

windows = json.loads(subprocess.check_output([os.environ['HYPRCTL'], 'clients', '-j']))
chromium = [window for window in windows if window['class'] == 'chromium-browser' and window['mapped'] and window['focusHistoryID'] >= 0]
args = []
if chromium:
    window = min(chromium, key=lambda item: item['focusHistoryID'])
    try:
        command = Path(f"/proc/{window['pid']}/cmdline").read_bytes().split(b'\0')
        if len([arg for arg in command if arg]) == 1:
            command = [os.fsencode(arg) for arg in shlex.split(os.fsdecode(command[0]))]
        for arg in command:
            if arg.startswith((b'--user-data-dir=', b'--profile-directory=')):
                args.append(os.fsdecode(arg))
    except FileNotFoundError:
        pass
os.execv(os.environ['CHROMIUM'], [os.environ['CHROMIUM'], *args, *sys.argv[1:]])
