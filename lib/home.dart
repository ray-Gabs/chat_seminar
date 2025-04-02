import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isTyping = false;

  /// Function to send a new message to Firestore
  Future<void> _sendMessage() async {
    final user = _auth.currentUser;
    if (_messageController.text.trim().isEmpty || user == null) return;

    try {
      await _firestore.collection('messages').add({
        'text': _messageController.text.trim(),
        'sender': user.email,
        'likes': 0, // Initialize likes to 0
        'timestamp': FieldValue.serverTimestamp(), // Orders messages by time
      });

      _messageController.clear(); // Clear input field after sending
      _updateTypingStatus(false); // Reset typing status after sending the message
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  /// Function to like a message
  Future<void> _likeMessage(String messageId, int currentLikes) async {
    try {
      await _firestore.collection('messages').doc(messageId).update({
        'likes': currentLikes + 1, // Increment like count
      });
    } catch (e) {
      print('Error liking message: $e');
    }
  }

  /// Function to log out the current user
  Future<void> _logout() async {
    try {
      await _auth.signOut();
      // Navigate to login screen or any other screen after logout
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  /// Update typing status in Firestore
  Future<void> _updateTypingStatus(bool isTyping) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('typing_status').doc(user.uid).set({
        'isTyping': isTyping,
        'sender': user.email,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void initState() {
    super.initState();

    // Listen to text changes in the input field
    _messageController.addListener(() {
      if (_messageController.text.isEmpty && _isTyping) {
        _updateTypingStatus(false);
        setState(() {
          _isTyping = false;
        });
      } else if (_messageController.text.isNotEmpty && !_isTyping) {
        _updateTypingStatus(true);
        setState(() {
          _isTyping = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Room'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout, // Trigger the logout function
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('messages')
                  .orderBy('timestamp', descending: true) // Newest messages first
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet!'));
                } else {
                  final messages = snapshot.data!.docs;
                  return ListView.builder(
                    reverse: true, // New messages appear at the bottom
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final messageId = message.id;
                      final messageData = message.data() as Map<String, dynamic>;

                      return ListTile(
                        title: Text(messageData['text']),
                        subtitle: Text(messageData['sender'] ?? 'Unknown'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Display the like count
                            Text(messageData['likes']?.toString() ?? '0'),
                            IconButton(
                              icon: Icon(Icons.thumb_up, color: Colors.red),
                              onPressed: () {
                                _likeMessage(messageId, messageData['likes'] ?? 0);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // Typing status display (for multiple users)
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('typing_status').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final typingUsers = snapshot.data!.docs;
                      final typingUsersList = typingUsers
                          .where((userDoc) => userDoc['isTyping'] == true)
                          .map((userDoc) => userDoc['sender'] as String)
                          .toList();

                      if (typingUsersList.isNotEmpty) {
                        return Text("${typingUsersList.join(", ")} is typing...");
                      }
                    }
                    return Container(); // If no users are typing, return an empty container
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Enter your message...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.blue),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
