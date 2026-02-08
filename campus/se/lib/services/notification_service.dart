import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';
import '../screens/live_location_screen.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  static Future<void> initialize() async {
    try {
      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Set up message handlers (only if initialization successful)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      
      // Request permission in background
      Future.delayed(const Duration(seconds: 2), _requestPermission);
      
    } catch (e) {
      print('Error initializing notifications: $e');
      // Continue app initialization even if notifications fail
    }
  }

  static void _requestPermission() {
    _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    ).then((settings) {
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional permission');
      } else {
        print('User declined or has not accepted permission');
      }
    }).catchError((e) {
      print('Error requesting permission: $e');
    });
  }

  static void saveFCMToken() {
    _firebaseMessaging.getToken().then((token) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (token != null && currentUser != null) {
        final currentUserId = currentUser.uid;
        print('🔑 Generated FCM Token for user $currentUserId: ${token.substring(0, 20)}...');
        
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .set({'fcmToken': token}, SetOptions(merge: true))
            .then((_) {
          print('✅ FCM Token saved successfully for user $currentUserId');
        }).catchError((e) {
          print('❌ Error saving FCM token: $e');
        });
      } else {
        print('❌ No FCM token generated or user not logged in');
      }
    }).catchError((e) {
      print('❌ Error getting FCM token: $e');
    });
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification
    await _showLocalNotification(
      title: message.notification?.title ?? 'Campus Ride',
      body: message.notification?.body ?? 'You have a new notification',
      payload: jsonEncode(message.data),
    );
  }

  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('Received background message: ${message.messageId}');
    final data = message.data;
    if (data['screen'] == 'LiveLocation') {
      final rideId = data['rideId'];
      if (rideId != null && navigatorKey?.currentContext != null) {
        Navigator.of(navigatorKey!.currentContext!).push(
          MaterialPageRoute(builder: (_) => LiveLocationScreen(rideId: rideId)),
        );
      }
    } else if (data['screen'] == 'Chat') {
      // Handle chat navigation if needed
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'campus_ride_channel',
      'Campus Ride Notifications',
      channelDescription: 'Notifications for Campus Ride app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    
    if (response.payload != null && navigatorKey?.currentContext != null) {
      try {
        final data = jsonDecode(response.payload!);

        if (data['screen'] == 'LiveLocation') {
          final rideId = data['rideId'];
          if (rideId != null) {
            Navigator.of(navigatorKey!.currentContext!).push(
              MaterialPageRoute(builder: (_) => LiveLocationScreen(rideId: rideId)),
            );
          }
        } else if (data['screen'] == 'Chat') {
          // Handle chat navigation if needed
        }
      } catch (e) {
        print('Error handling notification tap: $e');
        // Fallback for old payload format
        final payload = response.payload!;
        if (payload.contains('chat')) {
          final parts = payload.split('|');
          if (parts.length >= 4) {
            final rideId = parts[1];
            final otherUserId = parts[2];
            final otherUserName = parts[3];
            final otherUserPhone = parts.length > 4 ? parts[4] : '';
            
            Navigator.of(navigatorKey!.currentContext!).pushNamed(
              '/chat',
              arguments: {
                'rideId': rideId,
                'otherUserId': otherUserId,
                'otherUserName': otherUserName,
                'otherUserPhone': otherUserPhone,
              },
            );
          }
        }
      }
    }
  }

  // Send notification to specific user
  static Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        String? fcmToken = userData['fcmToken'];
        if (fcmToken != null) {
          // In a real app, you would send this via your backend.
          // The following is a placeholder and does not send a real push notification.
          // It only logs to the console.
          print('Simulating sending push notification to $userId with title: $title and body: $body');
          
          // For demo purposes, we'll just show a local notification
          await _showLocalNotification(
            title: title,
            body: body,
            payload: data?.toString(),
          );
        }
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Send chat message notification
  static Future<void> sendChatNotification({
    required String recipientUserId,
    required String senderName,
    required String messageText,
    required String rideId,
    required String senderUserId,
    required String senderPhone,
  }) async {
    try {
      print('🔔 Attempting to send chat notification...');
      print('📤 Sender: $senderName ($senderUserId)');
      print('📥 Recipient: $recipientUserId');
      print('💬 Message: $messageText');
      
      // Get recipient's FCM token
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUserId)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data() as Map<String, dynamic>;
        String? fcmToken = userData['fcmToken'];
        
        print('🔑 Recipient FCM Token: ${fcmToken?.substring(0, 20)}...');
        
        if (fcmToken != null) {
          // Create payload for navigation
          final payload = 'chat|$rideId|$senderUserId|$senderName|$senderPhone';
          
          print('📦 Payload: $payload');
          
          // Send FCM notification to recipient's device
          await _sendFCMNotification(
            fcmToken: fcmToken,
            title: '💬 New message from $senderName',
            body: messageText.length > 50 ? '${messageText.substring(0, 50)}...' : messageText,
            payload: payload,
          );
          
          print('✅ Chat notification sent to $recipientUserId from $senderName');
        } else {
          print('❌ No FCM token found for user $recipientUserId');
          print('📋 User data: $userData');
        }
      } else {
        print('❌ User document not found for $recipientUserId');
      }
    } catch (e) {
      print('❌ Error sending chat notification: $e');
    }
  }

  // Send FCM notification to specific device
  static Future<void> _sendFCMNotification({
    required String fcmToken,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      print('🚀 Sending FCM notification...');
      print('🎯 Target Token: ${fcmToken.substring(0, 20)}...');
      print('📝 Title: $title');
      print('📄 Body: $body');
      
      // Use the proper FCM service to send notification to recipient's device
      final response = await FCMService.sendNotification(
        fcmToken: fcmToken,
        title: title,
        body: body,
        data: {
          'payload': payload ?? '',
          'type': 'chat_message',
        },
      );
      
      print('📡 FCM Response: $response');
      
      if (response['success'] == true) {
        print('✅ FCM notification sent successfully to recipient device');
      } else {
        print('❌ FCM notification failed: ${response['error']}');
        print('🔄 Falling back to local notification...');
        // Fallback to local notification for testing
        await _showLocalNotification(
          title: title,
          body: body,
          payload: payload,
        );
      }
    } catch (e) {
      print('❌ Error sending FCM notification: $e');
      print('🔄 Falling back to local notification...');
      // Fallback to local notification for testing
      await _showLocalNotification(
        title: title,
        body: body,
        payload: payload,
      );
    }
  }

  // Send ride-related notifications
  static Future<void> sendRideNotification({
    required String userId,
    required String type, // 'ride_posted', 'ride_booked', 'ride_cancelled', 'driver_arrived'
    required Map<String, dynamic> rideData,
  }) async {
    String title = '';
    String body = '';

    switch (type) {
      case 'ride_posted':
        title = '🚗 Ride Posted Successfully!';
        body = 'Your ride from ${rideData['from']} to ${rideData['to']} has been posted.';
        break;
      case 'ride_booked':
        title = '✅ Ride Booked!';
        body = 'You have successfully booked a ride for ₹${rideData['fare']}.';
        break;
      case 'ride_cancelled':
        title = '❌ Ride Cancelled';
        body = 'Your ride has been cancelled. Refund will be processed soon.';
        break;
      case 'driver_arrived':
        title = '🚗 Driver Arrived!';
        body = 'Your driver has arrived at the pickup location.';
        break;
      default:
        title = 'Campus Ride';
        body = 'You have a new notification.';
    }

    await sendNotificationToUser(
      userId: userId,
      title: title,
      body: body,
      data: rideData,
    );
  }

  // Notify driver when a rider books their ride
  static Future<void> notifyDriverOfBooking({
    required String driverUserId,
    required String riderName,
    required String riderContact,
    required Map<String, dynamic> rideData,
    int? numberOfSeats,
  }) async {
    try {
      // Fetch driver's FCM token
      final driverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverUserId)
          .get();

      if (!driverDoc.exists || driverDoc.data() == null) {
        print('❌ Driver user document not found for $driverUserId');
        return;
      }

      final driverData = driverDoc.data() as Map<String, dynamic>;
      final String? fcmToken = driverData['fcmToken'];

      if (fcmToken == null) {
        print('❌ No FCM token for driver $driverUserId');
        return;
      }

      final from = rideData['from']?.toString() ?? '';
      final to = rideData['to']?.toString() ?? '';
      final date = rideData['date']?.toString() ?? '';
      final time = rideData['time']?.toString() ?? '';
      final fare = rideData['fare']?.toString() ?? '';
      final seatsStr = numberOfSeats != null && numberOfSeats > 0 ? ' • Seats: $numberOfSeats' : '';

      final title = '🆕 New booking from $riderName';
      final body = 'Trip $from → $to on $date at $time • Fare: ₹$fare$seatsStr';

      // Include rich payload for potential navigation or display
      final payload = jsonEncode({
        'type': 'ride_booking',
        'riderName': riderName,
        'riderContact': riderContact ?? '',
        'from': from,
        'to': to,
        'date': date,
        'time': time,
        'fare': fare,
        'seats': numberOfSeats?.toString() ?? '1',
      });

      await _sendFCMNotification(
        fcmToken: fcmToken,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (e) {
      print('❌ Error notifying driver of booking: $e');
    }
  }

  // Notify driver about payment status
  static Future<void> notifyDriverPaymentStatus({
    required String driverUserId,
    required num amount,
    required String method, // 'online' | 'cash'
    required Map<String, dynamic> rideData,
  }) async {
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(driverUserId)
          .get();

      if (!driverDoc.exists || driverDoc.data() == null) {
        print('❌ Driver user document not found for $driverUserId');
        return;
      }

      final driverData = driverDoc.data() as Map<String, dynamic>;
      final String? fcmToken = driverData['fcmToken'];
      if (fcmToken == null) {
        print('❌ No FCM token for driver $driverUserId');
        return;
      }

      final from = rideData['from']?.toString() ?? '';
      final to = rideData['to']?.toString() ?? '';
      final date = rideData['date']?.toString() ?? '';
      final time = rideData['time']?.toString() ?? '';
      final methodLabel = method == 'cash' ? 'Cash' : 'Online';

      final title = '💳 Payment ${methodLabel == 'Cash' ? 'selected/received' : 'successful'}';
      final body = '${methodLabel} payment ₹$amount for $from → $to on $date $time';

      final payload = jsonEncode({
        'type': 'payment_status',
        'method': method,
        'amount': amount.toString(),
        'from': from,
        'to': to,
        'date': date,
        'time': time,
      });

      await _sendFCMNotification(
        fcmToken: fcmToken,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (e) {
      print('❌ Error notifying driver payment status: $e');
    }
  }
}
