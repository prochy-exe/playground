#!/usr/bin/env python3

import subprocess, platform

if platform.system() == 'Windows':
    subprocess.run(r"%windir%\System32\rundll32.exe powrprof.dll,SetSuspendState 0,1,0", shell=True)
else:
    subprocess.run("systemctl suspend", shell=True)