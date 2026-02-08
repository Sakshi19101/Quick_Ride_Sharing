# Firebase Server Key Setup Guide

## How to Get Your Firebase Server Key

### Step 1: Access Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (campus ride sharing project)

### Step 2: Get Server Key
1. Click on the **⚙️ Settings** (gear icon) in the left sidebar
2. Select **Project settings**
3. Go to the **Cloud Messaging** tab
4. Find the **Server key** section
5. Copy the server key (it looks like: `AAAA...`)

### Step 3: Update Your Code
1. Open `lib/services/fcm_service.dart`
2. Replace `YOUR_FIREBASE_SERVER_KEY_HERE` with your actual server key:

```dart
static const String _serverKey = 'AAAA_your_actual_server_key_here';
```

### Step 4: Test the Implementation
1. Run the app on two different devices
2. Login with different accounts (driver and rider)
3. Send a chat message from one device
4. Check if notification appears on the other device

## Important Security Notes

⚠️ **Security Warning**: 
- Never commit the server key to version control
- Consider using environment variables or secure storage
- For production, implement server-side notification sending

## Alternative: Server-Side Implementation

For production apps, it's recommended to:
1. Create a backend service (Node.js, Python, etc.)
2. Use Firebase Admin SDK
3. Send notifications from your server instead of client-side

## Testing Without Server Key

If you don't have the server key yet, the app will:
1. Try to send FCM notification
2. Fall back to local notification if it fails
3. Log the error for debugging

This allows you to test the notification flow even without the server key.
