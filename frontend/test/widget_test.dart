import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatbot/core/theme/app_theme.dart';
import 'package:chatbot/data/datasources/local_storage.dart';
import 'package:chatbot/data/providers/repository_providers.dart';
import 'package:chatbot/features/chat/chat_screen.dart';
import 'package:chatbot/features/chat/widgets/chat_input_field.dart';
import 'package:chatbot/features/chat/widgets/suggested_prompts.dart';

void main() {
  testWidgets('ChatScreen displays dynamic title, model badge, actions, and opens drawer', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = LocalStorage(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ChatScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dynamic AppBar title
    expect(find.text('Nova Chat'), findsOneWidget);

    // Verify Chat Input bar is present
    expect(find.byType(ChatInputField), findsOneWidget);

    // Verify dynamic greeting is displayed for empty chat
    expect(find.byType(SuggestedPrompts), findsOneWidget);
    expect(find.text('How can I help you today?'), findsOneWidget);

    // Verify menu button is present in AppBar
    final menuButton = find.byIcon(Icons.menu_rounded);
    expect(menuButton, findsOneWidget);

    // Tap menu button to open top-right drawer
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Verify buttons in the drawer: Profile and New Chat
    expect(find.text('New Chat'), findsWidgets);
    expect(find.text('Guest User'), findsOneWidget);
    expect(find.text('CHATS'), findsOneWidget);
  });
}
