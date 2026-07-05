// Feature: Deteksi kontak dari foto rumah
//   Scenario: Mendeteksi nomor HP dan membuka WhatsApp
//     Given teks pada foto adalah "Hubungi 0812-3456-7890"
//     When aplikasi melakukan OCR
//     Then nomor HP terdeteksi sebagai "081234567890"
//     And format WhatsApp menjadi "6281234567890"
//
//   Scenario: Mendeteksi link Instagram
//     Given teks mengandung "https://instagram.com/rumah123"
//     When aplikasi mendeteksi link
//     Then tombol "Buka Instagram" muncul
//     And membuka aplikasi Instagram dengan intent "instagram://user?username=rumah123"

import 'package:flutter_test/flutter_test.dart';
import 'package:open_photo_link/parser.dart';

void main() {
  group('LinkParser Unit Tests (BDD)', () {
    
    // Scenario 1: Nomor HP biasa: 081234567890 → terdeteksi, format WhatsApp benar.
    test('Scenario 1: Mendeteksi nomor HP biasa dan memformat untuk WhatsApp', () {
      // Given
      const text = 'Hubungi kami di 081234567890';
      
      // When
      final phone = LinkParser.extractPhoneNumber(text);
      final formatted = phone != null ? LinkParser.formatPhoneForWhatsApp(phone) : null;
      
      // Then
      expect(phone, equals('081234567890'));
      expect(formatted, equals('6281234567890'));
    });

    // Scenario 2: Nomor HP dengan +62: +6281234567890 → format menjadi 6281234567890.
    test('Scenario 2: Mendeteksi nomor HP dengan +62 dan memformat menjadi 6281234567890', () {
      // Given
      const text = 'Kontak sales: +6281234567890';
      
      // When
      final phone = LinkParser.extractPhoneNumber(text);
      final formatted = phone != null ? LinkParser.formatPhoneForWhatsApp(phone) : null;
      
      // Then
      expect(phone, equals('+6281234567890'));
      expect(formatted, equals('6281234567890'));
    });

    // Scenario 3: Nomor HP dengan pemisah: 0812-3456-7890 → bersihkan, format benar.
    test('Scenario 3: Mendeteksi nomor HP dengan pemisah dan memformat dengan benar', () {
      // Given
      const text = 'Hotline: 0812-3456-7890';
      
      // When
      final phone = LinkParser.extractPhoneNumber(text);
      final formatted = phone != null ? LinkParser.formatPhoneForWhatsApp(phone) : null;
      
      // Then
      expect(phone, equals('081234567890'));
      expect(formatted, equals('6281234567890'));
    });

    // Scenario 4: Teks tanpa nomor → null.
    test('Scenario 4: Teks tanpa nomor HP mengembalikan null', () {
      // Given
      const text = 'Hanya ada teks biasa di sini tanpa nomor telepon.';
      
      // When
      final phone = LinkParser.extractPhoneNumber(text);
      
      // Then
      expect(phone, isNull);
    });

    // Scenario 5: Link Instagram: "https://instagram.com/p/abc" → terdeteksi sebagai sosmed Instagram, intent Instagram.
    test('Scenario 5: Mendeteksi link Instagram dan menentukan intent Instagram', () {
      // Given
      const text = 'Follow kami di https://instagram.com/rumah123';
      
      // When
      final sosmed = LinkParser.extractSocialMediaLink(text);
      final intent = sosmed != null ? LinkParser.determineIntent({'type': 'sosmed', 'url': sosmed}) : null;
      
      // Then
      expect(sosmed, equals('https://instagram.com/rumah123'));
      expect(intent, equals('instagram://user?username=rumah123'));
    });

    // Scenario 6: Link TikTok: "https://tiktok.com/@user/video/123" → terdeteksi TikTok.
    test('Scenario 6: Mendeteksi link TikTok', () {
      // Given
      const text = 'Tonton video di https://tiktok.com/@user/video/123';
      
      // When
      final sosmed = LinkParser.extractSocialMediaLink(text);
      final intent = sosmed != null ? LinkParser.determineIntent({'type': 'sosmed', 'url': sosmed}) : null;
      
      // Then
      expect(sosmed, equals('https://tiktok.com/@user/video/123'));
      expect(intent, equals('https://tiktok.com/@user/video/123'));
    });

    // Scenario 7: Link campur teks: "Hubungi kami di 081234567890 atau DM instagram.com/rumahidaman" → ambil nomor HP atau link pertama, test kedua fungsi.
    test('Scenario 7: Mendeteksi nomor HP dan link sosial media sekaligus dari teks campuran', () {
      // Given
      const text = 'Hubungi kami di 081234567890 atau DM instagram.com/rumahidaman';
      
      // When
      final phone = LinkParser.extractPhoneNumber(text);
      final sosmed = LinkParser.extractSocialMediaLink(text);
      
      // Then
      expect(phone, equals('081234567890'));
      expect(sosmed, equals('instagram.com/rumahidaman'));
    });

    // Scenario 8: QR code berisi URL → processQRCode menghasilkan type link.
    test('Scenario 8: QR Code berisi URL menghasilkan type link', () {
      // Given
      const qrData = 'https://google.com';
      
      // When
      final result = LinkParser.processQRCode(qrData);
      
      // Then
      expect(result, isNotNull);
      expect(result!['type'], equals('link'));
      expect(result['url'], equals('https://google.com'));
    });

    // Scenario 9: QR code berisi nomor HP → processQRCode menghasilkan type phone.
    test('Scenario 9: QR Code berisi nomor HP menghasilkan type phone', () {
      // Given
      const qrData = '081234567890';
      
      // When
      final result = LinkParser.processQRCode(qrData);
      
      // Then
      expect(result, isNotNull);
      expect(result!['type'], equals('phone'));
      expect(result['phone'], equals('081234567890'));
    });

    // Scenario 10: determineIntent memberikan URI yang benar untuk setiap tipe.
    test('Scenario 10: Menentukan intent URI yang benar untuk masing-masing tipe', () {
      // Given
      final phoneData = {'type': 'phone', 'phone': '081234567890'};
      final sosmedData = {'type': 'sosmed', 'url': 'https://instagram.com/rumah123'};
      final linkData = {'type': 'link', 'url': 'https://google.com'};
      
      // When
      final phoneIntent = LinkParser.determineIntent(phoneData);
      final sosmedIntent = LinkParser.determineIntent(sosmedData);
      final linkIntent = LinkParser.determineIntent(linkData);
      
      // Then
      expect(phoneIntent, equals('whatsapp://send?phone=6281234567890'));
      expect(sosmedIntent, equals('instagram://user?username=rumah123'));
      expect(linkIntent, equals('https://google.com'));
    });
  });
}

// How to run:
// flutter test test/parser_test.dart
