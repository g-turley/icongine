import 'package:example/main.dart';
import 'package:example/generated/example_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filters icons and recovers by clearing the search', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('${ExampleIcons.all.length} icons'), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'does-not-exist');
    await tester.pump();

    expect(find.textContaining('No icons match'), findsOneWidget);
    expect(find.text('0 icons'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.text('${ExampleIcons.all.length} icons'), findsOneWidget);
    expect(find.textContaining('No icons match'), findsNothing);
  });
}
