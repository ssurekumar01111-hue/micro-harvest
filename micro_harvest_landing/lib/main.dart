import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MicroHarvestApp());
}

class MicroHarvestApp extends StatelessWidget {
  const MicroHarvestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Micro-Harvest',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A6B3C),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0D1F0F),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
      ),
      home: const LandingPage(),
    );
  }
}

// ─── COLORS ───────────────────────────────────────────────
const kBg         = Color(0xFF0D1F0F);
const kBgCard     = Color(0xFF122718);
const kGreen      = Color(0xFF2ECC71);
const kGreenDark  = Color(0xFF1A6B3C);
const kGold       = Color(0xFFE8B84B);
const kText       = Color(0xFFF0F0E8);
const kMuted      = Color(0xFF7A9E7E);
const kBorder     = Color(0xFF1E4028);

// ─── APK LINKS ────────────────────────────────────────────
const kApkGrower      = 'https://github.com/ssurekumar01111-hue/micro-harvest/releases/download/v1.0.0/grower-release.apk';
const kApkProducer    = 'https://github.com/ssurekumar01111-hue/micro-harvest/releases/download/v1.0.0/producer-release.apk';
const kApkTransporter = 'https://github.com/ssurekumar01111-hue/micro-harvest/releases/download/v1.0.0/transporter-release.apk';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();

  void _scrollTo(double offset) {
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            _NavBar(isMobile: isMobile, onScrollTo: _scrollTo),
            _HeroSection(isMobile: isMobile),
            _ProblemSection(isMobile: isMobile),
            _HowItWorksSection(isMobile: isMobile),
            _AppsSection(isMobile: isMobile),
            _DownloadSection(isMobile: isMobile),
            _TechStackSection(isMobile: isMobile),
            _OfflineSection(isMobile: isMobile),
            _StatsSection(isMobile: isMobile),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

// ─── NAVBAR ───────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  final bool isMobile;
  final void Function(double) onScrollTo;
  const _NavBar({required this.isMobile, required this.onScrollTo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: kBg.withOpacity(0.95),
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.grass, color: Colors.black, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'MICRO-HARVEST',
                style: GoogleFonts.spaceMono(
                  color: kText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!isMobile) ...[
            _NavLink('Features', () => onScrollTo(700)),
            _NavLink('How it works', () => onScrollTo(1300)),
            _NavLink('Tech Stack', () => onScrollTo(2200)),
            const SizedBox(width: 16),
          ],
          OutlinedButton(
            onPressed: () => launchUrl(Uri.parse('https://github.com/ssurekumar01111-hue/micro-harvest')),
            style: OutlinedButton.styleFrom(
              foregroundColor: kGreen,
              side: BorderSide(color: kGreen),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('GitHub', style: GoogleFonts.spaceMono(fontSize: 13)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms);
  }
}

class _NavLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: kMuted, fontSize: 14)),
    );
  }
}

// ─── HERO ─────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final bool isMobile;
  const _HeroSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 64 : 100,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kBg, const Color(0xFF0F2A14)],
        ),
      ),
      child: Column(
        children: [
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: kGreenDark.withOpacity(0.3),
              border: Border.all(color: kGreen.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  'Google Cloud Rapid Agent Hackathon 2026',
                  style: TextStyle(color: kGreen, fontSize: 12, letterSpacing: 0.5),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),

          const SizedBox(height: 32),

          // Headline
          Text(
            'AI-Powered Agricultural\nLogistics for Indian Farmers',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(
              color: kText,
              fontSize: isMobile ? 36 : 60,
              height: 1.15,
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

          const SizedBox(height: 24),

          // Sub
          Text(
            'One conversation. Three apps. Instant payment.\nBuilt for 100 Million Indian farmers.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: isMobile ? 16 : 20, height: 1.7),
          ).animate().fadeIn(delay: 600.ms),

          const SizedBox(height: 48),

          // CTAs
          Wrap(
            spacing: 16, runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => launchUrl(Uri.parse('https://github.com/ssurekumar01111-hue/micro-harvest')),
                icon: const Icon(Icons.code, size: 18),
                label: const Text('View on GitHub'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('https://micro-harvest.web.app')),
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text('Admin Panel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kText,
                  side: BorderSide(color: kBorder.withOpacity(0.8)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  textStyle: const TextStyle(fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ).animate().fadeIn(delay: 800.ms),

          const SizedBox(height: 72),

          // Tech pills
          Wrap(
            spacing: 10, runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              'Google Agent Platform', 'Elastic MCP', 'Firebase',
              'Gemini 3.1 Flash', 'Stripe Settlement', 'Geo-Intelligence',
            ].map((t) => _TechPill(t)).toList(),
          ).animate().fadeIn(delay: 1000.ms),
        ],
      ),
    );
  }
}

class _TechPill extends StatelessWidget {
  final String label;
  const _TechPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(label, style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 0.3)),
    );
  }
}

