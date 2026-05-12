// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:obdreader2/data/app_database.dart';
import 'package:obdreader2/main.dart';

void main() {
  testWidgets('App shows OBD-II home', (WidgetTester tester) async {
    await tester.pumpWidget(
      Provider<AppDatabase>.value(
        value: AppDatabase(),
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OBD-II Connection'), findsWidgets);
    expect(find.text('Search for OBD'), findsOneWidget);
  });
}
