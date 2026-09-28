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


def patch_manifest() -> None:
    path = ANDROID / "app/src/main/AndroidManifest.xml"
    text = path.read_text(encoding="utf-8")

    permissions = [
        '<uses-permission android:name="android.permission.INTERNET"/>',
        '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>',
        '<uses-permission android:name="android.permission.VIBRATE"/>',
        '<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>',
    ]
    for permission in reversed(permissions):
        if permission not in text:
            text = text.replace("<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">", "<manifest xmlns:android=\"http://schemas.android.com/apk/res/android\">\n    " + permission, 1)

    text = re.sub(r'android:label="[^"]*"', 'android:label="تمرینو"', text, count=1)

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


def patch_gradle() -> None:
    path = ANDROID / "app/build.gradle.kts"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")

    text = re.sub(
        r'applicationId\s*=\s*"[^"]+"',
        'applicationId = "ir.sahandse.tamrino"',
        text,
        count=1,
    )

    if "isCoreLibraryDesugaringEnabled" not in text:
        text = text.replace(
            "compileOptions {",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            1,
        )

    if "coreLibraryDesugaring(" not in text:
        dependency = 'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        text = text.rstrip() + "\n\n" + dependency

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
    patch_manifest()
    patch_gradle()
    patch_main_activity()
    print("Android bootstrap completed for ir.sahandse.tamrino")


if __name__ == "__main__":
    main()
