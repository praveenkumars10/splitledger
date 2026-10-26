// ignore_for_file: avoid_print
import 'dart:io';

void main(List<String> args) async {
  print('========================================================');
  print('       SplitLedger Auto-Versioning APK Builder');
  print('========================================================\n');

  final projectDir = Directory.current;
  final pubspecFile = File('${projectDir.path}/pubspec.yaml');
  final appVersionFile = File('${projectDir.path}/lib/core/constants/app_version.dart');

  if (!pubspecFile.existsSync()) {
    print('❌ Error: pubspec.yaml not found in ${projectDir.path}');
    exit(1);
  }

  final bool noBump = args.contains('--no-bump');
  final bool bumpMajor = args.contains('--major');
  final bool bumpMinor = args.contains('--minor');

  // 1. Read current version from pubspec.yaml
  final pubspecContent = await pubspecFile.readAsString();
  final versionRegex = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)', multiLine: true);
  final match = versionRegex.firstMatch(pubspecContent);

  if (match == null) {
    print('❌ Error: Could not parse version in pubspec.yaml');
    exit(1);
  }

  int major = int.parse(match.group(1)!);
  int minor = int.parse(match.group(2)!);
  int patch = int.parse(match.group(3)!);
  int build = int.parse(match.group(4)!);

  final oldVersionStr = '$major.$minor.$patch+$build';

  if (!noBump) {
    build += 1;
    if (bumpMajor) {
      major += 1;
      minor = 0;
      patch = 0;
    } else if (bumpMinor) {
      minor += 1;
      patch = 0;
    } else {
      patch += 1;
    }
  }

  final newVersionName = '$major.$minor.$patch';
  final newFullVersion = '$newVersionName+$build';

  print('📦 Current Version : $oldVersionStr');
  print('🚀 Target Version  : $newFullVersion (Name: $newVersionName, Build: $build)\n');

  // 2. Update pubspec.yaml
  final updatedPubspec = pubspecContent.replaceFirst(
    versionRegex,
    'version: $newFullVersion',
  );
  await pubspecFile.writeAsString(updatedPubspec);
  print('✓ Updated pubspec.yaml -> version: $newFullVersion');

  // 3. Update lib/core/constants/app_version.dart
  final appVersionContent = '''class AppVersion {
  static const String versionName = '$newVersionName';
  static const int buildNumber = $build;
  static const String fullVersion = '\$versionName+\$buildNumber';
  static const String displayVersion = 'v\$versionName (Build \$buildNumber)';
}
''';
  await appVersionFile.writeAsString(appVersionContent);
  print('✓ Updated lib/core/constants/app_version.dart -> $newVersionName (Build $build)\n');

  // 4. Run flutter build apk --release
  print('🔨 Building Release APK with Flutter...');
  final buildStopwatch = Stopwatch()..start();

  final flutterCmd = Platform.isWindows ? 'flutter.bat' : 'flutter';
  final process = await Process.start(
    flutterCmd,
    ['build', 'apk', '--release'],
    environment: {
      ...Platform.environment,
      'BUILD_VERSION_INCREMENTED': 'true',
    },
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await process.exitCode;
  buildStopwatch.stop();

  if (exitCode != 0) {
    print('\n❌ Flutter APK build failed with exit code $exitCode');
    exit(exitCode);
  }

  // 5. Locate built release APK
  final defaultApk = File('${projectDir.path}/build/app/outputs/flutter-apk/app-release.apk');
  if (!defaultApk.existsSync()) {
    print('\n❌ Build succeeded but APK file was not found at ${defaultApk.path}');
    exit(1);
  }

  final fileSizeMB = (defaultApk.lengthSync() / (1024 * 1024)).toStringAsFixed(2);

  // 6. Copy to versioned APK in build/app/outputs/flutter-apk/
  final versionedApkName = 'SplitLedger-v$newVersionName-build$build.apk';
  final versionedApkInBuild = File('${projectDir.path}/build/app/outputs/flutter-apk/$versionedApkName');
  await defaultApk.copy(versionedApkInBuild.path);

  // 7. Also copy to dedicated project 'releases/' folder for easy access
  final releasesDir = Directory('${projectDir.path}/releases');
  if (!releasesDir.existsSync()) {
    await releasesDir.create(recursive: true);
  }
  final releaseOutputApk = File('${releasesDir.path}/$versionedApkName');
  await defaultApk.copy(releaseOutputApk.path);

  final elapsedSec = buildStopwatch.elapsed.inSeconds;

  print('\n========================================================');
  print('🎉 APK BUILD COMPLETED SUCCESSFULLY in ${elapsedSec}s!');
  print('========================================================');
  print('📱 App Name        : SplitLedger');
  print('🏷️  Version Name    : $newVersionName');
  print('🔢 Build Number    : $build');
  print('📦 Full Version    : $newFullVersion');
  print('⚖️  File Size       : $fileSizeMB MB');
  print('📍 Versioned APK   : ${versionedApkInBuild.path}');
  print('📂 Releases Folder : ${releaseOutputApk.path}');
  print('========================================================\n');
}
