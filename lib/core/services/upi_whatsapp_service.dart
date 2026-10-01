import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpiWhatsAppService {
  /// Opens WhatsApp with a pre-filled settlement reminder message
  static Future<bool> sendWhatsAppReminder({
    required BuildContext context,
    required String recipientName,
    required double amount,
    String? phoneNumber,
    String? customNote,
  }) async {
    final formattedAmount = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    final message = customNote != null && customNote.isNotEmpty
        ? customNote
        : '👋 Hi *$recipientName*,\n\n'
            'Friendly reminder from *SplitLedger*: You have a pending balance of *₹$formattedAmount*.\n\n'
            'Please settle up when convenient. Thank you! ✨';

    final encodedMessage = Uri.encodeComponent(message);
    
    // If phone number provided, direct to user, otherwise open WhatsApp chat chooser
    final cleanPhone = phoneNumber?.replaceAll(RegExp(r'[^\d+]'), '');
    final uriString = (cleanPhone != null && cleanPhone.isNotEmpty)
        ? 'https://wa.me/$cleanPhone?text=$encodedMessage'
        : 'whatsapp://send?text=$encodedMessage';

    final uri = Uri.parse(uriString);
    final fallbackWebUri = Uri.parse('https://api.whatsapp.com/send?text=$encodedMessage');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else if (await canLaunchUrl(fallbackWebUri)) {
        await launchUrl(fallbackWebUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open WhatsApp. Please ensure WhatsApp is installed.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching WhatsApp: $e')),
        );
      }
      return false;
    }
  }

  /// Launches installed UPI apps (GPay, PhonePe, Paytm, Cred, BHIM) with pre-filled amount and payee
  static Future<bool> payViaUpi({
    required BuildContext context,
    required String payeeName,
    required double amount,
    String upiId = '',
    String note = 'SplitLedger Settlement',
  }) async {
    final formattedAmount = amount.toStringAsFixed(2);
    final encodedPayeeName = Uri.encodeComponent(payeeName.trim());
    final encodedNote = Uri.encodeComponent(note.trim());

    // Standard NPCI UPI URI Scheme
    final upiUriString = upiId.isNotEmpty
        ? 'upi://pay?pa=$upiId&pn=$encodedPayeeName&am=$formattedAmount&cu=INR&tn=$encodedNote'
        : 'upi://pay?pn=$encodedPayeeName&am=$formattedAmount&cu=INR&tn=$encodedNote';

    final uri = Uri.parse(upiUriString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No UPI payment apps (GPay/PhonePe/Paytm) found on this device.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch UPI app: $e')),
        );
      }
      return false;
    }
  }
}
