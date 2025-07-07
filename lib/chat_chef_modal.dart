import 'package:flutter/material.dart';

class ChatChefModal extends StatefulWidget {
  const ChatChefModal({super.key});

  @override
  State<ChatChefModal> createState() => _ChatChefModalState();
}

class _ChatChefModalState extends State<ChatChefModal> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _messages.add({
        'role': 'gpt',
        'text': _generateChefReply(text),
      });
    });
    _controller.clear();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final contextString = latestSavedDishTitleAndIngredients(); // define this

    setState(() {
      _messages.add({'role': 'user', 'text': text});
    });

    final uri = Uri.parse("https://your-api.com/gpt-chef"); // replace

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "messages": _messages
              .map((m) => {"role": m['role'], "content": m['text']})
              .toList(),
          "context": contextString,
        }),
      );

      final data = jsonDecode(response.body);
      final reply = data['reply'] ?? "Sorry, chef forgot what to say 😅";

      setState(() {
        _messages.add({'role': 'gpt', 'text': reply});
      });

      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('chatHistory')
            .add({
          'prompt': text,
          'reply': reply,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({'role': 'gpt', 'text': 'Oops! GPT failed. Try again later.'});
      });
    }

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const Text(
                "👨‍🍳 Chat with ChefGPT",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    return Container(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Colors.white.withOpacity(0.9)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          msg['text']!,
                          style: TextStyle(
                            color: isUser ? Colors.black : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Ask the chef something...",
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white10,
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () => _sendMessage(_controller.text),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}