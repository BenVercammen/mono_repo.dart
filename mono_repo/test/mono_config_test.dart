// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:mono_repo/src/package_config.dart';
import 'package:mono_repo/src/yaml.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:term_glyph/term_glyph.dart' as glyph;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'shared.dart';

final _dummyPubspec = Pubspec('_example');

String _encodeJson(Object? input) =>
    const JsonEncoder.withIndent(' ').convert(input);

PackageConfig _parse(map) => PackageConfig.parse(
    'a',
    _dummyPubspec,
    map is YamlMap
        ? map
        : loadYamlChecked(
            _encodeJson(map),
          ) as Map);

void _expectParseThrows(Object content, String expectedError) =>
    expect(() => _parse(content), throwsAParsedYamlException(expectedError));

void main() {
  glyph.ascii = false;

  test('no stages - end up with one `unit_test` stage with one `test` task',
      () {
    final config = _parse({
      'dart': ['stable']
    });

    final oneJob = config.jobs.single;
    expect(oneJob.sdk, 'stable');
    expect(oneJob.tasks.first.name, 'test');
    expect(oneJob.tasks.first.args, isNull);
    expect(oneJob.stageName, 'unit_test');
  });

  test('valid example', () {
    final monoYaml = loadYamlChecked(_testConfig1) as Map;

    final config = _parse(monoYaml);

    expect(config.sdks, ['1.23.0', 'dev', 'stable']);

    final jobs = config.jobs.map((tj) => tj.toJson()).toList();

    expect(jobs, _testConfig1expectedOutput);
  });

  group('error checks', () {
    test('dart key is required', () {
      final config = _parse({});
      expect(config.cacheDirectories, isEmpty);
      expect(config.jobs, isEmpty);
      expect(config.stageNames, isEmpty);
      expect(config.sdks, isEmpty);
    });

    test('stage items must be a map', () {
      _expectParseThrows(
        {
          'stages': [
            {
              'format': ['dartfmt']
            }
          ]
        },
        r'''
line 4, column 14: Each item within a stage must be a map.
  ╷
4 │      "format": [
  │ ┌──────────────^
5 │ │     "dartfmt"
6 │ └    ]
  ╵''',
      );
    });

    test('group items must be instances of map or string', () {
      _expectParseThrows(
        loadYaml(r'''
stages:
- smoke_test:
  - group:
    - [dartfmt]
    - dartanalyzer: --fatal-infos --fatal-warnings .
    dart: dev
''') as Object,
        r'''
line 4, column 7: Must be a map or a string.
  ╷
4 │     - [dartfmt]
  │       ^^^^^^^^^
  ╵''',
      );
    });

    test('dart value cannot be null', () {
      _expectParseThrows(
        {'dart': null},
        r'''
line 2, column 10: Unsupported value for "dart". The value for "dart" must be an array with at least one value.
  ╷
2 │  "dart": null
  │          ^^^^
  ╵''',
      );
    });

    test('dart value cannot be empty', () {
      _expectParseThrows(
        {'dart': []},
        r'''
line 2, column 10: Unsupported value for "dart". The value for "dart" must be an array with at least one value.
  ╷
2 │  "dart": []
  │          ^^
  ╵''',
      );
    });

    test('Stages named `test` are not allowed', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {
            'test': ['test']
          },
        ]
      };
      _expectParseThrows(
        monoYaml,
        r'''
line 7, column 12: Unsupported value for "test". Stages are not allowed to have the name "test" because it interacts poorly with the default stage by the same name.
  ╷
7 │      "test": [
  │ ┌────────────^
8 │ │     "test"
9 │ └    ]
  ╵''',
      );
    });

    test('Stages tasks must be a list', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': 42},
        ]
      };

      _expectParseThrows(
        monoYaml,
        r'''
line 7, column 9: Unsupported value for "a". Stages must be a list of maps with exactly one key (the name of the stage), but the provided value `{a: 42}` is not valid.
  ╷
7 │      "a": 42
  │ ┌─────────^
8 │ │   }
  │ └──^
  ╵''',
      );
    });

    test('Stages tasks must be a list', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': 42},
        ]
      };

      _expectParseThrows(
        monoYaml,
        r'''
line 7, column 9: Unsupported value for "a". Stages must be a list of maps with exactly one key (the name of the stage), but the provided value `{a: 42}` is not valid.
  ╷
7 │      "a": 42
  │ ┌─────────^
8 │ │   }
  │ └──^
  ╵''',
      );
    });

    test('Stages tasks must be a list', () {
      final monoYaml = loadYaml('''
stages:
- smoke_test:
  - description: 'bob'
    group: funky
    dart: dev
''') as Object;

      _expectParseThrows(
        monoYaml,
        r'''
line 4, column 12: Unsupported value for "group". expected a list of tasks
  ╷
4 │     group: funky
  │            ^^^^^
  ╵''',
      );
    });

    test(
        'Stages tasks must be a list with map with one key in the approved set',
        () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {
            'a': [
              {'weird': 'thing'}
            ]
          },
        ]
      };

      _expectParseThrows(
        monoYaml,
        r'''
line 9, column 6: Must have one key of `dartfmt`, `dartanalyzer`, `test`, `command`.
  ╷
9 │      "weird": "thing"
  │      ^^^^^^^
  ╵''',
      );
    });

    test('Stage tasks entries must have one key in the approved set', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {
            'a': [
              {'test': 'thing', 'command': 'other thing'}
            ]
          },
        ]
      };

      _expectParseThrows(
        monoYaml,
        r'''
line 10, column 6: Must have one and only one key of `dartfmt`, `dartanalyzer`, `test`, `command`.
   ╷
10 │      "command": "other thing"
   │      ^^^^^^^^^
   ╵''',
      );
    });

    test('empty stage job', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': []},
        ]
      };
      _expectParseThrows(
        monoYaml,
        r'''
line 7, column 9: Unsupported value for "a". Stages are required to have at least one job. "a" is empty.
  ╷
7 │    "a": []
  │         ^^
  ╵''',
      );
    });

    test('multiple keys under a stage', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': null, 'b': null},
        ]
      };
      _expectParseThrows(
        monoYaml,
        r'''
line 8, column 4: Stages must be a list of maps with exactly one key (the name of the stage), but the provided value has 2 values.
  ╷
8 │    "b": null
  │    ^^^
  ╵''',
      );
    });

    test('no keys under a stage', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [{}]
      };
      _expectParseThrows(
        monoYaml,
        r'''
line 6, column 3: Stages must be a list of maps with exactly one key (the name of the stage), but no items exist.
  ╷
6 │   {}
  │   ^^
  ╵''',
      );
    });

    test('null stage job', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {'a': null},
        ]
      };
      _expectParseThrows(
        monoYaml,
        r'''
line 7, column 9: Unsupported value for "a". Stages are required to have at least one job. "a" is null.
  ╷
7 │      "a": null
  │ ┌─────────^
8 │ │   }
  │ └──^
  ╵''',
      );
    });

    test('unsupported keys', () {
      final monoYaml = {
        'extra': 'foo',
        'dart': ['stable'],
        'stages': [
          {
            'a': ['test']
          },
          {
            'a': ['dartfmt']
          },
        ],
        'more': null
      };
      _expectParseThrows(
        monoYaml,
        r'''
line 2, column 2: Unrecognized keys: [extra, more]; supported keys: [os, dart, stages, cache]
  ╷
2 │  "extra": "foo",
  │  ^^^^^^^
  ╵''',
      );
    });

    test('Duplicate stage names are not allowed', () {
      final monoYaml = {
        'dart': ['stable'],
        'stages': [
          {
            'a': ['test']
          },
          {
            'a': ['dartfmt']
          },
        ]
      };

      _expectParseThrows(
        monoYaml,
        r'''
line 12, column 4: Stages must be unique. "a" appears more than once.
   ╷
12 │    "a": [
   │    ^^^
   ╵''',
      );
    });

    test('SDKs must be versions or in the allow-list', () {
      final monoYaml = {
        'dart': ['latest'],
        'stages': [
          {
            'a': ['test']
          },
        ]
      };

      _expectParseThrows(monoYaml, r'''
line 2, column 10: Unsupported value for "dart". The value "latest" is neither a version string nor one of "main", "dev", "beta", "stable".
  ╷
2 │    "dart": [
  │ ┌──────────^
3 │ │   "latest"
4 │ │  ],
  │ └──^
  ╵''');
    });
  });
}

