import 'package:flutter/foundation.dart';
import 'api.dart';

final ValueNotifier<String> language = ValueNotifier<String>('en');

const Map<String, String> _hi = {
  'Find': 'खोजें', 'Saved': 'सेव', 'Route': 'रूट', 'Profile': 'प्रोफ़ाइल',
  'Next': 'आगे', 'Get started': 'शुरू करें', 'Allow location': 'लोकेशन चालू करें', 'Search by city instead': 'शहर से खोजें',
  'We use your location to show chargers near you.': 'आपके पास के चार्जर दिखाने के लिए लोकेशन चाहिए।',
  'Search city, area or station': 'शहर, इलाका या स्टेशन खोजें', 'Filters': 'फ़िल्टर', 'Search this area': 'इस इलाके में खोजें',
  'Map': 'मैप', 'List': 'लिस्ट', 'Available': 'उपलब्ध', 'Busy': 'व्यस्त', 'Not working': 'बंद है', 'Status not known': 'स्थिति पता नहीं',
  'Get directions': 'रास्ता देखें', 'Share': 'शेयर', 'Report a problem': 'समस्या बताएं', 'Write a review': 'रिव्यू लिखें', 'Book a slot': 'स्लॉट बुक करें',
  'Connectors': 'कनेक्टर', 'Price': 'कीमत', 'Reviews': 'रिव्यू', 'Open now': 'अभी खुला', 'Closed now': 'अभी बंद',
  'Sign in': 'साइन इन', 'Mobile number': 'मोबाइल नंबर', 'Send OTP': 'OTP भेजें', 'Enter OTP': 'OTP डालें', 'Verify': 'जांचें',
  'My vehicles': 'मेरी गाड़ियां', 'My reports': 'मेरी रिपोर्ट', 'My bookings': 'मेरी बुकिंग', 'Notifications': 'सूचनाएं', 'Suggest a station': 'स्टेशन सुझाएं',
  'Language': 'भाषा', 'Sign out': 'साइन आउट', 'Delete account': 'खाता हटाएं', 'Save': 'सेव करें', 'Name': 'नाम', 'Email': 'ईमेल',
  'Recently viewed': 'हाल में देखे', 'Plan a trip': 'यात्रा प्लान करें', 'From': 'कहां से', 'To': 'कहां तक', 'My location': 'मेरी लोकेशन', 'Show stations': 'स्टेशन दिखाएं',
  'No stations found here. Try a bigger radius or clear filters.': 'यहां कोई स्टेशन नहीं मिला। दायरा बढ़ाएं या फ़िल्टर हटाएं।',
  'Try again': 'फिर कोशिश करें', 'Apply': 'लागू करें', 'Clear': 'हटाएं', 'Update required': 'अपडेट ज़रूरी है',
  'Please update the app to continue.': 'जारी रखने के लिए ऐप अपडेट करें।',
};

String t(String en) => language.value == 'hi' ? (_hi[en] ?? en) : en;

void loadLanguage() {
  language.value = Api.prefs.getString('lang') ?? 'en';
}

Future<void> setLanguage(String code) async {
  language.value = code;
  await Api.prefs.setString('lang', code);
  if (Api.loggedIn) {
    try {
      await Api.put('profile', {'language': code});
    } catch (_) {}
  }
}
