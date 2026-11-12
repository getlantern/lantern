import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme;
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/models/website.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/local_storage_service.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/provider/website_notifier.dart';
import 'package:lantern/features/split_tunneling/website_domain_input.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:lantern/lantern/lantern_service_notifier.dart';

class _Snapshot extends SplitTunnel {
  _Snapshot(this.policy);
  final SplitTunnelPolicy policy;
  @override
  Future<SplitTunnelState> build() async =>
      SplitTunnelState(enabled: true, policy: policy);
}

class _Websites extends SplitTunnelingWebsites {
  Set<Website> initial = {};
  List<Website> added = [];
  Map<Website, Failure> failures = {};
  Completer<void>? saving;
  @override
  FutureOr<Set<Website>> build() => initial;
  @override
  Future<Map<Website, Failure>> addWebsites(List<Website> websites) async {
    added.addAll(websites);
    await saving?.future;
    return failures;
  }
}

class _Normalizer implements LanternService {
  String canonical = '.xn--bcher-kva.example';
  String Function(String)? canonicalFor;
  final inputs = <String>[];
  Failure? failure;
  @override
  Future<Either<Failure, String>> normalizeSplitTunnelWebsite(
    String input,
  ) async {
    inputs.add(input);
    if (failure != null) return left(failure!);
    return right(canonicalFor?.call(input) ?? canonical);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements LocalStorageService {
  @override
  bool get hasSeenBypassWebsiteDialog => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Normalizer normalizer;
  late _Websites websites;
  setUp(() async {
    await sl.reset();
    sl.registerSingleton<LocalStorageService>(_Storage());
    normalizer = _Normalizer();
    websites = _Websites();
  });
  tearDown(() => sl.reset());

  Future<void> pump(
    WidgetTester tester, {
    SplitTunnelPolicy policy = SplitTunnelPolicy.includeOnly,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lanternServiceProvider.overrideWithValue(normalizer),
          splitTunnelProvider.overrideWith(() => _Snapshot(policy)),
          splitTunnelingWebsitesProvider.overrideWith(() => websites),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            theme: AppTheme.appTheme(),
            home: const Scaffold(body: WebsiteDomainInput()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester, String input) async {
    await tester.enterText(
      find.byKey(const Key('split_tunneling.website.input')),
      input,
    );
    await tester.tap(
      find.byKey(const Key('split_tunneling.website.add_button')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'uses shared IDNA normalization and Include only skips bypass explanation',
    (tester) async {
      await pump(tester);
      await add(tester, '*.BÜCHER.Example.');
      expect(normalizer.inputs, ['*.BÜCHER.Example.']);
      expect(websites.added.single.domain, '.xn--bcher-kva.example');
      expect(websites.added.single.displayDomain, '*.xn--bcher-kva.example');
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('canonical duplicate in existing selections is rejected', (
    tester,
  ) async {
    websites.initial = {const Website(domain: '.xn--bcher-kva.example')};
    await pump(tester);
    await add(tester, '*.BÜCHER.Example');
    expect(websites.added, isEmpty);
    expect(find.text('split_tunnel_website_duplicate'), findsOneWidget);
  });

  testWidgets('duplicate batch is validated before any mutation', (
    tester,
  ) async {
    await pump(tester);
    await add(tester, '*.bücher.example, *.xn--bcher-kva.example');
    expect(websites.added, isEmpty);
    expect(normalizer.inputs, hasLength(2));
  });

  testWidgets('core validation errors and mutation errors preserve input', (
    tester,
  ) async {
    normalizer.failure = Failure(
      error: 'invalid split-tunnel website: "*ir"',
      localizedErrorMessage: 'invalid split-tunnel website: "*ir"',
    );
    await pump(tester);
    await add(tester, '*ir');
    expect(normalizer.inputs, ['*ir']);
    expect(find.text('split_tunnel_invalid_website'), findsOneWidget);
    expect(websites.added, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '*ir',
    );
    ScaffoldMessenger.of(
      tester.element(find.byType(WebsiteDomainInput)),
    ).removeCurrentSnackBar();
    await tester.pumpAndSettle();
    normalizer.failure = null;
    normalizer.canonical = 'example.com';
    websites.failures = {
      const Website(domain: 'example.com'): Failure(
        error: 'save',
        localizedErrorMessage: 'Could not save',
      ),
    };
    await add(tester, 'example.com');
    expect(find.text('Could not save'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'example.com',
    );
  });

  testWidgets('empty comma-separated parts are skipped', (tester) async {
    normalizer.canonicalFor = (input) => input;
    await pump(tester);
    await add(tester, 'a.com,, b.com,');
    expect(normalizer.inputs, ['a.com', 'b.com']);
    expect(websites.added.map((website) => website.domain), ['a.com', 'b.com']);
  });

  testWidgets('a partial failure keeps only the unsaved websites', (
    tester,
  ) async {
    normalizer.canonicalFor = (input) => input.toLowerCase();
    websites.failures = {
      const Website(domain: 'b.com'): Failure(
        error: 'save',
        localizedErrorMessage: 'Could not save',
      ),
    };
    await pump(tester);
    await add(tester, 'a.com, B.com');
    expect(find.text('Could not save'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'B.com',
    );
  });

  testWidgets('text typed while a save is pending is kept', (tester) async {
    websites.saving = Completer();
    await pump(tester);
    final input = find.byKey(const Key('split_tunneling.website.input'));
    await tester.enterText(input, 'a.com');
    await tester.tap(
      find.byKey(const Key('split_tunneling.website.add_button')),
    );
    await tester.pump();
    expect(websites.added, hasLength(1));
    await tester.enterText(input, 'b.com');
    websites.saving!.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'b.com',
    );
  });

  testWidgets('bypass explanation cancellation leaves lists unchanged', (
    tester,
  ) async {
    await pump(tester, policy: SplitTunnelPolicy.bypass);
    await add(tester, '*.bücher.example');
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(websites.added, isEmpty);
    await tester.tap(find.text('cancel'));
    await tester.pumpAndSettle();
    expect(websites.added, isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '*.bücher.example',
    );
  });
}
