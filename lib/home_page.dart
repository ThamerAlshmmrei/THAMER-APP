import 'package:flutter/material.dart';
import 'service_request_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color primaryColor = Color(0xFF20E0C0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF080B16),
              Color(0xFF15182A),
              Color(0xFF080B16),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 35),

                const Icon(
                  Icons.home_repair_service,
                  color: primaryColor,
                  size: 65,
                ),

                const SizedBox(height: 18),

                const Text(
                  'THAMER APP',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),

                const SizedBox(height: 55),

                const Text(
                  'وش تحتاج؟',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'اختر الخدمة وسنبحث لك عن أقرب فني',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 45),

                serviceCard(
                  context,
                  title: 'سباك',
                  description: 'خدمات السباكة المنزلية',
                  icon: Icons.plumbing,
                  serviceType: 'plumber',
                ),

                const SizedBox(height: 22),

                serviceCard(
                  context,
                  title: 'كهربائي',
                  description: 'خدمات الكهرباء المنزلية',
                  icon: Icons.electrical_services,
                  serviceType: 'electrician',
                ),

                const Spacer(),

                const Text(
                  'THAMER ©️ 2026',
                  style: TextStyle(
                    color: Colors.white38,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget serviceCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required String serviceType,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ServiceRequestPage(
              serviceType: serviceType,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF20283B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.5),
            width: 1.3,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: 48,
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              color: primaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}