// ─── PROBLEM ──────────────────────────────────────────────
class _ProblemSection extends StatelessWidget {
  final bool isMobile;
  const _ProblemSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 80),
      color: const Color(0xFF0A1A0C),
      child: Column(
        children: [
          _SectionLabel('THE PROBLEM'),
          const SizedBox(height: 20),
          Text(
            '16% of Indian produce is lost annually\nto supply chain failures',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(
              color: kText,
              fontSize: isMobile ? 28 : 42,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Farmers lack access to real-time logistics, buyers can\'t find surplus crops,\nand drivers have no coordination layer. Micro-Harvest fixes all three.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 16, height: 1.8),
          ),
          const SizedBox(height: 56),
          Wrap(
            spacing: 20, runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _StatCard('₹92,000 Cr', 'lost annually to\nproduce wastage'),
              _StatCard('58%', 'farmers have no\ndigital market access'),
              _StatCard('3–5 days', 'average delay in\nlogistics coordination'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.spaceMono(
            color: kGold, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 13, height: 1.6)),
        ],
      ),
    );
  }
}

// ─── HOW IT WORKS ─────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  final bool isMobile;
  const _HowItWorksSection({required this.isMobile});

  static const steps = [
    ('🌾', 'Farmer chats with\nHarvest Agent', 'Speaks naturally — crop type, quantity, price. AI parses intent and creates a verified listing.'),
    ('🔍', 'Buyer discovers\nwith Smart Search', 'Elastic MCP-powered search matches buyers to nearby surplus with geo-intelligence routing.'),
    ('🚚', 'Driver gets\nauto-assigned', 'Google Agent Platform dispatches the nearest available driver with route and payment details.'),
    ('💳', 'Instant payment\nsettlement', 'Stripe processes payment on delivery confirmation. Farmer receives funds same day.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 80),
      child: Column(
        children: [
          _SectionLabel('HOW IT WORKS'),
          const SizedBox(height: 20),
          Text('One conversation powers the entire chain',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(
              color: kText, fontSize: isMobile ? 28 : 40)),
          const SizedBox(height: 56),
          isMobile
            ? Column(children: steps.indexed.map((e) =>
                Padding(padding: const EdgeInsets.only(bottom: 16),
                  child: _StepCard(e.$1 + 1, e.$2.$1, e.$2.$2, e.$2.$3))).toList())
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: steps.indexed.map((e) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _StepCard(e.$1 + 1, e.$2.$1, e.$2.$2, e.$2.$3),
                  ),
                )).toList(),
              ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int step;
  final String emoji;
  final String title;
  final String desc;
  const _StepCard(this.step, this.emoji, this.title, this.desc);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: kGreenDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text('$step',
                style: GoogleFonts.spaceMono(color: kGreen, fontSize: 12, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 10),
            Text(emoji, style: const TextStyle(fontSize: 20)),
          ]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: kText, fontSize: 16,
            fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 10),
          Text(desc, style: TextStyle(color: kMuted, fontSize: 13, height: 1.7)),
        ],
      ),
    ).animate().fadeIn(delay: (step * 150).ms).slideY(begin: 0.2);
  }
}

