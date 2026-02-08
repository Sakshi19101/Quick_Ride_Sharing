import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String rideId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhone;
  final String? otherUserPhotoUrl;

  const ChatScreen({
    Key? key,
    required this.rideId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhone,
    this.otherUserPhotoUrl,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  String? _chatRoomId;

  @override
  void initState() {
    super.initState();
    _generateChatRoomId();
  }

  void _generateChatRoomId() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Handle not logged in case
      return;
    }
    final currentUserId = currentUser.uid;
    final otherUserId = widget.otherUserId;

    // Create a consistent chat room ID regardless of who initiates the chat
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    _chatRoomId = '${ids[0]}_${ids[1]}';
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _chatRoomId == null) {
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    final messageText = _messageController.text.trim();
    
    // Save message to Firestore
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatRoomId) // Use the unique chat room ID
        .collection('messages')
        .add({
      'text': messageText,
      'senderId': currentUser.uid,
      'timestamp': Timestamp.now(),
    });

    // Send notification to the other user
    try {
      // Get current user's name from Firestore
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      String senderName = 'Unknown User';
      String senderPhone = '';
      
      if (currentUserDoc.exists && currentUserDoc.data() != null) {
        final userData = currentUserDoc.data() as Map<String, dynamic>;
        senderName = userData['name'] ?? userData['displayName'] ?? 'Unknown User';
        senderPhone = userData['phone'] ?? '';
      }

      // Send notification to the other user
      await NotificationService.sendChatNotification(
        recipientUserId: widget.otherUserId,
        senderName: senderName,
        messageText: messageText,
        rideId: widget.rideId,
        senderUserId: currentUser.uid,
        senderPhone: senderPhone,
      );
    } catch (e) {
      print('Error sending chat notification: $e');
      // Continue even if notification fails
    }

    _messageController.clear();
  }

  Future<void> _makeCall() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: widget.otherUserPhone,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not make a call to ${widget.otherUserPhone}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chatRoomId == null) {
      // This can happen if the user is not logged in when the screen initializes.
      // You can show a loading indicator or an error message.
      return Scaffold(
        appBar: AppBar(title: Text(widget.otherUserName)),
        body: const Center(child: Text("Error: Could not initialize chat.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.otherUserPhotoUrl != null)
              CircleAvatar(
                backgroundImage: NetworkImage(widget.otherUserPhotoUrl!),
              ),
            const SizedBox(width: 8),
            Text(widget.otherUserName),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _makeCall,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatRoomId) // Use the unique chat room ID
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final currentUser = FirebaseAuth.instance.currentUser;

                    if (currentUser == null) {
                      return const SizedBox.shrink();
                    }

                    final isMe = message['senderId'] == currentUser.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).primaryColor
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message['text'],
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a message...',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}