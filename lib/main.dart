import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const WomenSafetyApp());
}

// ============================================================
// APP ROOT
// ============================================================

class WomenSafetyApp extends StatelessWidget {
  const WomenSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Women Safety & Awareness',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F8FA),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ============================================================
// HOME SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _gettingLocation = false;
  Position? _currentPosition;

  // ----------------------------------------------------------
  // GET CURRENT GPS LOCATION
  // ----------------------------------------------------------

  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          _showMessage(
            'Location service बंद है। कृपया GPS चालू करें।',
            isError: true,
          );
        }
        return null;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          _showMessage(
            'Location permission की आवश्यकता है।',
            isError: true,
          );
        }
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showMessage(
            'Location permission permanently denied है। Settings से permission दें।',
            isError: true,
          );
        }
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentPosition = position;
      return position;
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Location प्राप्त नहीं हो सकी।',
          isError: true,
        );
      }
      return null;
    }
  }

  // ----------------------------------------------------------
  // SOS FLOW
  // ----------------------------------------------------------

  Future<void> _handleSOS() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Emergency SOS'),
            ],
          ),
          content: const Text(
            'क्या आप emergency action शुरू करना चाहते हैं?\n\n'
            'ऐप आपकी वर्तमान GPS location प्राप्त करके '
            '112 को कॉल करने और emergency SMS तैयार करने का प्रयास करेगा।',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SOS शुरू करें'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _gettingLocation = true;
    });

    final position = await _getLocation();

    setState(() {
      _gettingLocation = false;
    });

    if (position == null) return;

    final lat = position.latitude.toStringAsFixed(6);
    final lng = position.longitude.toStringAsFixed(6);

    final locationUrl =
        'https://maps.google.com/?q=$lat,$lng';

    final message =
        'EMERGENCY! मुझे सहायता की आवश्यकता है।\n'
        'मेरी वर्तमान location:\n'
        '$locationUrl';

    if (mounted) {
      await _showSOSResult(message);
    }
  }

  // ----------------------------------------------------------
  // SHOW SOS ACTIONS
  // ----------------------------------------------------------

  Future<void> _showSOSResult(String message) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Emergency Actions',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'आपकी location प्राप्त हो गई है। नीचे से आवश्यक action चुनें।',
                ),

                const SizedBox(height: 20),

                // CALL 112
                FilledButton.icon(
                  icon: const Icon(Icons.phone),
                  label: const Text('112 पर कॉल करें'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _callNumber('112');
                  },
                ),

                const SizedBox(height: 10),

                // SEND SMS
                OutlinedButton.icon(
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Emergency SMS तैयार करें'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _sendSMS(message);
                  },
                ),

                const SizedBox(height: 10),

                // SHARE LOCATION
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_location),
                  label: const Text('Location Share करें'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _shareLocation(message);
                  },
                ),

                const SizedBox(height: 8),

                Text(
                  'Location: ${_currentPosition?.latitude.toStringAsFixed(5)}, '
                  '${_currentPosition?.longitude.toStringAsFixed(5)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------
  // DIRECT PHONE CALL
  // ----------------------------------------------------------

  Future<void> _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage(
          'Phone app उपलब्ध नहीं है।',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage(
        'Call शुरू नहीं हो सकी।',
        isError: true,
      );
    }
  }

  // ----------------------------------------------------------
  // SMS
  // ----------------------------------------------------------

  Future<void> _sendSMS(String message) async {
    final encoded = Uri.encodeComponent(message);

    final uri = Uri.parse(
      'sms:?body=$encoded',
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showMessage(
          'SMS application उपलब्ध नहीं है।',
          isError: true,
        );
      }
    } catch (_) {
      _showMessage(
        'SMS application नहीं खुल सकी।',
        isError: true,
      );
    }
  }

  // ----------------------------------------------------------
  // SHARE LOCATION
  // ----------------------------------------------------------

  Future<void> _shareLocation(String message) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Emergency Location',
        ),
      );
    } catch (_) {
      _showMessage(
        'Location share नहीं हो सकी।',
        isError: true,
      );
    }
  }

  // ----------------------------------------------------------
  // LIVE LOCATION TRIGGER
  // ----------------------------------------------------------

  Future<void> _startLiveLocation() async {
    setState(() {
      _gettingLocation = true;
    });

    final position = await _getLocation();

    setState(() {
      _gettingLocation = false;
    });

    if (position == null) return;

    final mapUrl =
        'https://maps.google.com/?q='
        '${position.latitude},${position.longitude}';

    await SharePlus.instance.share(
      ShareParams(
        text:
            'मेरी वर्तमान location:\n$mapUrl\n\n'
            'यह location Women Safety & Awareness App से साझा की गई है।',
        subject: 'My Current Location',
      ),
    );
  }

  // ----------------------------------------------------------
  // SNACKBAR
  // ----------------------------------------------------------

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Women Safety',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Safety • Awareness • Empowerment',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Women Safety & Awareness',
                applicationVersion: '1.0.0',
                applicationLegalese:
                    'Safety awareness application.',
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEmergencyCard(),

              const SizedBox(height: 22),

              _buildSectionTitle(
                'Emergency Helplines',
                'जरूरत पड़ने पर तुरंत संपर्क करें',
              ),

              const SizedBox(height: 12),

              _buildHelplineList(),

              const SizedBox(height: 24),

              _buildSectionTitle(
                'Safety Tools',
                'अपनी safety information और location संभालकर रखें',
              ),

              const SizedBox(height: 12),

              _buildLocationCard(),

              const SizedBox(height: 28),

              _buildSectionTitle(
                'Awareness & Education',
                'अपने अधिकारों और safety के बारे में जानें',
              ),

              const SizedBox(height: 12),

              _buildAwarenessCards(),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // EMERGENCY CARD
  // ==========================================================

  Widget _buildEmergencyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        24,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE53935),
            Color(0xFFB71C1C),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.25),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Emergency Assistance',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // BIG SOS BUTTON
          GestureDetector(
            onTap: _gettingLocation ? null : _handleSOS,
            child: Container(
              width: 175,
              height: 175,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4),
                  width: 8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: _gettingLocation
                    ? const CircularProgressIndicator(
                        color: Colors.red,
                      )
                    : Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sos,
                            size: 58,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const Text(
                            'TAP FOR HELP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'Emergency में SOS दबाएं',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Location प्राप्त करके emergency actions उपलब्ध होंगे',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SECTION TITLE
  // ==========================================================

  Widget _buildSectionTitle(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // HELPLINES
  // ==========================================================

  Widget _buildHelplineList() {
    return Column(
      children: [
        _buildHelplineTile(
          number: '112',
          title: 'National Emergency Number',
          subtitle: 'Police / Fire / Medical Emergency',
          icon: Icons.emergency,
          color: Colors.red,
        ),

        const SizedBox(height: 10),

        _buildHelplineTile(
          number: '1091',
          title: 'Women Helpline',
          subtitle: 'Women-focused assistance',
          icon: Icons.woman,
          color: Colors.pink,
        ),

        const SizedBox(height: 10),

        _buildHelplineTile(
          number: '1098',
          title: 'Child Helpline',
          subtitle: 'Children in need of care and protection',
          icon: Icons.child_care,
          color: Colors.deepPurple,
        ),
      ],
    );
  }

  Widget _buildHelplineTile({
    required String number,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: color,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                tooltip: 'Call $number',
                onPressed: () => _callNumber(number),
                icon: Icon(
                  Icons.phone,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // LOCATION CARD
  // ==========================================================

  Widget _buildLocationCard() {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.blue,
                  ),
                ),

                const SizedBox(width: 14),

                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location Sharing',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'अपनी current location trusted person के साथ share करें।',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _gettingLocation
                        ? null
                        : _startLiveLocation,
                icon: _gettingLocation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.share_location,
                      ),
                label: Text(
                  _gettingLocation
                      ? 'Location प्राप्त हो रही है...'
                      : 'Share Current Location',
                ),
              ),
            ),

            if (_currentPosition != null) ...[
              const SizedBox(height: 12),
              Text(
                'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}   '
                'Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // AWARENESS CARDS
  // ==========================================================

  Widget _buildAwarenessCards() {
    final articles = [
      AwarenessArticle(
        title: 'Consent',
        subtitle: 'सहमति को समझें',
        icon: Icons.handshake_outlined,
        color: Colors.purple,
        content: '''
Consent यानी सहमति किसी भी व्यक्ति की स्पष्ट और स्वैच्छिक अनुमति है।

महत्वपूर्ण बातें:

• Consent स्पष्ट और voluntary होना चाहिए।
• दबाव, डर या मजबूरी में दी गई अनुमति genuine consent नहीं हो सकती।
• किसी भी समय अपनी सहमति वापस ली जा सकती है।
• Silence को अपने आप consent नहीं माना जाना चाहिए।
• हर व्यक्ति की boundaries का सम्मान करना जरूरी है।

Respect का मतलब है दूसरे व्यक्ति की इच्छा और boundaries को समझना और उनका सम्मान करना।
''',
      ),

      AwarenessArticle(
        title: 'Equality',
        subtitle: 'समानता और सम्मान',
        icon: Icons.balance,
        color: Colors.indigo,
        content: '''
Equality का अर्थ है सभी लोगों को समान सम्मान, अवसर और अधिकार मिलना।

एक सुरक्षित समाज में:

• Gender के आधार पर भेदभाव नहीं होना चाहिए।
• शिक्षा और career के अवसरों में समानता होनी चाहिए।
• हर व्यक्ति को अपनी बात रखने का अधिकार होना चाहिए।
• घरेलू और professional environments में respectful behaviour जरूरी है।
• किसी व्यक्ति की पहचान या background के आधार पर उसे कमतर नहीं समझना चाहिए।
''',
      ),

      AwarenessArticle(
        title: 'Legal Rights',
        subtitle: 'BNS और POCSO की जानकारी',
        icon: Icons.gavel_outlined,
        color: Colors.deepOrange,
        content: '''
भारत में criminal law और child protection से जुड़े कई कानून हैं।

BNS:
Bharatiya Nyaya Sanhita, 2023 ने कई पुराने IPC provisions को replace किया और criminal offences तथा penalties से संबंधित framework प्रदान करता है।

POCSO:
Protection of Children from Sexual Offences Act, 2012 बच्चों को sexual offences से protection देने के लिए बनाया गया कानून है।

ध्यान रखें:
• कानूनी स्थिति case के facts पर निर्भर करती है।
• गंभीर मामले में qualified lawyer, police या appropriate authority से सहायता लेना चाहिए।
• किसी emergency में 112 से संपर्क किया जा सकता है।
• बच्चों से जुड़े protection concerns में 1098 उपयोगी emergency helpline है।

यह section केवल educational information है, legal advice नहीं।
''',
      ),

      AwarenessArticle(
        title: 'Respectful Parenting',
        subtitle: 'बच्चों के साथ सम्मानजनक व्यवहार',
        icon: Icons.family_restroom,
        color: Colors.teal,
        content: '''
Respectful parenting का उद्देश्य बच्चे को डराने के बजाय समझने और guide करने पर जोर देना है।

कुछ principles:

• बच्चे की बात ध्यान से सुनें।
• उसकी personal boundaries का सम्मान करें।
• गलती पर समझाएं और constructive guidance दें।
• डर, humiliation और unnecessary punishment से बचें।
• बच्चे को age-appropriate तरीके से safety और consent के बारे में बताएं।
• ऐसा environment बनाएं जिसमें बच्चा किसी समस्या के बारे में खुलकर बता सके।
''',
      ),
    ];

    return Column(
      children: articles.map((article) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildAwarenessCard(article),
        );
      }).toList(),
    );
  }

  Widget _buildAwarenessCard(
    AwarenessArticle article,
  ) {
    return Card(
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ArticleScreen(
                article: article,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: article.color.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  article.icon,
                  color: article.color,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ARTICLE MODEL
// ============================================================

class AwarenessArticle {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String content;

  AwarenessArticle({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.content,
  });
}

// ============================================================
// ARTICLE SCREEN
// ============================================================

class ArticleScreen extends StatelessWidget {
  final AwarenessArticle article;

  const ArticleScreen({
    super.key,
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(article.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: article.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  Icon(
                    article.icon,
                    size: 55,
                    color: article.color,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: article.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              article.content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.65,
              ),
            ),

            const SizedBox(height: 30),

            if (article.title == 'Legal Rights')
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'कानून समय के साथ बदल सकते हैं। किसी specific legal case के लिए वर्तमान कानून और qualified legal professional की सलाह देखें।',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
