import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  Future<bool> canLaunch(Uri url) async {
    return await canLaunchUrl(url);
  }

  Future<bool> launch(Uri url, {LaunchMode mode = LaunchMode.externalApplication}) async {
    return await launchUrl(url, mode: mode);
  }
}
