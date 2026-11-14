import 'package:flutter/material.dart';
import '../widgets/brand_logo.dart';

class S45BrandScreen extends StatelessWidget {
  const S45BrandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main hero card (dark)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1016),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                child: Column(
                  children: [
                    const BrandLogo(size: 240),
                    const SizedBox(height: 28),
                    const Text(
                      'DEVOPS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3.84,
                        color: Color(0xFFA898FF),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Command Center',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // The idea
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E5EC)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The idea',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.04,
                        color: Color(0xFF6B7385),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildIdeaBullet(
                      title: 'Shield',
                      desc: ': safe, controlled remediation with reviewed playbooks.',
                    ),
                    const SizedBox(height: 10),
                    _buildIdeaBullet(
                      title: 'Pulse that rises into a check',
                      desc: ': one incident from detection to verified recovery.',
                    ),
                    const SizedBox(height: 10),
                    _buildIdeaBullet(
                      title: 'Green signal dot',
                      desc: ': the service is live and healthy again.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Logo on dark & Logo on light
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1016),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Logo on dark',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.96,
                              color: Color(0xFF6B7385),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const BrandLogo(size: 64),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'DEVOPS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2.4,
                                        color: Color(0xFFA898FF),
                                      ),
                                    ),
                                    Text(
                                      'Command Center',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFECEEF3),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E5EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Logo on light',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.96,
                              color: Color(0xFF6B7385),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const BrandLogo(size: 64),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      'DEVOPS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 2.4,
                                        color: Color(0xFF5A43D6),
                                      ),
                                    ),
                                    Text(
                                      'Command Center',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF151922),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // App icon sizes
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E5EC)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App icon sizes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.04,
                        color: Color(0xFF6B7385),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        _BuildSizeTile(size: 96),
                        SizedBox(width: 16),
                        _BuildSizeTile(size: 64),
                        SizedBox(width: 16),
                        _BuildSizeTile(size: 48),
                        SizedBox(width: 16),
                        _BuildSizeTile(size: 32),
                        SizedBox(width: 16),
                        _BuildSizeTile(size: 24),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Symbol and single colour
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E5EC)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Symbol and single colour',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.04,
                        color: Color(0xFF6B7385),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const BrandLogo(size: 64),
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1438),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.shield_outlined, size: 40, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E5EC)),
                          ),
                          child: const Icon(Icons.shield_outlined, size: 40, color: Color(0xFF151922)),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A43D6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.shield_outlined, size: 40, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Colours
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E5EC)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Colours',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.04,
                        color: Color(0xFF6B7385),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildSwatch(color: const Color(0xFF1B1438), name: 'Ink', hex: '#1B1438'),
                        _buildSwatch(color: const Color(0xFFA898FF), name: 'Lavender', hex: '#A898FF'),
                        _buildSwatch(color: const Color(0xFFBCB0FF), name: 'Lavender light', hex: '#BCB0FF'),
                        _buildSwatch(color: const Color(0xFF5A43D6), name: 'Violet · light UI', hex: '#5A43D6'),
                        _buildSwatch(color: const Color(0xFF55D394), name: 'Signal green', hex: '#55D394'),
                        _buildSwatch(color: const Color(0xFFFF6B6B), name: 'Critical', hex: '#FF6B6B'),
                        _buildSwatch(color: const Color(0xFFFFB84D), name: 'Warning', hex: '#FFB84D'),
                        _buildSwatch(color: const Color(0xFF0E1016), name: 'Night · dark UI', hex: '#0E1016'),
                        _buildSwatch(color: const Color(0xFFF4F5F9), name: 'Paper · light UI', hex: '#F4F5F9'),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Usage rules
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E5EC)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Usage',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.04,
                        color: Color(0xFF6B7385),
                      ),
                    ),
                    SizedBox(height: 14),
                    Text('• Keep clear space around the logo equal to the green dot’s width × 2.'),
                    SizedBox(height: 8),
                    Text('• Smallest size: 24 px icon, 120 px wide lockup.'),
                    SizedBox(height: 8),
                    Text('• Use the tile on app icons and splash; the bare symbol inside the app.'),
                    SizedBox(height: 8),
                    Text('• Do not recolour the shield, rotate it or add effects.'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // On the home screen
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E5EC)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'On the home screen',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.04,
                        color: Color(0xFF6B7385),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '14:34',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 18,
                            runSpacing: 18,
                            alignment: WrapAlignment.center,
                            children: const [
                              _BuildAppGridItem(icon: Icons.mail, name: 'Mail', bg: Colors.blue),
                              _BuildAppGridItem(icon: Icons.calendar_today, name: 'Calendar', bg: Colors.red),
                              _BuildAppGridItem(icon: Icons.chat_bubble, name: 'Chat', bg: Colors.green),
                              _BuildAppGridItem(icon: Icons.map, name: 'Maps', bg: Colors.amber),
                              _BuildAppGridItem(icon: Icons.photo, name: 'Photos', bg: Colors.purple),
                              _BuildAppGridItem(icon: Icons.music_note, name: 'Music', bg: Colors.pink),
                              _BuildAppGridItem(icon: Icons.settings, name: 'Settings', bg: Colors.grey),
                              _BuildCommandCenterAppItem(),
                            ],
                          ),
                        ],
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

  Widget _buildIdeaBullet({required String title, required String desc}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF151922)),
        children: [
          TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: desc),
        ],
      ),
    );
  }

  Widget _buildSwatch({required Color color, required String name, required String hex}) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E5EC)),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(hex, style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: Color(0xFF6B7385))),
        ],
      ),
    );
  }
}

class _BuildSizeTile extends StatelessWidget {
  final double size;
  const _BuildSizeTile({required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BrandLogo(size: size),
        const SizedBox(height: 8),
        Text(
          '${size.toInt()}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7385)),
        ),
      ],
    );
  }
}

class _BuildAppGridItem extends StatelessWidget {
  final IconData icon;
  final String name;
  final Color bg;

  const _BuildAppGridItem({required this.icon, required this.name, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 11, color: Colors.white),
        ),
      ],
    );
  }
}

class _BuildCommandCenterAppItem extends StatelessWidget {
  const _BuildCommandCenterAppItem();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const BrandLogo(size: 52),
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  '1',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'DevOps',
          style: TextStyle(fontSize: 11, color: Colors.white),
        ),
      ],
    );
  }
}
