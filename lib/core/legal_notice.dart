import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';

/// "بالتسجيل أنت توافق على الشروط وسياسة الخصوصية" مع روابط.
class LegalNotice extends StatelessWidget {
  const LegalNotice({super.key});

  static void _open(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    const linkStyle = TextStyle(
      color: Color(0xFF20E0C0),
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      TextSpan(
        style: const TextStyle(color: Colors.white54, fontSize: 12.5),
        children: [
          const TextSpan(text: 'بالتسجيل أنت توافق على '),
          TextSpan(
            text: 'الشروط والأحكام',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _open(AppConfig.termsUrl),
          ),
          const TextSpan(text: ' و'),
          TextSpan(
            text: 'سياسة الخصوصية',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => _open(AppConfig.privacyPolicyUrl),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
