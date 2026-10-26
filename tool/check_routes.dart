// Static route audit – run with:  dart run tool/check_routes.dart
// Fails (exit 1) when any context.push/go('/path') points to a path that has
// no GoRoute in lib/router.dart (this is exactly what broke Sign-up before).
import 'dart:io';

List<String> findMissingRoutes(String libDir) {
  final router = File('$libDir/router.dart').readAsStringSync();
  final routes = RegExp(r"GoRoute\(\s*path:\s*'([^']+)'")
      .allMatches(router)
      .map((m) => m.group(1)!)
      .toSet();
  final patterns = [
    for (final r in routes)
      RegExp('^${r.replaceAll(RegExp(r':\w+'), r'[^/]+')}\$'),
  ];
  final nav = RegExp(
    r"""(?:\.push|\.go|\.pushReplacement|\.replace)\(\s*(['"])(.*?)\1""",
  );
  final missing = <String>[];
  for (final f in Directory(libDir).listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final src = f.readAsStringSync();
    for (final m in nav.allMatches(src)) {
      final raw = m.group(2)!;
      final path = raw
          .replaceAll(RegExp(r'\$\{[^}]*\}|\$\w+'), 'x')
          .split('?')
          .first;
      if (!patterns.any((p) => p.hasMatch(path))) {
        missing.add('${f.path}: $raw');
      }
    }
  }
  return missing;
}

void main() {
  final missing = findMissingRoutes('lib');
  if (missing.isEmpty) {
    stdout.writeln('OK – every navigation target has a route.');
  } else {
    stdout.writeln('Missing routes:\n${missing.join('\n')}');
    exit(1);
  }
}
