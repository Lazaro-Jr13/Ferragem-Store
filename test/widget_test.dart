import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ferragem_store/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mostra o titulo principal da aplicacao', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const FerragemStoreApp());
    await tester.pumpAndSettle();

    expect(find.text('Produtos'), findsOneWidget);
  });
}