// ─── APPS ─────────────────────────────────────────────────
class _AppsSection extends StatelessWidget {
  final bool isMobile;
  const _AppsSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 80),
      color: const Color(0xFF0A1A0C),
      child: Column(
        children: [
          _SectionLabel('THREE APPS. ONE PLATFORM'),
          const SizedBox(height: 20),
          Text('Built for every player in the chain',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(color: kText, fontSize: isMobile ? 28 : 40)),
          const SizedBox(height: 48),
          Wrap(
            spacing: 20, runSpacing: 20,
            alignment: WrapAlignment.center,
            children: const [
              _AppCard(
                icon: Icons.agriculture,
                title: 'Farmer App',
                subtitle: 'Grower',
                color: kGreen,
                apkUrl: kApkGrower,
                features: ['AI Harvest Agent chat', 'Offline listing creation', 'Real-time listing status', 'Earnings dashboard'],
              ),
              _AppCard(
                icon: Icons.local_shipping_outlined,
                title: 'Driver App',
                subtitle: 'Transporter',
                color: kGold,
                apkUrl: kApkTransporter,
                features: ['Auto haul assignment', 'GPS route guidance', 'Gate capture handover', 'Instant pay on delivery'],
              ),
              _AppCard(
                icon: Icons.storefront_outlined,
                title: 'Buyer App',
                subtitle: 'Producer',
                color: Color(0xFF64B5F6),
                apkUrl: kApkProducer,
                features: ['Smart surplus search', 'Geo-filtered listings', 'Claim & reserve crops', 'Transport tracking'],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> features;
  final String apkUrl;
  const _AppCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.features, required this.apkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: color, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 20),
          Divider(color: kBorder),
          const SizedBox(height: 16),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Icon(Icons.check_circle_outline, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Text(f, style: TextStyle(color: kMuted, fontSize: 13))),
            ]),
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(apkUrl),
                mode: LaunchMode.externalApplication),
              icon: Icon(Icons.download_outlined, size: 16, color: color),
              label: Text('Download APK', style: TextStyle(color: color, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OFFLINE FEATURE ──────────────────────────────────────
class _OfflineSection extends StatelessWidget {
  final bool isMobile;
  const _OfflineSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 80),
      child: isMobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: _content(isMobile))
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _content(isMobile))),
              const SizedBox(width: 64),
              Expanded(child: _OfflineVisual()),
            ],
          ),
    );
  }

  List<Widget> _content(bool isMobile) => [
    _SectionLabel('OFFLINE FIRST'),
    const SizedBox(height: 20),
    Text('Works without internet.\nLists when reconnected.',
      style: GoogleFonts.dmSerifDisplay(color: kText, fontSize: isMobile ? 28 : 38, height: 1.25)),
    const SizedBox(height: 20),
    Text(
      'Indian farmers often operate in areas with poor connectivity. Micro-Harvest\'s Harvest Agent saves messages and listings locally, then syncs and goes live the moment internet returns.',
      style: TextStyle(color: kMuted, fontSize: 15, height: 1.8),
    ),
    const SizedBox(height: 32),
    ...[
      ('Offline badge detection', 'App detects connectivity loss instantly'),
      ('Local message queue', 'Conversations saved to device storage'),
      ('Auto-sync on reconnect', 'Listing goes live without user action'),
    ].map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.$1, style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(e.$2, style: TextStyle(color: kMuted, fontSize: 13)),
        ])),
      ]),
    )),
    if (isMobile) ...[const SizedBox(height: 40), _OfflineVisual()],
  ];
}

class _OfflineVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _ChatBubble('I have 20 macro bins of Merlot ready to go today asking 4000 per ton', isUser: true),
          const SizedBox(height: 12),
          _OfflineBadge(),
          const SizedBox(height: 12),
          _ChatBubble('You\'re offline. Your message has been saved and will be processed when you reconnect.', isUser: false),
          const SizedBox(height: 20),
          _OnlineBadge(),
          const SizedBox(height: 12),
          _ChatBubble('✅ Your offline listing is now live!', isUser: false, isSuccess: true),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isSuccess;
  const _ChatBubble(this.text, {required this.isUser, this.isSuccess = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSuccess
            ? kGreen.withOpacity(0.15)
            : isUser
              ? kGreenDark
              : const Color(0xFF1A3022),
          border: isSuccess ? Border.all(color: kGreen.withOpacity(0.4)) : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
          style: TextStyle(
            color: isSuccess ? kGreen : kText,
            fontSize: 13, height: 1.5)),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.15),
          border: Border.all(color: Colors.orange.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off, color: Colors.orange, size: 13),
          const SizedBox(width: 6),
          Text('Offline', style: TextStyle(color: Colors.orange, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: kGreen.withOpacity(0.15),
          border: Border.all(color: kGreen.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi, color: kGreen, size: 13),
          const SizedBox(width: 6),
          Text('Back online — syncing...', style: TextStyle(color: kGreen, fontSize: 11)),
        ]),
      ),
    );
  }
}

// ─── TECH STACK ───────────────────────────────────────────
class _TechStackSection extends StatelessWidget {
  final bool isMobile;
  const _TechStackSection({required this.isMobile});

