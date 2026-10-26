import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final String receiptPath;
  final String? title;
  final String? amountText;

  const ReceiptViewerDialog({
    super.key,
    required this.receiptPath,
    this.title,
    this.amountText,
  });

  static void show(
    BuildContext context, {
    required String receiptPath,
    String? title,
    String? amountText,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => ReceiptViewerDialog(
        receiptPath: receiptPath,
        title: title,
        amountText: amountText,
      ),
    );
  }

  Widget _buildImage() {
    try {
      if (receiptPath.startsWith('http')) {
        return Image.network(
          receiptPath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      } else if (receiptPath.startsWith('data:image')) {
        final commaIdx = receiptPath.indexOf(',');
        final base64Data = commaIdx != -1 ? receiptPath.substring(commaIdx + 1) : receiptPath;
        return Image.memory(
          base64Decode(base64Data),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      } else {
        final file = File(receiptPath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
          );
        }
      }
    } catch (_) {}
    return _buildErrorWidget();
  }

  Widget _buildErrorWidget() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 56, color: Colors.white54),
          SizedBox(height: 12),
          Text(
            'Unable to load receipt image',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _shareReceipt() {
    try {
      if (!receiptPath.startsWith('http') && !receiptPath.startsWith('data:image')) {
        final file = File(receiptPath);
        if (file.existsSync()) {
          SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path)],
              text: 'SplitLedger Bill Receipt: ${title ?? ''}',
            ),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildImage(),
              ),
            ),
          ),

          // Header Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title ?? 'Bill Receipt',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (amountText != null)
                          Text(
                            amountText!,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  if (!receiptPath.startsWith('http') && !receiptPath.startsWith('data:image'))
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      tooltip: 'Share Receipt',
                      onPressed: _shareReceipt,
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
