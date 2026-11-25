# ثامر (THAMER)

تطبيق يربط العميل بأقرب فني متاح: **سباك، كهربائي، فني مكيفات، فني غسالات**.
العميل يرسل طلبه وموقعه. النظام يعرض الطلب على أقرب فني متاح، وإذا رفضه الفني أو ما رد خلال دقيقتين ينتقل للفني اللي بعده تلقائياً.
بعد قبول الطلب يقدر العميل يتواصل مع الفني بالاتصال أو واتساب أو المحادثة، ويتابع موقعه مباشرة.

## مكونات المشروع

| المجلد | المحتوى |
|---|---|
| `lib/` | تطبيق Flutter (أندرويد و iOS) |
| `lib/core/service_catalog.dart` | الخدمات الأربع وخيارات المكيفات والغسالات |
| `lib/core/pricing.dart` | التسعير |
| `functions/` | Cloud Functions: توزيع الطلبات، مهلة الفني، الإشعارات |
| `firestore.rules` | قواعد الحماية (تتحقق من الأسعار والصلاحيات) |
| `firestore.indexes.json` | فهارس Firestore |
| `storage.rules` | قواعد رفع صور الفنيين |
| `rules-tests/` | اختبارات قواعد الحماية |
| `docs/` | صفحات الخصوصية والشروط وحذف الحساب (تُنشر على Firebase Hosting) |
| `store/` | نصوص المتجر وإجابات نماذج الخصوصية وصورة Google Play |
| `assets/branding/` | الأيقونة وشعار شاشة البداية |

## التسعير

- أجرة العمل: **1.5 ريال للدقيقة** (من 5 إلى 120 دقيقة).
- رسوم الخدمة (ربح التطبيق): **15% من أجرة العمل، بحد أدنى 5 ريال**.

| المدة | أجرة الفني | رسوم الخدمة | الإجمالي |
|---|---|---|---|
| 10 دقائق | 15.00 | 5.00 | 20.00 |
| 30 دقيقة | 45.00 | 6.75 | 51.75 |
| 60 دقيقة | 90.00 | 13.50 | 103.50 |
| 120 دقيقة | 180.00 | 27.00 | 207.00 |

لتغيير النسبة عدّل `lib/core/pricing.dart` **و** دالة `validAppFee` في `firestore.rules` معاً، لأن القواعد ترفض أي طلب سعره لا يطابق الحساب.

## حالات الطلب

`searching` ← `offered` ← (`accepted` أو `rejected` ← فني آخر) ← `waiting_customer_confirmation` ← `completed`

- العميل يقدر **يلغي** الطلب قبل قبول الفني (`cancelled`).
- إذا ما فيه فني متاح (`no_technician_available`) يقدر العميل **يعيد البحث**.
- إذا أنهى الفني العمل وما أكّد العميل، يُعتمد الطلب تلقائياً بعد **3 ساعات**، عشان ما يتعطل الفني عن طلبات جديدة.

---

## التشغيل للتطوير

```bash
flutter pub get

# على Firebase الحقيقي
flutter run

# على المحاكيات المحلية (Emulators)
firebase emulators:start
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
# على جوال حقيقي حدد عنوان جهازك:
flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=192.168.1.10
```

الاختبارات:

```bash
flutter test                         # اختبارات التطبيق (التسعير والخدمات)
cd rules-tests && npm install && npm test   # اختبارات قواعد Firestore (تحتاج Java)
cd functions && npm install && npm run lint
```

---

## خطوات النشر (مرة واحدة)

### 1) Firebase Console (المشروع `thamer-e0fdd`)

