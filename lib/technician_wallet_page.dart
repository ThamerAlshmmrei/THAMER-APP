import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'core/pricing.dart';
import 'core/service_catalog.dart';

/// محفظة الفني: أرباحه من الطلبات المدفوعة، وما تم تحويله له،
/// وحسابه البنكي (الآيبان) اللي تُحوّل عليه المستحقات.
class TechnicianWalletPage extends StatelessWidget {
  const TechnicianWalletPage({super.key});

  static const Color primaryColor = Color(0xFF20E0C0);
  static const Color cardColor = Color(0xFF20283B);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('محفظتي'),
        backgroundColor: const Color(0xFF080B16),
        foregroundColor: Colors.white,
      ),
      body: uid == null
          ? const Center(child: Text('يرجى تسجيل الدخول'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('technicianEarnings')
                  .where('technicianId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('تعذر تحميل المحفظة: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                double pending = 0;
                double paidOut = 0;

                for (final doc in docs) {
                  final amount = (doc.data()['amount'] as num?) ?? 0;
                  if (doc.data()['status'] == 'pending') {
                    pending += amount;
                  } else {
                    paidOut += amount;
                  }
                }

                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _stat(
                            'رصيدك المستحق',
                            Pricing.format(pending),
                            primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _stat(
                            'تم تحويله',
                            Pricing.format(paidOut),
                            Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'تُحوّل مستحقاتك إلى حسابك البنكي بشكل دوري.',
                      style: TextStyle(color: Colors.white54, fontSize: 12.5),
                    ),
                    const SizedBox(height: 18),
                    _IbanCard(uid: uid),
                    const SizedBox(height: 22),
                    const Text(
                      'سجل الأرباح',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'ما فيه أرباح للحين. أرباحك تظهر هنا بعد ما يكتمل '
                          'أي طلب.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    for (final doc in docs) _earningTile(doc.data()),
                  ],
                );
              },
            ),
    );
  }

  Widget _stat(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningTile(Map<String, dynamic> data) {
    final service = ServiceCatalog.byId(data['serviceType']);
    final createdAt = data['createdAt'];
    final date = createdAt is Timestamp
        ? '${createdAt.toDate().year}/${createdAt.toDate().month}/'
              '${createdAt.toDate().day}'
        : '';
    final paid = data['status'] == 'paid_out';
    final amount = data['amount'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(service?.icon ?? Icons.build, color: primaryColor),
        title: Text('طلب ${service?.jobName ?? '-'}'),
        subtitle: Text(date),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount is num ? Pricing.format(amount) : '-',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              paid ? 'تم التحويل' : 'مستحق',
              style: TextStyle(
                color: paid ? Colors.white54 : primaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IbanCard extends StatelessWidget {
  final String uid;

  const _IbanCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('technicians')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final iban = (data?['iban'] ?? '').toString();
        final holder = (data?['ibanHolderName'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TechnicianWalletPage.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iban.isEmpty
                  ? Colors.orangeAccent
                  : TechnicianWalletPage.primaryColor.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance,
                color: TechnicianWalletPage.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      iban.isEmpty ? 'أضف حسابك البنكي (الآيبان)' : holder,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (iban.isNotEmpty)
                      Text(
                        iban,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white60),
                      )
                    else
                      const Text(
                        'عشان نقدر نحوّل لك مستحقاتك',
                        style: TextStyle(color: Colors.white60),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _editIban(context, iban, holder),
                child: Text(iban.isEmpty ? 'إضافة' : 'تعديل'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editIban(
    BuildContext context,
    String currentIban,
    String currentHolder,
  ) async {
    final ibanController = TextEditingController(text: currentIban);
    final holderController = TextEditingController(text: currentHolder);
    final messenger = ScaffoldMessenger.of(context);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('الحساب البنكي'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: holderController,
                  decoration: const InputDecoration(
                    labelText: 'اسم صاحب الحساب (كما في البنك)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ibanController,
                  textDirection: TextDirection.ltr,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9 ]')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'رقم الآيبان',
                    hintText: 'SA0000000000000000000000',
                    errorText: error,
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
                onPressed: () {
                  final iban = normalizeIban(ibanController.text);
                  final holder = holderController.text.trim();
                  if (!isValidSaudiIban(iban)) {
                    setDialogState(() => error = 'آيبان سعودي غير صحيح');
                    return;
                  }
                  if (holder.length < 3) {
                    setDialogState(() => error = 'اكتب اسم صاحب الحساب');
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('technicians')
          .doc(uid)
          .update({
            'iban': normalizeIban(ibanController.text),
            'ibanHolderName': holderController.text.trim(),
          });
      messenger.showSnackBar(
        const SnackBar(content: Text('تم حفظ الحساب البنكي')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('تعذر الحفظ: $e')));
    }
  }
}

/// يحذف المسافات ويحوّل الحروف لكبيرة.
String normalizeIban(String input) =>
    input.replaceAll(RegExp(r'\s'), '').toUpperCase();

/// آيبان سعودي: SA + 22 رقم، مع التحقق من رقم التحقق (mod 97).
bool isValidSaudiIban(String iban) {
  if (!RegExp(r'^SA\d{22}$').hasMatch(iban)) return false;

  final rearranged = iban.substring(4) + iban.substring(0, 4);
  final buffer = StringBuffer();
  for (final unit in rearranged.codeUnits) {
    if (unit >= 65 && unit <= 90) {
      buffer.write(unit - 55);
    } else {
      buffer.writeCharCode(unit);
    }
  }

  var remainder = 0;
  for (final char in buffer.toString().split('')) {
    remainder = (remainder * 10 + int.parse(char)) % 97;
  }
  return remainder == 1;
}