const _testConfig1 = r'''
dart:
  - dev
  - stable
  - 1.23.0
os:
  - linux

stages:
  - analyze_and_format:
    - description: "dartanalyzer && dartfmt"
      group:
        - dartanalyzer: --fatal-infos --fatal-warnings .
        - dartfmt
      dart:
        - dev
      os:
        - windows
        - linux
    - dartanalyzer: --fatal-infos --fatal-warnings .
      dart:
        - 1.23.0
      os:
        - osx
  - unit_test:
    - test: --platform chrome
    - test: --preset travis --total-shards 5 --shard-index 0
    - test: --preset travis --total-shards 5 --shard-index 1
    - test #no args
''';

List get _testConfig1expectedOutput => [
      {
        'description': 'dartanalyzer && dartfmt',
        'os': 'windows',
        'package': 'a',
        'sdk': 'dev',
        'stageName': 'analyze_and_format',
        'tasks': [
          {'name': 'dartanalyzer', 'args': '--fatal-infos --fatal-warnings .'},
          {'name': 'dartfmt'}
        ]
      },
      {
        'description': 'dartanalyzer && dartfmt',
        'os': 'linux',
        'package': 'a',
        'sdk': 'dev',
        'stageName': 'analyze_and_format',
        'tasks': [
          {'name': 'dartanalyzer', 'args': '--fatal-infos --fatal-warnings .'},
          {'name': 'dartfmt'}
        ]
      },
      {
        'os': 'osx',
        'package': 'a',
        'sdk': '1.23.0',
        'stageName': 'analyze_and_format',
        'tasks': [
          {'name': 'dartanalyzer', 'args': '--fatal-infos --fatal-warnings .'}
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': '1.23.0',
        'stageName': 'unit_test',
        'tasks': [
          {'name': 'test', 'args': '--platform chrome'}
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': 'dev',
        'stageName': 'unit_test',
        'tasks': [
          {'name': 'test', 'args': '--platform chrome'}
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': 'stable',
        'stageName': 'unit_test',
        'tasks': [
          {'name': 'test', 'args': '--platform chrome'}
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': '1.23.0',
        'stageName': 'unit_test',
        'tasks': [
          {
            'name': 'test',
            'args': '--preset travis --total-shards 5 --shard-index 0'
          }
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': 'dev',
        'stageName': 'unit_test',
        'tasks': [
          {
            'name': 'test',
            'args': '--preset travis --total-shards 5 --shard-index 0'
          }
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': 'stable',
        'stageName': 'unit_test',
        'tasks': [
          {
            'name': 'test',
            'args': '--preset travis --total-shards 5 --shard-index 0'
          }
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': '1.23.0',
        'stageName': 'unit_test',
        'tasks': [
          {
            'name': 'test',
            'args': '--preset travis --total-shards 5 --shard-index 1'
          }
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': 'dev',
        'stageName': 'unit_test',
        'tasks': [
          {
            'name': 'test',
            'args': '--preset travis --total-shards 5 --shard-index 1'
          }
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': 'stable',
        'stageName': 'unit_test',
        'tasks': [
          {
            'name': 'test',
            'args': '--preset travis --total-shards 5 --shard-index 1'
          }
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': '1.23.0',
        'stageName': 'unit_test',
        'tasks': [
          {'name': 'test'}
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': 'dev',
        'stageName': 'unit_test',
        'tasks': [
          {'name': 'test'}
        ]
      },
      {
        'os': 'linux',
        'package': 'a',
        'sdk': 'stable',
        'stageName': 'unit_test',
        'tasks': [
          {'name': 'test'}
        ]
      }
    ];
