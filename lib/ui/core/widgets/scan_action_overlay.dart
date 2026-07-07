import 'package:flutter/material.dart';
import 'package:open_photo_link/domain/models/scan_result.dart';

class ScanActionOverlay extends StatelessWidget {
  final List<ScanResult> scanResults;
  final Function(String? intentUri, Map<String, dynamic> data) onActionPressed;

  const ScanActionOverlay({
    Key? key,
    required this.scanResults,
    required this.onActionPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: scanResults.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final result = scanResults[index];
          final data = result.data;

          IconData icon;
          String title;
          String subtitle;
          Color buttonColor;

          final type = data['type'];
          if (type == 'phone') {
            icon = Icons.chat_bubble_outline;
            title = 'Chat WhatsApp';
            subtitle = data['phone'] ?? '';
            buttonColor = const Color(0xFF25D366);
          } else if (type == 'sosmed') {
            final url = (data['url'] as String?) ?? '';
            if (url.contains('instagram')) {
              icon = Icons.camera_alt_outlined;
              title = 'Open Instagram';
            } else if (url.contains('tiktok')) {
              icon = Icons.music_note;
              title = 'Open TikTok';
            } else {
              icon = Icons.people_outline;
              title = 'Open Social Media';
            }
            subtitle = url;
            buttonColor = const Color(0xFFE1306C);
          } else {
            icon = Icons.link;
            title = 'Open Link';
            subtitle = data['url'] ?? '';
            buttonColor = const Color(0xFF2563EB);
          }

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: buttonColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: buttonColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    elevation: 0,
                  ),
                  onPressed: () => onActionPressed(result.intentUri, data),
                  child: const Icon(Icons.arrow_forward, size: 18),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