1. **الخطة**: تحتاج خطة **Blaze**، لأن Cloud Functions و Cloud Tasks و Storage يتطلبونها.
2. **Authentication ← Sign-in method**: فعّل **Phone**.
3. **Storage**: أنشئ الـ bucket (لصور الفنيين).
4. **Cloud Messaging ← Apple app configuration**: ارفع **APNs Authentication Key (.p8)** من حساب Apple Developer. بدونه ما توصل الإشعارات لأجهزة iPhone.
5. في Google Cloud لنفس المشروع: فعّل **Cloud Tasks API**.
6. **حماية الرسائل (مهم مالياً)**:
   - Authentication ← Settings ← **SMS region policy**: اسمح بالسعودية فقط (`SA`).
   - **App Check**: سجّل تطبيق أندرويد بـ **Play Integrity** (يحتاج بصمة SHA-256)، وتطبيق iOS بـ **DeviceCheck** (يحتاج مفتاح DeviceCheck من حساب Apple).
   - جرّب التطبيق أسبوع وتأكد من صفحة App Check أن الطلبات "Verified"، ثم فعّل **Enforce** لـ Authentication و Firestore و Storage.
   - في وضع التطوير يطبع التطبيق "debug token" في السجل. أضفه في App Check ← Manage debug tokens.
7. **أرقام جوال تجريبية** للمراجعين: Authentication ← Phone ← Phone numbers for testing (التفاصيل في `store/STORE_LISTING.md`).
8. **بريد الدعم**: اكتبه في `lib/core/app_config.dart` (`supportEmail`)، واستبدل `SUPPORT_EMAIL` في ملفات `docs/*.html`.
9. انشر كل شيء:

```bash
cd functions && npm install && cd ..
firebase deploy --only firestore,storage,functions,hosting
```

   بعدها تشتغل صفحات الخصوصية على `https://thamer-e0fdd.web.app/privacy.html`.

10. **أول حساب أدمن**: سجّل كعميل من التطبيق، ثم من Firestore Console غيّر حقل `role` في `users/{uid}` إلى `admin`.

### 2) أندرويد

1. **اسم الحزمة**: Google Play لا يقبل `com.example.my_first_app`. لتغييره إلى `com.thamer.thamer` (نفس معرف iOS):
   - في Firebase Console ← Project settings ← Add app ← Android بالاسم `com.thamer.thamer`، وأضف بصمات **SHA-1 و SHA-256** لمفتاح التوقيع (ضرورية لتسجيل الدخول برقم الجوال).
   - شغّل `flutterfire configure` لتحديث `lib/firebase_options.dart`.
   - غيّر `applicationId` في `android/app/build.gradle.kts`.
2. **مفتاح التوقيع**:

```bash
keytool -genkey -v -keystore ~/thamer-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

   أنشئ الملف `android/key.properties` (لا ترفعه على Git):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/المسار/thamer-upload.jks
```

3. البناء: `flutter build appbundle`

### 3) iOS (يحتاج جهاز Mac مع Xcode)

1. معرف التطبيق مضبوط على `com.thamer.thamer`، وهو المسجل في Firebase.
2. افتح `ios/Runner.xcworkspace` ← Runner ← **Signing & Capabilities**:
   - اختر الـ Team.
   - تأكد من وجود **Push Notifications** و **Background Modes ← Remote notifications** (ملف `Runner.entitlements` جاهز).
3. البناء: `flutter build ipa`

---

## الأيقونة وشاشة البداية

الملفات في `assets/branding/`. لتغيير الشعار استبدل الصور ثم شغّل:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## ملاحظات

- **الدفع**: السعر يُحسب ويُعرض، والدفع حالياً **نقداً للفني**. ربط بوابة دفع (Moyasar / Tap / Apple Pay) يحتاج حساب تاجر.
- **حذف الحساب**: من "حسابي ← حذف الحساب" (مطلوب من Apple و Google). ينفذه الـ Function `deleteAccount`: يحذف بيانات المستخدم وتسجيل دخوله ورسائله، ويزيل اسمه ورقمه من الطلبات السابقة، ويرفض الحذف إذا عنده طلب جاري.
- **صور الفنيين**: رفعها مفعّل. لإيقافه مؤقتاً ابنِ بـ `--dart-define=ENABLE_STORAGE=false`.
- لإضافة خدمة جديدة: أضفها في `lib/core/service_catalog.dart`، وفي `serviceTypes()` داخل `firestore.rules`، وفي `SERVICE_NAMES` داخل `functions/index.js`.
