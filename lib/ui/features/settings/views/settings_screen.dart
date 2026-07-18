import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import '../../../../data/services/preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  final PreferencesService preferencesService;
  final bool isRedirected;

  const SettingsScreen({
    Key? key,
    required this.preferencesService,
    this.isRedirected = false,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _dialCode;
  String? _countryName;

  @override
  void initState() {
    super.initState();
    _dialCode = widget.preferencesService.getCountryDialCode();
    _countryName = widget.preferencesService.getCountryName();

    if (_dialCode == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAutoDetectDialog();
      });
    }
  }

  void _showAutoDetectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Deteksi Negara'),
        content: const Text(
            'Apakah Anda ingin mendeteksi negara secara otomatis berdasarkan pengaturan HP Anda?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _selectCountryManually();
            },
            child: const Text('Pilih Manual'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _autoDetectCountry();
            },
            child: const Text('Ya, Deteksi'),
          ),
        ],
      ),
    );
  }

  void _autoDetectCountry() {
    final localCode = WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (localCode != null) {
      try {
        final country = CountryService().findByCode(localCode);
        if (country != null) {
          _saveCountry(country.phoneCode, country.name);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil mendeteksi negara: ${country.name} (+${country.phoneCode})'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } catch (e) {
        debugPrint('Error finding country by code: $e');
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gagal mendeteksi negara secara otomatis. Silakan pilih secara manual.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    _selectCountryManually();
  }

  void _selectCountryManually() {
    showCountryPicker(
      context: context,
      onSelect: (Country country) {
        _saveCountry(country.phoneCode, country.name);
      },
    );
  }

  void _saveCountry(String dialCode, String name) {
    widget.preferencesService.setCountryDialCode(dialCode);
    widget.preferencesService.setCountryName(name);
    setState(() {
      _dialCode = dialCode;
      _countryName = name;
    });
    if (widget.isRedirected) {
      Navigator.pop(context, true);
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
          // Section: Country Code Configuration
          _buildSectionHeader('WhatsApp Configuration'),
          _buildSettingsTile(
            icon: Icons.public,
            title: 'Country Code',
            subtitle: _dialCode != null 
                ? '$_countryName (+$_dialCode)' 
                : 'Not Configured (Tap to set)',
            onTap: _selectCountryManually,
          ),
          const SizedBox(height: 40),

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
