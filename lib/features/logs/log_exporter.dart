import 'dart:io';

import 'package:path/path.dart' as p;

Future<List<File>> existingLogFiles(Iterable<String> filePaths) async {
  final files = <File>[];
  for (final path in filePaths) {
    if (path.isEmpty) continue;
    final file = File(path);
    if (await file.exists()) {
      files.add(file);
    }
  }
  return files;
}

String diagnosticLogExportFileName(DateTime generatedAt) {
  final timestamp = generatedAt
      .toUtc()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  return 'lantern-diagnostic-logs-$timestamp.txt';
}

String normalizeDiagnosticLogExportPath(String path) {
  if (p.extension(path).isNotEmpty) {
    return path;
  }
  return '$path.txt';
}

Future<File> writeDiagnosticLogBundle(
  Iterable<File> files,
  String targetPath, {
  DateTime? generatedAt,
}) async {
  final sourceFiles = files.toList(growable: false);
  if (sourceFiles.isEmpty) {
    throw ArgumentError.value(sourceFiles, 'files', 'must not be empty');
  }

  final target = File(normalizeDiagnosticLogExportPath(targetPath));
  if (!await target.parent.exists()) {
    await target.parent.create(recursive: true);
  }

  final temp = File(
    p.join(
      target.parent.path,
      '.${p.basename(target.path)}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    ),
  );
  final sink = temp.openWrite();
  var finishedWriting = false;

  try {
    sink.writeln('Lantern diagnostic logs');
    sink.writeln('Generated: ${(generatedAt ?? DateTime.now()).toUtc()}');
    sink.writeln();
    sink.writeln('Source files:');
    for (final file in sourceFiles) {
      sink.writeln('- ${p.basename(file.path)}');
    }

    for (final file in sourceFiles) {
      sink.writeln();
      sink.writeln('===== ${p.basename(file.path)} =====');
      await sink.addStream(file.openRead());
      sink.writeln();
    }

    await sink.flush();
    finishedWriting = true;
  } finally {
    await sink.close();
    if (!finishedWriting && await temp.exists()) {
      await temp.delete();
    }
  }

  try {
    return await temp.copy(target.path);
  } finally {
    if (await temp.exists()) {
      await temp.delete();
    }
  }
}
