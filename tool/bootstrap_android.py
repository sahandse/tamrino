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
    <path android:fillColor="#F7F7FA" android:pathData="M0,0h108v108h-108z"/>
    <path android:fillColor="#7624F5" android:pathData="M10,43h8v24h-8z M18,36h10v38h-10z M80,36h10v38h-10z M90,43h8v24h-8z"/>
    <path android:fillColor="#191A23" android:pathData="M8,52h92v7h-92z"/>
    <path android:fillColor="#191A23" android:pathData="M34,34 C40,29 48,28 57,30 L82,30 C88,30 91,27 92,24 L92,39 C88,44 82,45 75,45 L58,45 C49,45 45,49 45,57 C45,66 50,70 58,70 C66,70 70,65 73,59 L84,59 C79,76 68,84 53,84 C35,84 28,73 28,58 C28,47 29,39 34,34z"/>
    <path android:fillColor="#8A2CFF" android:pathData="M47,15 L53,21 L47,27 L41,21z M63,15 L69,21 L63,27 L57,21z"/>
</vector>''',
        encoding="utf-8",
    )

    launch = '''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#F7F7FA" />
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
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowSplashScreenBackground">#F7F7FA</item>
        <item name="android:windowSplashScreenAnimatedIcon">@drawable/tamrino_launcher</item>
        <item name="android:windowLightStatusBar">true</item>
        <item name="android:windowActionModeOverlay">true</item>
    </style>
    <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowLightStatusBar">true</item>
        <item name="android:colorAccent">#7624F5</item>
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
    print("Android bootstrap completed for ir.sahandse.tamrino with Tamrino branding")


if __name__ == "__main__":
    main()
