#!/usr/bin/env python3
"""Patches the android/ and ios/ folders created by `flutter create`.

Adds permissions, the foreground service, lock-screen flags, privacy settings,
notification icon and the app name. Safe to run more than once.
"""
import os
import plistlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_NAME = os.environ.get('APP_NAME', 'Forex Alert')

ANDROID_PERMISSIONS = [
    'INTERNET',
    'POST_NOTIFICATIONS',
    'FOREGROUND_SERVICE',
    'FOREGROUND_SERVICE_DATA_SYNC',
    'WAKE_LOCK',
    'USE_FULL_SCREEN_INTENT',
    'VIBRATE',
    'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
]

SERVICE_XML = '''
        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="dataSync"
            android:exported="false" />
'''

NOTIFICATION_ICON = '''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M12,22c1.1,0 2,-0.9 2,-2h-4c0,1.1 0.89,2 2,2zM18,16v-5c0,-3.07 -1.64,-5.64 -4.5,-6.32V4c0,-0.83 -0.67,-1.5 -1.5,-1.5s-1.5,0.67 -1.5,1.5v0.68C7.63,5.36 6,7.92 6,11v5l-2,2v1h16v-1l-2,-2z" />
</vector>
'''

KEEP_XML = '''<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools"
    tools:keep="@drawable/ic_stat_alert" />
'''


def fail(message):
    sys.exit(f'configure_platforms: {message}')


def patch_manifest():
    path = ROOT / 'android/app/src/main/AndroidManifest.xml'
    text = path.read_text()
    if 'flutter_foreground_task.service.ForegroundService' in text:
        print('android manifest already patched')
        return

    perms = '\n'.join(
        f'    <uses-permission android:name="android.permission.{p}" />'
        for p in ANDROID_PERMISSIONS
    )
    if '<application' not in text:
        fail('<application> not found in AndroidManifest.xml')
    text = text.replace(
        '<application',
        perms + '\n\n    <application\n'
        '        android:allowBackup="false"\n'
        '        android:usesCleartextTraffic="false"',
        1,
    )
    text = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', text, count=1)

    if 'android:name=".MainActivity"' not in text:
        fail('MainActivity not found in AndroidManifest.xml')
    text = text.replace(
        'android:name=".MainActivity"',
        'android:name=".MainActivity"\n'
        '            android:showWhenLocked="true"\n'
        '            android:turnScreenOn="true"',
        1,
    )
    text = text.replace('</application>', SERVICE_XML + '    </application>', 1)
    path.write_text(text)
    print('patched AndroidManifest.xml')


def patch_gradle():
    app_dir = ROOT / 'android/app'
    gradle = next((app_dir / n for n in ('build.gradle.kts', 'build.gradle')
                   if (app_dir / n).exists()), None)
    if gradle is None:
        fail('android/app/build.gradle(.kts) not found')
    text = gradle.read_text()
    if 'coreLibraryDesugaring' in text:
        print('gradle already patched')
        return

    kts = gradle.suffix == '.kts'
    flag = 'isCoreLibraryDesugaringEnabled = true' if kts else 'coreLibraryDesugaringEnabled true'
    text, count = re.subn(r'compileOptions\s*\{', 'compileOptions {\n        ' + flag, text, count=1)
    if count == 0:
        fail('compileOptions block not found in gradle file')

    dep = ('coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")' if kts
           else "coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'")
    text += f'\ndependencies {{\n    {dep}\n}}\n'
    gradle.write_text(text)
    print(f'patched {gradle.name}')


def write_android_resources():
    res = ROOT / 'android/app/src/main/res'
    (res / 'drawable').mkdir(parents=True, exist_ok=True)
    (res / 'raw').mkdir(parents=True, exist_ok=True)
    (res / 'drawable/ic_stat_alert.xml').write_text(NOTIFICATION_ICON)
    (res / 'raw/keep.xml').write_text(KEEP_XML)
    print('wrote notification icon resources')


def patch_ios():
    path = ROOT / 'ios/Runner/Info.plist'
    with path.open('rb') as f:
        data = plistlib.load(f)
    data['CFBundleDisplayName'] = APP_NAME
    data['CFBundleName'] = APP_NAME
    modes = set(data.get('UIBackgroundModes', []))
    modes.update({'audio', 'fetch'})
    data['UIBackgroundModes'] = sorted(modes)
    with path.open('wb') as f:
        plistlib.dump(data, f)
    print('patched Info.plist')


def main():
    if (ROOT / 'android').exists():
        patch_manifest()
        patch_gradle()
        write_android_resources()
    if (ROOT / 'ios').exists():
        patch_ios()


if __name__ == '__main__':
    main()
