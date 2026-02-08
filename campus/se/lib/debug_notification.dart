import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/notification_service.dart';
import 'services/fcm_service.dart';

/// Debug widget to help troubleshoot notification issues
class NotificationDebugWidget extends StatefulWidget {
  const NotificationDebugWidget({super.key});

  @override
  State<NotificationDebugWidget> createState() => _NotificationDebugWidgetState();
}

class _NotificationDebugWidgetState extends State<NotificationDebugWidget> {
  String? currentUserFCMToken;
  String? otherUserFCMToken;
  String? otherUserId;
  List<Map<String, dynamic>> users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _getCurrentUserToken();
  }

  Future<void> _getCurrentUserToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          currentUserFCMToken = userData['fcmToken'];
        });
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      setState(() {
        users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? data['displayName'] ?? 'Unknown',
            'fcmToken': data['fcmToken'],
            'role': data['role'] ?? 'unknown',
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _testDirectFCM(String targetToken, String targetUserId) async {
    try {
      print('🧪 Testing direct FCM notification...');
      
      final response = await FCMService.sendNotification(
        fcmToken: targetToken,
        title: '🧪 Test Notification',
        body: 'This is a test notification from debug widget',
        data: {
          'type': 'test',
          'from': 'debug_widget',
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('FCM Test Result: ${response['success'] ? 'Success' : 'Failed'}'),
          backgroundColor: response['success'] ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('FCM Test Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Notification Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadUsers();
              _getCurrentUserToken();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current User Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '👤 Current User',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('ID: ${FirebaseAuth.instance.currentUser?.uid ?? 'Not logged in'}'),
                    Text('FCM Token: ${currentUserFCMToken?.substring(0, 30) ?? 'No token'}...'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Users List
            const Text(
              '👥 All Users',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            ...users.map((user) => Card(
              child: ListTile(
                title: Text('${user['name']} (${user['role']})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${user['id']}'),
                    Text('FCM Token: ${user['fcmToken']?.substring(0, 30) ?? 'No token'}...'),
                  ],
                ),
                trailing: user['fcmToken'] != null && user['id'] != FirebaseAuth.instance.currentUser?.uid
                    ? ElevatedButton(
                        onPressed: () => _testDirectFCM(user['fcmToken'], user['id']),
                        child: const Text('Test'),
                      )
                    : null,
              ),
            )).toList(),
            
            const SizedBox(height: 16),
            
            // Debug Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔍 Debug Instructions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Check if all users have FCM tokens\n'
                      '2. Use "Test" button to send direct FCM notification\n'
                      '3. Check console logs for detailed debugging info\n'
                      '4. Verify Firebase Server Key is correct\n'
                      '5. Test on two different devices',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
