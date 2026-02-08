# 🔑 Firebase Service Account Setup for Cross-Device Notifications

## 🚀 **Cross-Device Notifications with FCM v1 API**

Your app now uses the **Firebase Cloud Messaging v1 API** with **service account authentication** for reliable cross-device notifications.

## 📋 **Setup Instructions**

### **Step 1: Get Service Account JSON**

1. **Go to Firebase Console**: https://console.firebase.google.com/
2. **Select your project**: campus-rideshare-2025
3. **Click Settings** ⚙️ → **Project Settings**
4. **Go to Service Accounts tab**
5. **Click "Generate new private key"**
6. **Download the JSON file**

### **Step 2: Update Service Account File**

1. **Open**: `lib/service_account.dart`
2. **Replace the placeholder values** with your actual service account data:

```dart
class ServiceAccount {
  static const Map<String, dynamic> json = {
    "type": "service_account",
    "project_id": "campus-rideshare-2025",
    "private_key_id": "YOUR_ACTUAL_PRIVATE_KEY_ID",
    "private_key": "-----BEGIN PRIVATE KEY-----\nYOUR_ACTUAL_PRIVATE_KEY\n-----END PRIVATE KEY-----\n",
    "client_email": "firebase-adminsdk-xxxxx@campus-rideshare-2025.iam.gserviceaccount.com",
    "client_id": "YOUR_ACTUAL_CLIENT_ID",
    // ... copy all values from your downloaded JSON
  };
}
```

### **Step 3: Test Cross-Device Notifications**

1. **Run**: `flutter run`
2. **Login on two devices** with different accounts
3. **Send chat messages** between them
4. **Check console logs** for:
   ```
   🔑 Access Token: ya29.a0AfH6SMC...
   ✅ Notification sent successfully via FCM v1 API!
   ```

## 🔍 **How It Works**

### **FCM v1 API Benefits:**
- ✅ **More reliable** than legacy API
- ✅ **Better error handling**
- ✅ **Automatic token management**
- ✅ **Secure service account authentication**

### **Cross-Device Flow:**
1. **Driver sends message** → App gets access token → Sends notification to rider's device
2. **Rider sends message** → App gets access token → Sends notification to driver's device
3. **Recipient receives notification** on their device (not sender's device)
4. **Tapping notification** opens the specific chat screen

## 🔒 **Security Features**

- ✅ **Service account authentication** (more secure than server key)
- ✅ **Automatic token refresh**
- ✅ **Scoped permissions** (only Firebase Messaging)
- ✅ **No hardcoded credentials** in client code

## 📱 **Expected Results**

Once you add your service account JSON:
- ✅ **Access tokens generated** automatically
- ✅ **Notifications sent** to recipient devices
- ✅ **Cross-device messaging** working perfectly
- ✅ **No more 404 errors**

## 🚨 **Important Notes**

- **Never commit** the service account JSON to version control
- **Keep private keys secure**
- **The client_email** should end with `@campus-rideshare-2025.iam.gserviceaccount.com`
- **Test on two different devices** to verify cross-device functionality

Your cross-device notification system is now ready with the modern FCM v1 API! 🎉
