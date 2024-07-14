#!/usr/bin/env python3

import subprocess, platform

if platform.system() == 'Windows':
    subprocess.run("shutdown /s /t 0 /f", shell=True)
else:
    subprocess.run("shutdown -P 0", shell=True)