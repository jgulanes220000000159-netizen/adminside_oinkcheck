import 'package:flutter/material.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({Key? key, required this.onLoginPressed}) : super(key: key);
  final VoidCallback onLoginPressed;

  static const Color _primary = Color(0xFF1B5E20);
  static const Color _accent = Color(0xFF66BB6A);
  static const Color _dark = Color(0xFF121212);
  static const Color _text = Color(0xFF1E1E1E);
  static const Color _textSec = Color(0xFF616161);

  static const String _playStoreUrl =
      'https://drive.google.com/drive/folders/1kbf47I0L3mEflP3rljq0loCMLJc5fi8n?usp=sharing';

  static const List<_DiseaseInfo> _diseases = [
    _DiseaseInfo(
      name: 'Swine Pox',
      key: 'swine_pox',
      description:
          'A viral disease caused by the Swine Poxvirus. It manifests as raised, round skin lesions that progress from red papules to pustules and scabs, primarily affecting young pigs.',
      causes:
          'Spread by lice, mosquitoes, and direct contact with infected animals.',
    ),
    _DiseaseInfo(
      name: 'Bacterial Erysipelas',
      key: 'bacterial_erysipelas',
      description:
          'Caused by Erysipelothrix rhusiopathiae, this disease produces characteristic diamond-shaped red skin lesions. Can be acute or chronic and may affect joints and heart valves.',
      causes:
          'Bacteria found in soil; enters through wounds or ingestion of contaminated feed.',
    ),
    _DiseaseInfo(
      name: 'Greasy Pig Disease',
      key: 'greasy_pig_disease',
      description:
          'A skin infection caused by Staphylococcus hyicus bacteria. It produces greasy, brown exudative lesions that can cover the entire body, giving the skin a dirty appearance.',
      causes:
          'Bacteria enter through skin abrasions; stress and poor hygiene increase risk.',
    ),
    _DiseaseInfo(
      name: 'Sunburn',
      key: 'sunburn',
      description:
          'UV radiation damage to pig skin, especially in light-skinned breeds. Appears as reddened, inflamed skin that can blister and peel, causing pain and secondary infections.',
      causes:
          'Prolonged exposure to direct sunlight without access to shade or wallows.',
    ),
    _DiseaseInfo(
      name: 'Ringworm',
      key: 'ringworm',
      description:
          'A fungal skin infection (dermatophytosis) that creates circular, raised, crusty lesions. The affected areas show hair loss and scaly skin patches.',
      causes:
          'Caused by fungi (Trichophyton or Microsporum); spread by direct contact or contaminated surfaces.',
    ),
    _DiseaseInfo(
      name: 'Mange',
      key: 'mange',
      description:
          'A parasitic skin disease caused by Sarcoptes scabiei mites. Causes intense itching, crusty lesions, hair loss, and thickened skin, especially around ears, eyes, and snout.',
      causes:
          'Transmitted by direct contact with infested pigs or contaminated environments.',
    ),
    _DiseaseInfo(
      name: 'Foot-and-Mouth Disease',
      key: 'foot_and_mouth',
      description:
          'A highly contagious viral disease that causes blisters and erosions on the feet, mouth, and snout. Affected pigs may become lame and show excessive salivation.',
      causes:
          'Caused by an Aphthovirus; spreads rapidly through direct contact, aerosol, and contaminated materials.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _AOS(
                  type: _AOSType.fadeIn,
                  duration: 600,
                  child: _buildHero(context),
                ),
              ),
              SliverToBoxAdapter(
                child: _AOS(
                  type: _AOSType.fadeUp,
                  delay: 100,
                  child: _buildAbout(context),
                ),
              ),
              SliverToBoxAdapter(
                child: _AOS(
                  type: _AOSType.fadeUp,
                  delay: 100,
                  child: _buildFeatures(context),
                ),
              ),
              SliverToBoxAdapter(
                child: _AOS(
                  type: _AOSType.fadeIn,
                  delay: 50,
                  child: _DiseaseCarousel(diseases: _diseases),
                ),
              ),
              SliverToBoxAdapter(
                child: _AOS(
                  type: _AOSType.fadeUp,
                  delay: 100,
                  child: _buildHowItWorks(context),
                ),
              ),
              SliverToBoxAdapter(
                child: _AOS(
                  type: _AOSType.fadeUp,
                  delay: 100,
                  child: _buildBenefits(context),
                ),
              ),
              SliverToBoxAdapter(
                child: _AOS(
                  type: _AOSType.fadeIn,
                  delay: 50,
                  child: _buildFooter(context),
                ),
              ),
            ],
          ),
          _buildFloatingNav(context),
        ],
      ),
    );
  }

  Widget _buildFloatingNav(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                width: 38,
                height: 38,
                errorBuilder:
                    (_, __, ___) => Icon(Icons.pets, size: 38, color: _primary),
              ),
              const SizedBox(width: 10),
              const Text(
                'OinkCheck',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _text,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onLoginPressed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isWide = screenW > 860;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: 100,
        left: 48,
        right: 48,
        bottom: isWide ? 80 : 48,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D3B0F), Color(0xFF1B5E20), Color(0xFF2E7D32)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child:
              isWide
                  ? Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _AOS(
                          type: _AOSType.fadeRight,
                          delay: 200,
                          duration: 800,
                          child: _heroText(),
                        ),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        flex: 2,
                        child: _AOS(
                          type: _AOSType.zoomIn,
                          delay: 400,
                          duration: 900,
                          child: _heroLogo(),
                        ),
                      ),
                    ],
                  )
                  : Column(
                    children: [
                      _AOS(
                        type: _AOSType.zoomIn,
                        delay: 200,
                        duration: 900,
                        child: _heroLogo(size: 120),
                      ),
                      const SizedBox(height: 32),
                      _AOS(
                        type: _AOSType.fadeUp,
                        delay: 400,
                        duration: 800,
                        child: _heroText(centered: true),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _heroLogo({double size = 200}) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.white.withOpacity(0.12),
        child: ClipOval(
          child: Image.asset(
            'assets/logo.png',
            width: size * 0.7,
            height: size * 0.7,
            fit: BoxFit.contain,
            errorBuilder:
                (_, __, ___) =>
                    Icon(Icons.pets, size: size * 0.5, color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _heroText({bool centered = false}) {
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'OinkCheck',
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'AI-powered pig skin disease detection.\nEarly diagnosis, treatment recommendations,\nand expert validation — all in one app.',
          textAlign: centered ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white.withOpacity(0.88),
            fontSize: 18,
            height: 1.6,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 36),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/qrc.jpg',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Download the app',
                style: TextStyle(
                  color: _primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan QR code with your phone',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
              const SizedBox(height: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse(_playStoreUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 14,
                        color: _primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'or click here to download',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAbout(BuildContext context) {
    return _SectionWrap(
      bg: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Chip('ABOUT'),
          const SizedBox(height: 16),
          const Text(
            'What is OinkCheck?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: const Text(
              'OinkCheck is a mobile-based AI application that detects common pig skin diseases using Convolutional Neural Networks (CNN). '
              'It supports early diagnosis, treatment recommendation, and expert validation for farmers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, height: 1.8, color: _textSec),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures(BuildContext context) {
    final features = [
      (
        Icons.map_rounded,
        'Geo-tagging',
        'Tracks disease outbreaks with heatmap visualization.',
      ),
      (
        Icons.verified_user_rounded,
        'Expert Validation',
        'Veterinarians review and verify AI detection results.',
      ),
      (
        Icons.wifi_off_rounded,
        'Offline Support',
        'Works without internet — sync when you reconnect.',
      ),
    ];
    return _SectionWrap(
      bg: const Color(0xFFF6F9F4),
      child: Column(
        children: [
          _Chip('FEATURES'),
          const SizedBox(height: 16),
          const Text(
            'Key Features',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (ctx, c) {
              final narrow = c.maxWidth < 700;
              final cards =
                  features.asMap().entries.map((e) {
                    return _AOS(
                      type: _AOSType.fadeUp,
                      delay: 120 * e.key,
                      child: _FeatureCard(
                        icon: e.value.$1,
                        title: e.value.$2,
                        desc: e.value.$3,
                      ),
                    );
                  }).toList();
              return narrow
                  ? Column(
                    children:
                        cards
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: c,
                              ),
                            )
                            .toList(),
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        cards
                            .map(
                              (c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: c,
                                ),
                              ),
                            )
                            .toList(),
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    const steps = [
      (
        'Capture',
        'Take a photo of the pig skin using your phone camera.',
        Icons.camera_alt_rounded,
      ),
      (
        'Detect',
        'AI analyzes the image and classifies the disease.',
        Icons.psychology_rounded,
      ),
      (
        'Recommend',
        'Get treatment recommendations instantly.',
        Icons.healing_rounded,
      ),
      (
        'Verify',
        'Report is sent to veterinarians for validation.',
        Icons.assignment_turned_in_rounded,
      ),
      (
        'Monitor',
        'Heatmap updates for regional disease surveillance.',
        Icons.map_rounded,
      ),
    ];
    return _SectionWrap(
      bg: Colors.white,
      child: Column(
        children: [
          _Chip('PROCESS'),
          const SizedBox(height: 16),
          const Text(
            'How It Works',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 48),
          LayoutBuilder(
            builder: (ctx, c) {
              final narrow = c.maxWidth < 700;
              if (narrow) {
                return Column(
                  children:
                      steps.asMap().entries.map((e) {
                        return _AOS(
                          type: _AOSType.fadeUp,
                          delay: 100 * e.key,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: _StepCard(
                              index: e.key + 1,
                              title: e.value.$1,
                              desc: e.value.$2,
                              icon: e.value.$3,
                            ),
                          ),
                        );
                      }).toList(),
                );
              }
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children:
                    steps.asMap().entries.map((e) {
                      return _AOS(
                        type: _AOSType.fadeUp,
                        delay: 100 * e.key,
                        child: SizedBox(
                          width: 190,
                          child: _StepCard(
                            index: e.key + 1,
                            title: e.value.$1,
                            desc: e.value.$2,
                            icon: e.value.$3,
                          ),
                        ),
                      );
                    }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits(BuildContext context) {
    final items = [
      (
        Icons.agriculture_rounded,
        'Farmers',
        'Early detection reduces financial loss and protects livestock.',
        const Color(0xFF388E3C),
      ),
      (
        Icons.local_hospital_rounded,
        'Veterinarians',
        'Efficient remote case management saves time and resources.',
        const Color(0xFF1565C0),
      ),
      (
        Icons.public_rounded,
        'Community',
        'Improved food security and disease prevention for all.',
        const Color(0xFFE65100),
      ),
    ];
    return _SectionWrap(
      bg: const Color(0xFFF6F9F4),
      child: Column(
        children: [
          _Chip('IMPACT'),
          const SizedBox(height: 16),
          const Text(
            'Who Benefits',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: _text,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (ctx, c) {
              final narrow = c.maxWidth < 700;
              final cards =
                  items.asMap().entries.map((e) {
                    return _AOS(
                      type: _AOSType.fadeUp,
                      delay: 120 * e.key,
                      child: _BenefitCard(
                        icon: e.value.$1,
                        title: e.value.$2,
                        desc: e.value.$3,
                        color: e.value.$4,
                      ),
                    );
                  }).toList();
              return narrow
                  ? Column(
                    children:
                        cards
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: c,
                              ),
                            )
                            .toList(),
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        cards
                            .map(
                              (c) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: c,
                                ),
                              ),
                            )
                            .toList(),
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
      color: _dark,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 32,
                          height: 32,
                          errorBuilder:
                              (_, __, ___) => const Icon(
                                Icons.pets,
                                size: 32,
                                color: Colors.white54,
                              ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'OinkCheck',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI-powered pig skin disease detection.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEVELOPER',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jay Jr. S. Gulanes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'University of the Immaculate Conception',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Master in Information Technology',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiseaseInfo {
  final String name;
  final String key;
  final String description;
  final String causes;
  const _DiseaseInfo({
    required this.name,
    required this.key,
    required this.description,
    required this.causes,
  });
}

class _DiseaseCarousel extends StatefulWidget {
  const _DiseaseCarousel({Key? key, required this.diseases}) : super(key: key);
  final List<_DiseaseInfo> diseases;

  @override
  State<_DiseaseCarousel> createState() => _DiseaseCarouselState();
}

class _DiseaseCarouselState extends State<_DiseaseCarousel> {
  late final PageController _controller;
  int _current = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.38, initialPage: 0);
    _startAuto();
  }

  void _startAuto() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_current + 1) % widget.diseases.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showDiseaseDetail(BuildContext context, _DiseaseInfo d) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 260),
                        color: Colors.grey.shade200,
                        child: Image.asset(
                          'assets/diseases/${d.key}.jpg',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder:
                              (_, __, ___) => SizedBox(
                                height: 200,
                                child: Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 56,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      d.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      d.description,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFF616161),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F9F4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: Color(0xFF1B5E20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Causes',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1B5E20),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  d.causes,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Color(0xFF616161),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64),
      color: const Color(0xFF0D3B0F),
      child: Column(
        children: [
          const _Chip('DETECTION', light: true),
          const SizedBox(height: 16),
          const Text(
            'Diseases Detected',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a card to learn more about each disease',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 320,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.diseases.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) {
                final d = widget.diseases[index];
                return AnimatedScale(
                  scale: _current == index ? 1.0 : 0.88,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: _current == index ? 1.0 : 0.6,
                    duration: const Duration(milliseconds: 300),
                    child: GestureDetector(
                      onTap: () {
                        _autoTimer?.cancel();
                        _showDiseaseDetail(context, d);
                        _startAuto();
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white,
                            boxShadow: [
                              if (_current == index)
                                BoxShadow(
                                  color: const Color(
                                    0xFF66BB6A,
                                  ).withOpacity(0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: Container(
                                    color: Colors.grey.shade200,
                                    child: Image.asset(
                                      'assets/diseases/${d.key}.jpg',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder:
                                          (_, __, ___) => Center(
                                            child: Icon(
                                              Icons.image_outlined,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E1E1E),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to learn more',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          // Dots indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.diseases.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _current == i ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      _current == i
                          ? const Color(0xFF66BB6A)
                          : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          // Navigation arrows
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CarouselArrow(
                icon: Icons.arrow_back_rounded,
                onTap: () {
                  _autoTimer?.cancel();
                  final prev = (_current - 1).clamp(
                    0,
                    widget.diseases.length - 1,
                  );
                  _controller.animateToPage(
                    prev,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                  _startAuto();
                },
              ),
              const SizedBox(width: 24),
              _CarouselArrow(
                icon: Icons.arrow_forward_rounded,
                onTap: () {
                  _autoTimer?.cancel();
                  final next = (_current + 1) % widget.diseases.length;
                  _controller.animateToPage(
                    next,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                  );
                  _startAuto();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({Key? key, required this.icon, required this.onTap})
    : super(key: key);
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.12),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _SectionWrap extends StatelessWidget {
  const _SectionWrap({Key? key, required this.child, this.bg = Colors.white})
    : super(key: key);
  final Widget child;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: child,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.light = false});
  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color:
            light
                ? Colors.white.withOpacity(0.12)
                : const Color(0xFF1B5E20).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: light ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.desc,
  }) : super(key: key);
  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1B5E20), const Color(0xFF388E3C)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    Key? key,
    required this.index,
    required this.title,
    required this.desc,
    required this.icon,
  }) : super(key: key);
  final int index;
  final String title;
  final String desc;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B5E20).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Icon(icon, color: const Color(0xFF2E7D32), size: 28),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────
// AOS — Animate On Scroll (like JS AOS library)
// ──────────────────────────────────────
enum _AOSType { fadeUp, fadeIn, fadeLeft, fadeRight, zoomIn }

class _AOS extends StatefulWidget {
  const _AOS({
    Key? key,
    required this.child,
    this.type = _AOSType.fadeUp,
    this.duration = 700,
    this.delay = 0,
  }) : super(key: key);

  final Widget child;
  final _AOSType type;
  final int duration;
  final int delay;

  @override
  State<_AOS> createState() => _AOSState();
}

class _AOSState extends State<_AOS> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  bool _visible = false;
  Timer? _delayTimer;
  ScrollPosition? _scrollPosition;

  static const double _slideDistance = 60.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.duration),
    );

    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);

    Offset beginOffset;
    switch (widget.type) {
      case _AOSType.fadeUp:
        beginOffset = const Offset(0, _slideDistance);
        break;
      case _AOSType.fadeLeft:
        beginOffset = const Offset(-_slideDistance, 0);
        break;
      case _AOSType.fadeRight:
        beginOffset = const Offset(_slideDistance, 0);
        break;
      case _AOSType.fadeIn:
      case _AOSType.zoomIn:
        beginOffset = Offset.zero;
        break;
    }
    _slide = Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(curve);

    final scaleBegin = widget.type == _AOSType.zoomIn ? 0.85 : 1.0;
    _scale = Tween<double>(begin: scaleBegin, end: 1.0).animate(curve);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attachScrollListener();
      _checkVisibility();
    });
  }

  void _attachScrollListener() {
    if (!mounted) return;
    _scrollPosition = Scrollable.of(context).position;
    _scrollPosition?.addListener(_onScroll);
  }

  void _onScroll() {
    _checkVisibility();
  }

  void _checkVisibility() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    final viewportH = MediaQuery.of(context).size.height;

    // Element is "in view" when its top is above 92% of viewport
    // AND its bottom is still below 0 (not scrolled past entirely)
    final inView = pos.dy < viewportH * 0.92 && (pos.dy + size.height) > 0;

    if (inView && !_visible) {
      _visible = true;
      _delayTimer?.cancel();
      _delayTimer = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _ctrl.forward();
      });
    } else if (!inView && _visible) {
      _visible = false;
      _delayTimer?.cancel();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _scrollPosition?.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: _slide.value,
            child: Transform.scale(scale: _scale.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  }) : super(key: key);
  final IconData icon;
  final String title;
  final String desc;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF616161),
            ),
          ),
        ],
      ),
    );
  }
}
