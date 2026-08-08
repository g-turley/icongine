import 'package:test/test.dart';
import 'package:icongine/icongine.dart';

void main() {
  group('SymbolResolver', () {
    final resolver = SymbolResolver();

    test('keeps first name and adds numeric suffix for collisions', () {
      final files = const [
        IconFile(absolutePath: '/tmp/a/home.svg', relativePath: 'a/home.svg'),
        IconFile(absolutePath: '/tmp/b/home.svg', relativePath: 'b/home.svg'),
        IconFile(absolutePath: '/tmp/c/home.svg', relativePath: 'c/home.svg'),
      ];

      final symbols = resolver.resolve(files: files, prefixWithSubdir: false);

      expect(symbols.map((item) => item.name).toList(), [
        'home',
        'home2',
        'home3',
      ]);
    });

    test(
      'handles subdirectory and flat-name near-collisions deterministically',
      () {
        final files = const [
          IconFile(absolutePath: '/tmp/a/home.svg', relativePath: 'a/home.svg'),
          IconFile(absolutePath: '/tmp/b/home.svg', relativePath: 'b/home.svg'),
          IconFile(absolutePath: '/tmp/bhome.svg', relativePath: 'bhome.svg'),
        ];

        final symbols = resolver.resolve(files: files, prefixWithSubdir: true);

        expect(symbols.map((item) => item.name).toList(), [
          'aHome',
          'bHome',
          'bhome2',
        ]);
      },
    );

    test('reports name collision warning diagnostics', () {
      final files = const [
        IconFile(
          absolutePath: '/tmp/food/home.svg',
          relativePath: 'food/home.svg',
        ),
        IconFile(
          absolutePath: '/tmp/social/home.svg',
          relativePath: 'social/home.svg',
        ),
      ];

      final result = resolver.resolveWithDiagnostics(
        files: files,
        prefixWithSubdir: false,
      );

      expect(
        result.issues.where((issue) => issue.code == 'name_collision'),
        hasLength(1),
      );
    });

    test(
      'reports error when path-based name resolves to reserved identifier',
      () {
        final files = const [
          IconFile(
            absolutePath: '/tmp/font-family.svg',
            relativePath: 'font-family.svg',
          ),
        ];

        final result = resolver.resolveWithDiagnostics(
          files: files,
          prefixWithSubdir: false,
        );

        final issue = result.issues.singleWhere(
          (item) => item.code == 'reserved_identifier',
        );
        expect(issue.severity, NamingIssueSeverity.error);
        expect(issue.message, contains('reserved name "fontFamily"'));
      },
    );

    test(
      'reports error when path-based name resolves to fontPackage identifier',
      () {
        final files = const [
          IconFile(
            absolutePath: '/tmp/font-package.svg',
            relativePath: 'font-package.svg',
          ),
        ];

        final result = resolver.resolveWithDiagnostics(
          files: files,
          prefixWithSubdir: false,
        );

        final issue = result.issues.singleWhere(
          (item) => item.code == 'reserved_identifier',
        );
        expect(issue.severity, NamingIssueSeverity.error);
        expect(issue.message, contains('reserved name "fontPackage"'));
      },
    );

    test('reports error when path-based name resolves to all identifier '
        'and generateIconMap is enabled', () {
      final files = const [
        IconFile(absolutePath: '/tmp/all.svg', relativePath: 'all.svg'),
      ];

      final result = resolver.resolveWithDiagnostics(
        files: files,
        prefixWithSubdir: false,
        additionalReserved: const {'all'},
      );

      final issue = result.issues.singleWhere(
        (item) => item.code == 'reserved_identifier',
      );
      expect(issue.severity, NamingIssueSeverity.error);
      expect(issue.message, contains('reserved name "all"'));
    });

    test('allows all identifier when generateIconMap is disabled', () {
      final files = const [
        IconFile(absolutePath: '/tmp/all.svg', relativePath: 'all.svg'),
      ];

      final result = resolver.resolveWithDiagnostics(
        files: files,
        prefixWithSubdir: false,
      );

      expect(
        result.issues.where((item) => item.code == 'reserved_identifier'),
        isEmpty,
      );
    });

    test('reports error when path-based name normalizes to an empty name', () {
      final files = const [
        IconFile(absolutePath: '/tmp/---.svg', relativePath: '---.svg'),
      ];

      final result = resolver.resolveWithDiagnostics(
        files: files,
        prefixWithSubdir: false,
      );

      final issue = result.issues.singleWhere(
        (item) => item.code == 'empty_name',
      );
      expect(issue.severity, NamingIssueSeverity.error);
      expect(issue.message, contains('produced an empty symbol name'));
    });

    test('reports error when a generated name starts with a digit', () {
      final result = resolver.resolveWithDiagnostics(
        files: const [
          IconFile(
            absolutePath: '/tmp/123-home.svg',
            relativePath: '123-home.svg',
          ),
        ],
        prefixWithSubdir: false,
      );

      final issue = result.issues.singleWhere(
        (item) => item.code == 'invalid_identifier',
      );
      expect(issue.severity, NamingIssueSeverity.error);
      expect(issue.message, contains('starts with a letter'));
    });

    test('reports representative Dart keywords as reserved identifiers', () {
      final result = resolver.resolveWithDiagnostics(
        files: const [
          IconFile(absolutePath: '/tmp/break.svg', relativePath: 'break.svg'),
          IconFile(absolutePath: '/tmp/import.svg', relativePath: 'import.svg'),
          IconFile(absolutePath: '/tmp/sealed.svg', relativePath: 'sealed.svg'),
        ],
        prefixWithSubdir: false,
      );

      expect(
        result.issues.where((issue) => issue.code == 'reserved_identifier'),
        hasLength(3),
      );
    });
  });
}
