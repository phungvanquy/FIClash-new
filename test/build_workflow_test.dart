import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final workflow =
      loadYaml(File('.github/workflows/build.yaml').readAsStringSync())
          as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;
  final build = jobs['build'] as YamlMap;
  final release = jobs['release'] as YamlMap;
  const tagPush =
      "github.event_name == 'push' && startsWith(github.ref, 'refs/tags/v')";

  test('main pushes and manual runs build without enabling releases', () {
    final events = workflow['on'] as YamlMap;
    expect(events.containsKey('workflow_dispatch'), isTrue);
    expect(events['push']['branches'], contains('**'));
    expect(
      build['if'],
      "github.event_name == 'workflow_dispatch' || "
      "(github.event_name == 'push' && (github.ref == 'refs/heads/main' || "
      "startsWith(github.ref, 'refs/tags/v')))",
    );
    expect(release['if'], tagPush);
    expect(workflow['permissions']['contents'], 'read');
    expect(release['permissions']['contents'], 'write');
    expect(
      workflow['env']['IS_STABLE'],
      '\${{ $tagPush && !contains(github.ref_name, \'-\') }}',
    );
  });

  test('test artifacts target Android and Windows while tags retain Linux', () {
    final matrix = build['strategy']['matrix']['include'] as String;
    expect(matrix, contains('$tagPush &&'));
    final targets = RegExp(r"'(\[.*?\])'")
        .allMatches(matrix)
        .map((match) => jsonDecode(match[1]!) as List<dynamic>)
        .toList();

    expect(targets, hasLength(2));
    expect(targets[0].map((target) => target['platform']), [
      'android',
      'windows',
      'linux',
    ]);
    expect(targets[1], [
      {
        'platform': 'android',
        'os': 'ubuntu-latest',
        'arch': 'arm64',
        'args': '--arch arm64',
      },
      {
        'platform': 'windows',
        'os': 'windows-2022',
        'arch': 'amd64',
        'args': '--targets exe',
      },
    ]);
    expect(build['strategy']['fail-fast'], isFalse);
  });

  test('artifact builds retain every validation prerequisite', () {
    expect(build['needs'], [
      'dart',
      'plugins',
      'go',
      'xray-interop',
      'android',
      'rust',
      'windows-helper-test',
    ]);
    expect(release['needs'], ['build']);
  });

  test('test builds use native assets and do not consume release signing', () {
    final steps = build['steps'] as YamlList;
    final checkout = steps.firstWhere((step) => step['name'] == 'Checkout');
    final signing = steps.firstWhere(
      (step) => step['name'] == 'Setup Android Signing',
    );
    final setup = steps.firstWhere((step) => step['name'] == 'Setup');
    final upload = steps.firstWhere(
      (step) => step['name'] == 'Upload test installer',
    );
    final releaseUpload = steps.firstWhere(
      (step) => step['name'] == 'Upload release packages',
    );

    expect(checkout['with']['submodules'], 'recursive');
    expect(signing['if'], "matrix.platform == 'android' && $tagPush");
    expect(setup['run'], startsWith('dart setup.dart '));
    expect(setup['run'], contains(r'${{ matrix.args }}'));
    expect(upload['uses'], 'actions/upload-artifact@v7');
    expect(upload['if'], '\${{ !($tagPush) }}');
    expect(upload['with']['archive'], isFalse);
    expect(upload['with']['name'], r'${{ steps.test-installer.outputs.name }}');
    expect(upload['with']['path'], r'${{ steps.test-installer.outputs.path }}');
    expect(upload['with']['if-no-files-found'], 'error');
    expect(releaseUpload['if'], tagPush);
    expect(releaseUpload['with']['path'], './dist');
    expect(releaseUpload['with']['name'], startsWith('artifact-'));
    expect(
      steps.any((step) => (step['run'] ?? '').toString().contains('= false')),
      isFalse,
    );
  });

  test('Core checkout points to the published repository without SSH keys', () {
    final submodules = File('.gitmodules').readAsStringSync();
    expect(
      submodules,
      contains('url = https://github.com/phungvanquy/FlClash-core.git'),
    );
    expect(submodules, contains('branch = main'));
  });
}
