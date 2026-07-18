import 'dart:core';

/// Helper class to parse and extract links, phone numbers, and social media URLs.
class LinkParser {
  /// **Scenario: Mendeteksi nomor HP Indonesia**
  /// **Given** a string containing an Indonesian phone number (e.g. 0812-3456-7890 or +6281234567890)
  /// **When** [extractPhoneNumber] is called
  /// **Then** it returns the cleaned phone number (digits and '+' only) or null if not found.
  static String? extractPhoneNumber(String text, {String countryDialCode = '62'}) {
    // Matches 08xx, +628xx, or 628xx with optional dashes or spaces for ID,
    // or a general pattern for other countries using their dial code.
    final regExp = countryDialCode == '62'
        ? RegExp(r'(?:\+?62|0)8[1-9][0-9\-\s]{7,12}[0-9]')
        : RegExp('(?:\\+?$countryDialCode|0)[0-9\\-\\s]{6,14}[0-9]');
    final match = regExp.firstMatch(text);
    if (match != null) {
      final matchedText = match.group(0)!;
      // Clean up spaces and dashes, keeping digits and +
      final cleaned = matchedText.replaceAll(RegExp(r'[\-\s]'), '');
      if (cleaned.length >= 7 && cleaned.length <= 15) {
        return cleaned;
      }
    }
    return null;
  }

  /// **Scenario: Memformat nomor HP ke format WhatsApp**
  /// **Given** a cleaned phone number (e.g. 081234567890 or +6281234567890)
  /// **When** [formatPhoneForWhatsApp] is called
  /// **Then** it returns the phone number in '[countryDialCode]xxxxxxxxxx' format.
  static String formatPhoneForWhatsApp(String phone, String countryDialCode) {
    String cleaned = phone.replaceAll(RegExp(r'[\-\s]'), '');
    if (cleaned.startsWith('+$countryDialCode')) {
      cleaned = cleaned.substring(countryDialCode.length + 1);
    } else if (cleaned.startsWith(countryDialCode)) {
      cleaned = cleaned.substring(countryDialCode.length);
    } else if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return '$countryDialCode$cleaned';
  }

  /// **Scenario: Mendeteksi link sosial media**
  /// **Given** a string containing a social media link (Instagram, TikTok, Twitter/X, Facebook)
  /// **When** [extractSocialMediaLink] is called
  /// **Then** it returns the first matched complete URL, or null if not found.
  static String? extractSocialMediaLink(String text) {
    final regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:instagram\.com|tiktok\.com|vm\.tiktok\.com|twitter\.com|x\.com|facebook\.com)\/[a-zA-Z0-9_@\-\.\/\?%&=]+',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(text);
    return match?.group(0);
  }

  /// **Scenario: Mendeteksi link generik**
  /// **Given** a string containing a generic HTTP/HTTPS link
  /// **When** [extractAnyLink] is called
  /// **Then** it returns the first generic link that is not a social media link, or null.
  static String? extractAnyLink(String text) {
    final regExp = RegExp(
      r'https?:\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,}(?:\/[a-zA-Z0-9_@\-\.\/\?%&=#]*)?',
      caseSensitive: false,
    );
    final matches = regExp.allMatches(text);
    for (final match in matches) {
      final url = match.group(0)!;
      if (extractSocialMediaLink(url) == null) {
        return url;
      }
    }
    return null;
  }

  /// **Scenario: Memproses QR Code**
  /// **Given** raw QR code data
  /// **When** [processQRCode] is called
  /// **Then** it returns a Map containing type 'link' or 'phone', or null if neither matches.
  static Map<String, dynamic>? processQRCode(String qrData, {String countryDialCode = '62'}) {
    final trimmed = qrData.trim();
    if (trimmed.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      return {"type": "link", "url": trimmed};
    }
    final sosmed = extractSocialMediaLink(trimmed) ?? extractSocialMediaLink('https://$trimmed');
    if (sosmed != null) {
      return {"type": "sosmed", "url": sosmed};
    }
    final link = extractAnyLink(trimmed) ?? extractAnyLink('https://$trimmed');
    if (link != null) {
      return {"type": "link", "url": link};
    }
    final phone = extractPhoneNumber(trimmed, countryDialCode: countryDialCode);
    if (phone != null) {
      return {"type": "phone", "phone": phone};
    }
    return null;
  }

  /// **Scenario: Membuat URL WhatsApp**
  /// **Given** a phone number
  /// **When** [buildWhatsAppUrl] is called
  /// **Then** it returns the wa.me link with formatted phone number.
  static String buildWhatsAppUrl(String phone, String countryDialCode) {
    return 'https://wa.me/${formatPhoneForWhatsApp(phone, countryDialCode)}';
  }

  /// **Scenario: Menentukan Intent URI**
  /// **Given** a parsed map from detection methods
  /// **When** [determineIntent] is called
  /// **Then** it returns a schema URI ready for launch.
  static String? determineIntent(Map<String, dynamic> parsed, {String countryDialCode = '62'}) {
    final type = parsed['type'];
    if (type == 'phone') {
      final phone = parsed['phone'] as String;
      return 'whatsapp://send?phone=${formatPhoneForWhatsApp(phone, countryDialCode)}';
    } else if (type == 'sosmed') {
      final url = parsed['url'] as String;
      if (url.toLowerCase().contains('instagram.com')) {
        // Try to extract username
        final uri = Uri.tryParse(url.startsWith(RegExp(r'https?://', caseSensitive: false)) ? url : 'https://$url');
        if (uri != null && uri.pathSegments.isNotEmpty) {
          final username = uri.pathSegments.first;
          if (username.isNotEmpty && username != 'p' && username != 'reels') {
            return 'instagram://user?username=$username';
          }
        }
        return url.startsWith(RegExp(r'https?://', caseSensitive: false)) ? url : 'https://$url';
      }
      return url.startsWith(RegExp(r'https?://', caseSensitive: false)) ? url : 'https://$url';
    } else if (type == 'link') {
      return parsed['url'] as String;
    }
    return null;
  }
}
