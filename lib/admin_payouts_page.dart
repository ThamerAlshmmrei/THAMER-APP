import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'core/app_config.dart';
import 'core/pricing.dart';

/// لوحة المدفوعات للأدمن: مستحقات كل فني، وتسجيل التحويل البنكي،
/// والطلبات اللي فشل استرجاع مبلغها تلقائياً.
class AdminPayoutsPage extends StatelessWidget {
  const AdminPayoutsPage({super.key});

  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color cardColor = Color(0xFF20283B);

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المدفوعات والتحويلات'),
        backgroundColor: const Color(0xFF080B16),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _RefundIssues(db: db),
          const Text(
            'مستحقات الفنيين',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'حوّل المبلغ للفني من حسابك البنكي، ثم اضغط "تم التحويل".',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('technicianEarnings')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('تعذر التحميل: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final byTechnician = <String, _PendingSummary>{};
              for (final doc in snapshot.data!.docs) {
                final data = doc.data();
                final id = data['technicianId'] as String? ?? '';
                final summary = byTechnician.putIfAbsent(
                  id,
                  () => _PendingSummary(
                    id,
                    (data['technicianName'] ?? '').toString(),
                  ),
                );
                summary.amount += (data['amount'] as num?) ?? 0;
                summary.appFees += (data['appFee'] as num?) ?? 0;
                summary.count++;
              }

              if (byTechnician.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'ما فيه مستحقات معلقة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                );
              }

              final summaries = byTechnician.values.toList()
                ..sort((a, b) => b.amount.compareTo(a.amount));

              final totalDue = summaries.fold<double>(
                0,
                (total, s) => total + s.amount,
              );
              final totalFees = summaries.fold<double>(
                0,
                (total, s) => total + s.appFees,
              );

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('للفنيين: ${Pricing.format(totalDue)}'),
                        Text(
                          'رسوم الخدمة: ${Pricing.format(totalFees)}',
                          style: const TextStyle(color: primaryColor),
                        ),
                      ],
                    ),
                  ),
                  for (final summary in summaries)
                    _TechnicianPayoutCard(summary: summary),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PendingSummary {
  final String technicianId;
  final String name;
  double amount = 0;
  double appFees = 0;
  int count = 0;

  _PendingSummary(this.technicianId, this.name);
}

class _TechnicianPayoutCard extends StatelessWidget {
  final _PendingSummary summary;

  const _TechnicianPayoutCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('technicians')
          .doc(summary.technicianId)
          .snapshots(),
      builder: (context, snapshot) {
        final technician = snapshot.data?.data();
        final iban = (technician?['iban'] ?? '').toString();
        final holder = (technician?['ibanHolderName'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AdminPayoutsPage.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.name.isEmpty ? 'فني' : summary.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    Pricing.format(summary.amount),
                    style: const TextStyle(
                      color: AdminPayoutsPage.primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.count} طلب مكتمل',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 8),
              if (iban.isEmpty)
                const Text(
                  'الفني ما أضاف حسابه البنكي بعد',
                  style: TextStyle(color: Colors.orangeAccent),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$holder\n$iban',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    IconButton(
                      tooltip: 'نسخ الآيبان',
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: iban));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ الآيبان')),
                        );
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: iban.isEmpty
                    ? null
                    : () => _recordPayout(context, summary),
                icon: const Icon(Icons.check),
                label: const Text('تم التحويل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminPayoutsPage.primaryColor,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _recordPayout(
    BuildContext context,
    _PendingSummary summary,
  ) async {
    final referenceController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد التحويل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'هل حوّلت ${Pricing.format(summary.amount)} '
              'إلى ${summary.name.isEmpty ? 'الفني' : summary.name}؟',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'رقم مرجع التحويل (اختياري)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('نعم، تم التحويل'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await appFunctions.httpsCallable('recordPayout').call<void>({
        'technicianId': summary.technicianId,
        'reference': referenceController.text.trim(),
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('تم تسجيل التحويل وإشعار الفني')),
      );
    } on FirebaseFunctionsException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'تعذر تسجيل التحويل')),
      );
    }
  }
}

/// طلبات ملغاة فشل استرجاع مبلغها تلقائياً: تُسترجع يدوياً من لوحة ميسّر.
class _RefundIssues extends StatelessWidget {
  final FirebaseFirestore db;

  const _RefundIssues({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('requests')
          .where('paymentStatus', isEqualTo: 'refund_failed')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${docs.length} طلب ملغي فشل استرجاع مبلغه',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'استرجعها يدوياً من لوحة ميسّر برقم الدفعة:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              for (final doc in docs)
                SelectableText(
                  '${doc.data()['paymentId']} • '
                  '${Pricing.format((doc.data()['paidAmount'] as num?) ?? 0)}',
                  textDirection: TextDirection.ltr,
                ),
            ],
          ),
        );
      },
    );
  }
}
