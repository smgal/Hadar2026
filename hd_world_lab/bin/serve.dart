import 'dart:io';

import 'package:hd_world_lab/server.dart';

/// Serves the equipment screen and the command API.
///
///     dart run bin/serve.dart [port]
Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 5330 : int.tryParse(args.first) ?? 5330;
  final here = File.fromUri(Platform.script).parent.parent;
  final server = LabServer(root: Directory('${here.path}/web'));
  await server.start(port: port);
  stdout
    ..writeln('hd_world lab on http://127.0.0.1:${server.port}')
    ..writeln('  screen  http://127.0.0.1:${server.port}/')
    ..writeln('  guide   http://127.0.0.1:${server.port}/api/guide')
    ..writeln('  spec    http://127.0.0.1:${server.port}/openapi.yaml')
    ..writeln('press ctrl-c to stop');
  await ProcessSignal.sigint.watch().first;
  await server.stop();
}
