import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatChefModal extends StatefulWidget {
  const ChatChefModal({super.key});

  @override
  State<ChatChefModal> createState() => _ChatChefModalState();
}

class _ChatChefModalState extends State<ChatChefModal> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final String _endpoint = 'https://chef-gpt-api-swart.vercel.app/api/chat';
  final String _context =
      'User is chatting about a food dish. Suggest improvements or healthy alternatives. Talk food like a pro.';

  List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final userMsg = {'role': 'user', 'content': text.trim()};
    setState(() {
      _messages.add(userMsg);
      _isSending = true;
    });

    _controller.clear();
    _focusNode.unfocus();
    await _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': _messages,
          'context': _context,
        }),
      );

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final reply = json['reply'];

        if (reply != null && reply is String) {
          setState(() {
            _messages.add({'role': 'assistant', 'content': reply.trim()});
          });
        } else {
          throw Exception("No valid 'reply' field in response");
        }
      } else {
        throw Exception("HTTP \${res.statusCode}: \${res.reasonPhrase}");
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '⚠️ Oops! Failed to get a response. Error: \${e.toString()}',
        });
      });
    } finally {
      setState(() => _isSending = false);
      await _scrollToBottom();
    }
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundImage:
                const AssetImage('assets/gpt_avatar.png'),
              ),
            ),
          Flexible(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.white.withOpacity(0.9)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 16),
                ),
              ),
              child: Text(
                msg['content'],
                style: TextStyle(
                  color: isUser ? Colors.black : Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundImage:
                const AssetImage('assets/profile_placeholder.jpg'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        curve: Curves.easeOut,
        child: FractionallySizedBox(
          heightFactor: 0.95,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Scaffold(
                backgroundColor: Colors.black.withOpacity(0.6),
                resizeToAvoidBottomInset: false,
                body: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        "👨‍🍳 Chat with the Chef",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 10),
                        itemCount: _messages.length + (_isSending ? 1 : 0),
                        itemBuilder: (_, index) {
                          if (_isSending && index == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.only(left: 16, top: 8),
                              child: TypingIndicator(),
                            );
                          }
                          return _buildMessage(_messages[index]);
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                style: const TextStyle(color: Colors.white),
                                textInputAction: TextInputAction.send,
                                decoration: const InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle:
                                  TextStyle(color: Colors.white60),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: _sendMessage,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => _sendMessage(_controller.text),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                              ),
                              child:
                              const Icon(Icons.send, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat();

    _animation1 = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeInOut)),
    );
    _animation2 = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 0.8, curve: Curves.easeInOut)),
    );
    _animation3 = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.4, 1.0, curve: Curves.easeInOut)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(_animation1),
          const SizedBox(width: 6),
          _buildDot(_animation2),
          const SizedBox(width: 6),
          _buildDot(_animation3),
        ],
      ),
    );
  }
}
