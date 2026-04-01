import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider((ref) => ApiService());

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier();
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([
    ChatMessage(text: "Hello! I'm Msosi. Please choose an option by typing its number:\n\n1. Show menu\n2. Show list of restaurants\n3. My orders", type: MessageType.bot),
  ]);

  void sendMessage(String text) async {
    state = [...state, ChatMessage(text: text, type: MessageType.user)];
    
    // Simple command handling
    String response = _processCommand(text);
    
    // Simulate bot delay
    await Future.delayed(const Duration(milliseconds: 1000));
    state = [...state, ChatMessage(text: response, type: MessageType.bot)];
  }

  String _processCommand(String text) {
    String cmd = text.trim().toLowerCase();
    
    if (cmd.startsWith('show me the menu for')) {
      return "Fetching the menu... (In a full app, this would display the items inline!)";
    }

    if (cmd == '1' || cmd == '1.' || cmd.contains('menu')) {
      return "To see a menu, please navigate to the Restaurants tab and tap on a restaurant!";
    } else if (cmd == '2' || cmd == '2.' || cmd.contains('list') || cmd.contains('restaurant')) {
      return "Sure! Check out the 'Restaurants' tab to see what's open.";
    } else if (cmd == '3' || cmd == '3.' || cmd.contains('order')) {
      return "You can view your order history in the 'Orders' section.";
    } else {
      return "Please choose a valid option:\n1. Show menu\n2. Show list of restaurants\n3. My orders";
    }
  }
}
