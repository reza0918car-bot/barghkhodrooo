// 👈 مسیر ایمپورت اصلاح شد
import 'package:sms_sender_background/sms_sender.dart';

class SmsHelper {
  static final SmsSender _smsSender = SmsSender();

  static Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      bool hasPermission = await _smsSender.checkSmsPermission();
      if (!hasPermission) {
        hasPermission = await _smsSender.requestSmsPermission();
      }
      
      if (!hasPermission) {
        return false;
      }

      return await _smsSender.sendSms(
        phoneNumber: phoneNumber,
        message: message,
      );
    } catch (e) {
      return false;
    }
  }
}