  static const techs = [
    (Icons.cloud_outlined,        'Google Agent Platform', 'Orchestrates multi-tool AI agents with Gemini 3.1 Flash'),
    (Icons.search,                'Elastic MCP',           '24 tools for semantic crop search and geo-intelligence'),
    (Icons.local_fire_department, 'Firebase',              'Firestore, Auth, Hosting, Cloud Functions — fully serverless'),
    (Icons.flash_on_outlined,     'Gemini 3.1 Flash',      'Fast reasoning for harvest intelligence and logistics'),
    (Icons.payment_outlined,      'Stripe',                'Instant farmer payment settlement on delivery'),
    (Icons.location_on_outlined,  'Geo-Intelligence',      'Radius-based matching and real-time driver routing'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 80),
      color: const Color(0xFF0A1A0C),
      child: Column(
        children: [
          _SectionLabel('TECH STACK'),
          const SizedBox(height: 20),
          Text('Built on Google Cloud',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(color: kText, fontSize: isMobile ? 28 : 40)),
          const SizedBox(height: 48),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 4 : 2.2,
            ),
            itemCount: techs.length,
            itemBuilder: (_, i) {
              final t = techs[i];
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kBgCard,
                  border: Border.all(color: kBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: kGreenDark.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(t.$1, color: kGreen, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(t.$2, style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(t.$3, style: TextStyle(color: kMuted, fontSize: 11, height: 1.4)),
                    ],
                  )),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── STATS ────────────────────────────────────────────────
class _StatsSection extends StatelessWidget {
  final bool isMobile;
  const _StatsSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 80),
      child: Column(
        children: [
          _SectionLabel('IMPACT'),
          const SizedBox(height: 20),
          Text('Built for scale',
            style: GoogleFonts.dmSerifDisplay(color: kText, fontSize: isMobile ? 28 : 40)),
          const SizedBox(height: 48),
          Wrap(
            spacing: 20, runSpacing: 20,
            alignment: WrapAlignment.center,
            children: const [
              _ImpactCard('100M+', 'Indian farmers\ntarget market'),
              _ImpactCard('3 apps', 'Farmer · Driver\n· Buyer'),
              _ImpactCard('24 tools', 'Elastic MCP\nintegrations'),
              _ImpactCard('< 30s', 'Listing creation\nend-to-end'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final String value;
  final String label;
  const _ImpactCard(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        Text(value, style: GoogleFonts.spaceMono(
          color: kGreen, fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: kMuted, fontSize: 12, height: 1.6)),
      ]),
    );
  }
}

// ─── FOOTER ───────────────────────────────────────────────
class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0C),
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('MICRO-HARVEST', style: GoogleFonts.spaceMono(
              color: kMuted, fontSize: 13, letterSpacing: 2)),
            Text('Google Cloud Rapid Agent Hackathon 2026',
              style: TextStyle(color: kMuted, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'github.com/ssurekumar01111-hue/micro-harvest  ·  One conversation. Three apps. Instant payment.',
          style: TextStyle(color: kBorder.withOpacity(2), fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ─── DOWNLOAD SECTION ─────────────────────────────────────
class _DownloadSection extends StatelessWidget {
  final bool isMobile;
  const _DownloadSection({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80, vertical: 80),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A0C),
        border: Border(
          top: BorderSide(color: kBorder),
          bottom: BorderSide(color: kBorder),
        ),
      ),
      child: Column(
        children: [
          _SectionLabel('TRY IT NOW'),
          const SizedBox(height: 20),
          Text(
            'Download & experience the full flow',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSerifDisplay(
              color: kText, fontSize: isMobile ? 28 : 40),
          ),
          const SizedBox(height: 12),
          Text(
            'Install all three apps on Android to walk through the complete\nfarmer → driver → buyer journey end-to-end.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 15, height: 1.8),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: kGold.withOpacity(0.1),
              border: Border.all(color: kGold.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.info_outline, color: kGold, size: 14),
              const SizedBox(width: 8),
              Text(
                'Enable "Install from unknown sources" in Android settings before installing',
                style: TextStyle(color: kGold, fontSize: 12),
              ),
            ]),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 20, runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              _DownloadCard(
                icon: Icons.agriculture,
                title: 'Farmer App',
                subtitle: 'grower-release.apk',
                description: 'Create listings, chat with AI Harvest Agent, track earnings and listing status.',
                color: kGreen,
                apkUrl: kApkGrower,
                step: '01',
              ),
              _DownloadCard(
                icon: Icons.storefront_outlined,
                title: 'Buyer App',
                subtitle: 'producer-release.apk',
                description: 'Search surplus crops by location, claim listings and track transport.',
                color: const Color(0xFF64B5F6),
                apkUrl: kApkProducer,
                step: '02',
              ),
              _DownloadCard(
                icon: Icons.local_shipping_outlined,
                title: 'Driver App',
                subtitle: 'transporter-release.apk',
                description: 'Accept hauls, navigate to farms, capture gate handover and confirm delivery.',
                color: kGold,
                apkUrl: kApkTransporter,
                step: '03',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final String apkUrl;
  final String step;
  const _DownloadCard({
    required this.icon, required this.title, required this.subtitle,
    required this.description, required this.color,
    required this.apkUrl, required this.step,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: kBgCard,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(step, style: GoogleFonts.spaceMono(
              color: kBorder, fontSize: 28, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(
            color: kText, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.spaceMono(
            color: kMuted, fontSize: 11)),
          const SizedBox(height: 12),
          Text(description, style: TextStyle(
            color: kMuted, fontSize: 13, height: 1.6)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse(apkUrl),
                mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.android, size: 18),
              label: const Text('Download APK'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2);
  }
}

// ─── SHARED ───────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
      style: GoogleFonts.spaceMono(
        color: kGreen, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w500));
  }
}
