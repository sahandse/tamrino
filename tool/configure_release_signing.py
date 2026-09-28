from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GRADLE = ROOT / "android/app/build.gradle.kts"


def main() -> None:
    if not GRADLE.exists():
        raise SystemExit("android/app/build.gradle.kts not found; run bootstrap_android.py first")

    text = GRADLE.read_text(encoding="utf-8")

    imports = "import java.io.FileInputStream\nimport java.util.Properties\n\n"
    if "import java.util.Properties" not in text:
        text = imports + text

    properties_block = '''
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (!keystorePropertiesFile.exists()) {
    error("android/key.properties is required for release signing")
}
keystoreProperties.load(FileInputStream(keystorePropertiesFile))

'''
    if "val keystoreProperties = Properties()" not in text:
        android_index = text.find("android {")
        if android_index == -1:
            raise SystemExit("android block not found in build.gradle.kts")
        text = text[:android_index] + properties_block + text[android_index:]

    signing_block = '''
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

'''
    if 'create("release")' not in text:
        marker = "android {\n"
        text = text.replace(marker, marker + signing_block, 1)

    debug_signing = 'signingConfig = signingConfigs.getByName("debug")'
    release_signing = 'signingConfig = signingConfigs.getByName("release")'
    if debug_signing in text:
        text = text.replace(debug_signing, release_signing, 1)
    elif release_signing not in text:
        release_marker = 'release {\n'
        if release_marker not in text:
            raise SystemExit("release build type not found")
        text = text.replace(
            release_marker,
            release_marker + f"            {release_signing}\n",
            1,
        )

    GRADLE.write_text(text, encoding="utf-8")
    print("Release signing configured")


if __name__ == "__main__":
    main()
