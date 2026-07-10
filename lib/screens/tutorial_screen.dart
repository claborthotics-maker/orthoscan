import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});
  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _slides = [
    _Slide(
      icon: Icons.health_and_safety,
      title: 'Welcome to CL@B',
      body: 'CL@B helps you create and send orthotic lab orders quickly and accurately — right from your phone.',
    ),
    _Slide(
      icon: Icons.person_add,
      title: 'Add Patients',
      body: 'Start by adding a patient from the home screen. You can store their name, date of birth, ID, and clinical notes.',
    ),
    _Slide(
      icon: Icons.assignment,
      title: 'Create Work Orders',
      body: 'Open a patient and create a work order. Choose an orthotic type, fill in specs, and add accommodations.',
    ),
    _Slide(
      icon: Icons.draw,
      title: 'Foot Diagram',
      body: 'Mark pressure points, relief areas, and missing toes directly on the foot diagram. These appear in the PDF.',
    ),
    _Slide(
      icon: Icons.send,
      title: 'Submit to Lab',
      body: 'When ready, tap Submit to Lab. A PDF is generated and shared instantly via email, text, or any app.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_done', true);
    if (!mounted) return;
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip', style: TextStyle(color: Colors.white54)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _buildSlide(_slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentPage == i ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? const Color(0xFF4FC3F7) : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (_currentPage < _slides.length - 1) {
                      _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    } else {
                      _finish();
                    }
                  },
                  child: Text(
                    _currentPage < _slides.length - 1 ? 'Next' : 'Get Started',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_Slide slide) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4FC3F7), width: 2),
            ),
            child: Icon(slide.icon, color: const Color(0xFF4FC3F7), size: 60),
          ),
          const SizedBox(height: 40),
          Text(slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(slide.body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.title, required this.body});
}

