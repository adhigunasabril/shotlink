import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  Future<void> _launchUrl(String urlString, BuildContext context) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        children: [
          // Section: General Info
          _buildSectionHeader('General'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About Shotlink',
            subtitle: 'Learn more about this app',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Shotlink',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(
                  Icons.camera_alt,
                  color: Color(0xFF2563EB),
                  size: 40,
                ),
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Shotlink is an application that allows you to point your camera or upload images containing text, phone numbers, or QR codes and launch intents instantly.',
                  ),
                ],
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.gavel_outlined,
            title: 'Licenses',
            subtitle: 'View open source licenses',
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'Shotlink',
                applicationVersion: '1.0.0',
              );
            },
          ),
          const SizedBox(height: 20),

          // Section: Support & Socials
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Need Help?',
            subtitle: 'Contact support team',
            onTap: () => _launchUrl('https://wa.me/6281234567890', context),
          ),
          _buildSettingsTile(
            icon: Icons.star_border_rounded,
            title: 'Rate Us',
            subtitle: 'Share your feedback on Play Store / App Store',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
          ),
          const SizedBox(height: 30),

          // Footer version
          Center(
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
