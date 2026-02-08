import 'package:flutter/material.dart';
import 'services/notification_service.dart';

/// Test widget to demonstrate chat notification functionality
/// This can be used for testing the notification system
class NotificationTestWidget extends StatelessWidget {
  const NotificationTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Notifications'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Chat Notifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Test sending a chat notification
                await NotificationService.sendChatNotification(
                  recipientUserId: 'test_user_id', // Replace with actual user ID
                  senderName: 'Test Driver',
                  messageText: 'Hello! I\'m on my way to pick you up.',
                  rideId: 'test_ride_id',
                  senderUserId: 'current_user_id',
                  senderPhone: '+1234567890',
                );
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent!')),
                );
              },
              child: const Text('Send Test Chat Notification'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                // Test sending a ride notification
                await NotificationService.sendRideNotification(
                  userId: 'test_user_id', // Replace with actual user ID
                  type: 'ride_booked',
                  rideData: {
                    'from': 'Campus Gate',
                    'to': 'Library',
                    'fare': '50',
                  },
                );
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test ride notification sent!')),
                );
              },
              child: const Text('Send Test Ride Notification'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cross-Device Testing Instructions:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Get Firebase Server Key from Firebase Console\n'
              '2. Update lib/services/fcm_service.dart with your server key\n'
              '3. Run app on TWO different devices\n'
              '4. Login with different accounts (driver & rider)\n'
              '5. Send chat messages between devices\n'
              '6. Verify notifications appear on recipient device\n'
              '7. Test notification tap navigation',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Current Status:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '✅ FCM tokens are automatically saved\n'
              '✅ Notifications target recipient device\n'
              '✅ Navigation to chat works\n'
              '⚠️ Requires Firebase Server Key for cross-device',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
