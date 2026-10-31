import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('ChatGoApp loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatGoApp());
    expect(find.byType(ChatGoApp), findsOneWidget);
  });
}
