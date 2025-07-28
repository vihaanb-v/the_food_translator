import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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
  String? _profilePic;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _loadChatHistory().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
    _fetchProfilePicture();
  }

  void _fetchProfilePicture() {
    final user = FirebaseAuth.instance.currentUser;
    final rawUrl = user?.photoURL;
    if (rawUrl != null) {
      final bustedUrl = '$rawUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _profilePic = bustedUrl;
      });
    }
  }

  Future<void> _loadChatHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .orderBy('timestamp')
        .get();

    final safeMessages = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'role': data['role'],
        'content': data['content'],
        // DO NOT include 'timestamp' here
      };
    }).toList();

    setState(() {
      _messages = List<Map<String, dynamic>>.from(safeMessages);
    });
    await _scrollToBottom();
  }

  Future<void> _clearChatHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chatHistory');

    final batch = FirebaseFirestore.instance.batch();
    final docs = await ref.get();
    for (final doc in docs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _saveMessage(String role, String content) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .add({
      'role': role,
      'content': content,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final userMsg = {'role': 'user', 'content': text.trim()};
    setState(() {
      _messages.add(userMsg);
      _isSending = true;
    });

    _controller.clear();
    _focusNode.unfocus();
    await _saveMessage('user', text.trim()); // ✅ Save user message

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
          final assistantMsg = {'role': 'assistant', 'content': reply.trim()};
          setState(() {
            _messages.add(assistantMsg);
          });
          await _saveMessage('assistant', reply.trim()); // ✅ Save assistant reply
        } else {
          throw Exception("No valid 'reply' field in response");
        }
      } else {
        throw Exception("HTTP ${res.statusCode}: ${res.reasonPhrase}");
      }
    } catch (e) {
      final errorMsg =
          '⚠️ Oops! Failed to get a response. Error: ${e.toString()}';
      final errorReply = {'role': 'assistant', 'content': errorMsg};
      setState(() {
        _messages.add(errorReply);
      });
      await _saveMessage('assistant', errorMsg); // ✅ Save error message
    } finally {
      setState(() => _isSending = false);
      await _scrollToBottom();
    }
  }

  Future<void> _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 250)); // Slightly longer wait
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 600), // Slower slide
        curve: Curves.easeOutQuart, // More natural easing
      );
    }
  }

  String _stripMarkdown(String text) {
    return text
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'\*'), '')
        .replaceAll(RegExp(r'^#+\s*'), '')
        .replaceAll(RegExp(r'\s+$'), '');
  }

  Widget _buildCleanRichText(String rawText) {
    final lines = rawText.trim().split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();

      bool isMarkdownBold = line.startsWith('**') && line.endsWith('**');
      bool isHeader = RegExp(r'^#+\s*').hasMatch(line);
      bool isBold = isMarkdownBold || isHeader;

      bool isBullet = line.startsWith('-') || line.startsWith('•');
      bool isNumbered = RegExp(r'^\d+\.\s').hasMatch(line);

      if (isBold) {
        // Forcefully insert a full blank line BEFORE every bold line
        spans.add(const TextSpan(text: '\n\n'));
      }

      if (isBold) {
        final clean = _stripMarkdown(line);
        spans.add(TextSpan(
          text: '$clean\n',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.white,
          ),
        ));
      } else if (isBullet) {
        final clean = _stripMarkdown(line.replaceFirst(RegExp(r'^[-•]\s*'), ''));
        spans.add(TextSpan(
          text: '• $clean\n',
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.white,
          ),
        ));
      } else if (isNumbered) {
        final clean = _stripMarkdown(line);
        spans.add(TextSpan(
          text: '$clean\n',
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.white,
          ),
        ));
      } else if (line.isNotEmpty) {
        final clean = _stripMarkdown(line);
        spans.add(TextSpan(
          text: '$clean\n',
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: Colors.white,
          ),
        ));
      }
    }

    // Trim final newlines
    if (spans.isNotEmpty) {
      final last = spans.last;
      if (last is TextSpan && last.text != null && last.text!.endsWith('\n')) {
        spans[spans.length - 1] = TextSpan(
          text: last.text!.replaceAll(RegExp(r'\n+$'), ''),
          style: last.style,
        );
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    final messageText = msg['content'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: const AssetImage('assets/gpt_avatar.png'),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              child: isUser
                  ? Text(
                messageText,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black,
                  height: 1.4,
                ),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCleanRichText(messageText),
                ],
              ),
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: _profilePic != null
                    ? NetworkImage(_profilePic!)
                    : const AssetImage('assets/profile_placeholder.jpg') as ImageProvider,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Full-screen blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🗑️ DELETE BUTTON
                      GestureDetector(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            barrierDismissible: true,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: const EdgeInsets.symmetric(horizontal: 32),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.black.withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded,
                                            color: Colors.redAccent, size: 40),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Clear Chat History?',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'This will permanently delete your chat history with the Chef.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.white70,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 20, vertical: 10),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12)),
                                              ),
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );

                          if (confirmed == true) {
                            await _clearChatHistory();
                            setState(() {
                              _messages.clear();
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      // 🧑‍🍳 TITLE
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/chef_hat.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Chat with the Chef',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      // ❌ CLOSE BUTTON
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(10),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Chat messages
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 30),
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

              // Input field
              AnimatedPadding(
                duration: const Duration(milliseconds: 250),
                padding: EdgeInsets.only(bottom: bottomInset),
                curve: Curves.easeOut,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                hintStyle: TextStyle(color: Colors.white60),
                                border: InputBorder.none,
                              ),
                              onSubmitted: _sendMessage,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _sendMessage(_controller.text),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                            ),
                            child: const Icon(Icons.send, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
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
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );
    _animation2 = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );
    _animation3 = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
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