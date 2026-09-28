from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"


def run(*args: str) -> None:
    subprocess.run(args, cwd=ROOT, check=True)


def ensure_android() -> None:
    if not ANDROID.exists():
        run(
            "flutter",
            "create",
            ".",
            "--platforms=android",
            "--org=ir.sahandse",
            "--project-name=tamrino",
        )


def remove_generated_sample_test() -> None:
    sample_test = ROOT / "test/widget_test.dart"
    if sample_test.exists():
        sample_test.unlink()


def patch_manifest() -> None:
    path = ANDROID / "app/src/main/AndroidManifest.xml"
    text = path.read_text(encoding="utf-8")

    permissions = [
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
        '<uses-permission android:name="android.permission.VIBRATE"/>',
        '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
    ]
    for permission in reversed(permissions):
        if permission not in text:
            text = text.replace(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    ' + permission,
                1,
            )

    text = text.replace('    <uses-permission android:name="android.permission.INTERNET"/>\n', '')
    text = re.sub(r'android:label="[^"]*"', 'android:label="تمرینو"', text, count=1)
    text = re.sub(r'android:icon="[^"]*"', 'android:icon="@drawable/tamrino_launcher"', text, count=1)
    if 'android:roundIcon=' not in text:
        text = text.replace(
            'android:icon="@drawable/tamrino_launcher"',
            'android:icon="@drawable/tamrino_launcher"\n        android:roundIcon="@drawable/tamrino_launcher"',
            1,
        )

    receivers = '''
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
            </intent-filter>
        </receiver>
'''
    if "ScheduledNotificationReceiver" not in text:
        text = text.replace("    </application>", receivers + "    </application>", 1)

    path.write_text(text, encoding="utf-8")


def patch_branding() -> None:
    res = ANDROID / "app/src/main/res"
    drawable = res / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)

    (drawable / "tamrino_launcher.xml").write_text(
        '''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#0B0D0F" android:pathData="M0,0h108v108h-108z"/>
    <path android:fillColor="#00C853" android:pathData="M14,54A40,40 0,0 1,36 18L41,26A31,31 0,0 0,22 54z M94,54A40,40 0,0 0,72 18L67,26A31,31 0,0 1,86 54z M26,78A38,38 0,0 0,82 78L74,73A29,29 0,0 1,34 73z"/>
    <path android:fillColor="#F8FAFC" android:pathData="M54,20a8,8 0,1 0,0.01 0z M54,31C45,31 37,36 34,45L40,57C44,53 47,49 49,44L49,68H59L59,44C61,49 64,53 68,57L74,45C71,36 63,31 54,31z"/>
    <path android:fillColor="#F8FAFC" android:pathData="M18,69h72v5h-72z"/>
    <path android:fillColor="#7CFF4F" android:pathData="M10,62h6v20h-6z M17,58h7v28h-7z M84,58h7v28h-7z M92,62h6v20h-6z"/>
    <path android:fillColor="#F8FAFC" android:pathData="M35,67a4,4 0,1 0,0.01 0z M73,67a4,4 0,1 0,0.01 0z"/>
</vector>''',
        encoding="utf-8",
    )

    launch = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#0B0D0F" />
        </shape>
    </item>
    <item android:width="148dp" android:height="148dp" android:gravity="center" android:drawable="@drawable/tamrino_launcher" />
</layer-list>'''
    for folder in (res / "drawable", res / "drawable-v21"):
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "launch_background.xml").write_text(launch, encoding="utf-8")

    for values_dir in (res / "values-v31", res / "values-night-v31"):
        values_dir.mkdir(parents=True, exist_ok=True)
        (values_dir / "styles.xml").write_text(
            '''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#0B0D0F</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/tamrino_launcher</item>
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:windowActionModeOverlay">true</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowLightStatusBar">false</item>
        <item name="android:colorAccent">#00C853</item>
    </style>
</resources>''',
            encoding="utf-8",
        )


def patch_gradle() -> None:
    path = ANDROID / "app/build.gradle.kts"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    text = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "ir.sahandse.tamrino"', text, count=1)

    if "isCoreLibraryDesugaringEnabled" not in text:
        text = text.replace("compileOptions {", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)

    if "coreLibraryDesugaring(" not in text:
        text = text.rstrip() + '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'

    path.write_text(text, encoding="utf-8")


def patch_main_activity() -> None:
    src = ANDROID / "app/src/main/kotlin"
    candidates = list(src.rglob("MainActivity.kt")) if src.exists() else []
    if not candidates:
        return
    old = candidates[0]
    target = src / "ir/sahandse/tamrino/MainActivity.kt"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        "package ir.sahandse.tamrino\n\n"
        "import io.flutter.embedding.android.FlutterActivity\n\n"
        "class MainActivity : FlutterActivity()\n",
        encoding="utf-8",
    )
    if old.resolve() != target.resolve():
        old.unlink(missing_ok=True)


def main() -> None:
    ensure_android()
    remove_generated_sample_test()
    patch_manifest()
    patch_branding()
    patch_gradle()
    patch_main_activity()
    print("Android bootstrap completed for ir.sahandse.tamrino with gym emblem branding")


if __name__ == "__main__":
    main()
