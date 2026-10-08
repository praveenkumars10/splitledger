import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Prompts for payee UPI ID (optional) and launches installed UPI apps (GPay, PhonePe, Paytm, Cred, BHIM)
  static Future<bool> payViaUpi({
    required BuildContext context,
    required String payeeName,
    required double amount,
    String upiId = '',
    String note = 'SplitLedger Settlement',
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => _UpiPaymentDialog(
        payeeName: payeeName,
        amount: amount,
        initialUpiId: upiId,
        note: note,
      ),
    ) ?? false;
  }

  /// Internal launcher for standard NPCI UPI URI
  static Future<bool> launchUpiUri({
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
        ? 'upi://pay?pa=${upiId.trim()}&pn=$encodedPayeeName&am=$formattedAmount&cu=INR&tn=$encodedNote'
        : 'upi://pay?pn=$encodedPayeeName&am=$formattedAmount&cu=INR&tn=$encodedNote';

    final uri = Uri.parse(upiUriString);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No UPI payment apps (GPay/PhonePe/Paytm) found on this device. Payment details copied to clipboard.',
              ),
              backgroundColor: Colors.orange.shade800,
              action: SnackBarAction(
                label: 'Copy Details',
                textColor: Colors.white,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: 'Pay ₹$formattedAmount to $payeeName ${upiId.isNotEmpty ? "($upiId)" : ""}'),
                  );
                },
              ),
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

class _UpiPaymentDialog extends StatefulWidget {
  final String payeeName;
  final double amount;
  final String initialUpiId;
  final String note;

  const _UpiPaymentDialog({
    required this.payeeName,
    required this.amount,
    required this.initialUpiId,
    required this.note,
  });

  @override
  State<_UpiPaymentDialog> createState() => _UpiPaymentDialogState();
}

class _UpiPaymentDialogState extends State<_UpiPaymentDialog> {
  late final TextEditingController _upiController;

  @override
  void initState() {
    super.initState();
    _upiController = TextEditingController(text: widget.initialUpiId);
  }

  @override
  void dispose() {
    _upiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = widget.amount.toStringAsFixed(widget.amount.truncateToDouble() == widget.amount ? 0 : 2);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'UPI Payment',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  Text(
                    '₹$formattedAmount',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Paying to: ${widget.payeeName}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _upiController,
              decoration: const InputDecoration(
                labelText: 'Payee UPI ID (Optional)',
                hintText: 'e.g. name@okhdfcbank / 9876543210@paytm',
                prefixIcon: Icon(Icons.alternate_email, size: 20),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'If left blank, Android will open your UPI app to select or search the payee.',
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new, size: 16),
          label: const Text('Pay via UPI'),
          onPressed: () async {
            final upiId = _upiController.text.trim();
            Navigator.pop(context, true);
            await UpiWhatsAppService.launchUpiUri(
              context: context,
              payeeName: widget.payeeName,
              amount: widget.amount,
              upiId: upiId,
              note: widget.note,
            );
          },
        ),
      ],
    );
  }
}
