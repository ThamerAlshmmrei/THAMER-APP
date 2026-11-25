# بيانات المتجر — جاهزة للنسخ واللصق

> قبل الرفع: استبدل كل `SUPPORT_EMAIL` ببريد الدعم الحقيقي، هنا وفي ملفات `docs/*.html`.

## الروابط

| | الرابط |
|---|---|
| سياسة الخصوصية | https://thamer-e0fdd.web.app/privacy.html |
| الشروط والأحكام | https://thamer-e0fdd.web.app/terms.html |
| حذف الحساب (Google يطلبه) | https://thamer-e0fdd.web.app/delete-account.html |
| موقع الدعم / Marketing URL | https://thamer-e0fdd.web.app |

تشتغل هذه الروابط بعد: `firebase deploy --only hosting`

---

## الاسم والوصف

| الحقل | النص | الحد |
|---|---|---|
| اسم التطبيق | ثامر - فني لبيتك | 30 |
| العنوان الفرعي (iOS) | سباك، كهربائي، مكيفات، غسالات | 30 |
| الوصف القصير (Google Play) | اطلب أقرب سباك أو كهربائي أو فني مكيفات وغسالات، بسعر واضح بالدقيقة. | 80 |
| الكلمات المفتاحية (iOS) | `سباك,كهربائي,فني,مكيفات,غسالات,صيانة,تكييف,تسريب,فريون,منزل,plumber,electrician` | 100 |
| التصنيف | iOS: **Lifestyle** · Google Play: **House & Home** | |
| الفئة العمرية | iOS: **4+**، Google Play: **Everyone / 3+** (عبر استبيان IARC) | |

### الوصف الكامل (عربي)

```
ثامر يوصلك بأقرب فني متاح حولك خلال دقائق، وبسعر واضح قبل ما تطلب.

الخدمات:
• سباك: تسريبات، تركيب، صيانة
• كهربائي: أفياش، إنارة، أعطال
• فني مكيفات: سبليت، شباك، دولابي، كاسيت، مركزي. تنظيف، تعبئة فريون، لا يبرد، تسريب، تركيب، فك ونقل
• فني غسالات: تحميل أمامي، علوي، حوضين، نشافة. ما تصرّف، ما تعصر، تسريب، تركيب

كيف يشتغل؟
1. اختر الخدمة وحدد نوع جهازك ووش يحتاج
2. حدد مدة العمل وشوف السعر مباشرة: 1.5 ريال للدقيقة، وادفع بأمان بمدى أو Apple Pay أو STC Pay
3. نرسل طلبك لأقرب فني، وإذا ما رد خلال دقيقتين ننقله للي بعده
4. تابع وصول الفني، وكلمه بالاتصال أو واتساب أو المحادثة
5. أكّد انتهاء الشغل

ليش ثامر؟
• سعر واضح بالدقيقة، بدون مفاجآت
• أقرب فني لك جغرافياً
• فنيين معتمدين بعد التحقق من هويتهم
• دفع إلكتروني آمن، واسترجاع كامل إذا ألغيت قبل قبول الفني
• إشعارات فورية بحالة طلبك

أنت فني؟ سجّل من التطبيق كفني واستقبل طلبات قريبة منك.
```

### Full description (English)

```
Thamer connects you with the nearest available technician in minutes, with a clear price before you order.

Services:
• Plumber: leaks, installation, maintenance
• Electrician: sockets, lighting, faults
• AC technician: split, window, cabinet, cassette and central units. Cleaning, gas refill, not cooling, leaks, installation, relocation
• Washing machine technician: front load, top load, twin tub, dryers. Not draining, not spinning, leaks, installation

How it works:
1. Choose a service, your device type and what it needs
2. Pick the job duration and see the price instantly: SAR 1.5 per minute
3. We send your request to the nearest technician; if they don't respond within two minutes it moves to the next one
4. Track your technician and reach them by call, WhatsApp or in-app chat
5. Confirm when the job is done

Free cancellation before a technician accepts. Technicians are verified before approval.
Are you a technician? Join from the app and receive nearby requests.
```

---

## Google Play ← Data safety

| نوع البيانات | يُجمع؟ | يُشارك؟ | الغرض | إلزامي؟ |
|---|---|---|---|---|
| الاسم | نعم | نعم (مع الطرف الآخر في الطلب) | وظائف التطبيق، إدارة الحساب | نعم |
| رقم الجوال | نعم | نعم (بعد قبول الطلب) | وظائف التطبيق، إدارة الحساب | نعم |
| البريد الإلكتروني | نعم | لا | إدارة الحساب | اختياري |
| الموقع الدقيق | نعم | نعم (مع الطرف الآخر في الطلب) | وظائف التطبيق | نعم |
| الصور | نعم (صورة الفني) | نعم (تظهر للعميل) | وظائف التطبيق | اختياري |
| رسائل داخل التطبيق | نعم | لا | وظائف التطبيق | اختياري |
| سجل المشتريات (Purchase history) | نعم | نعم (بوابة الدفع ميسّر) | وظائف التطبيق | نعم |
| معلومات مالية أخرى (آيبان الفني) | نعم | لا | وظائف التطبيق | للفني فقط |
| معرّفات أخرى (رقم الهوية/الإقامة) | نعم (للفنيين) | لا | منع الاحتيال والأمان | نعم للفني |
| معرّفات الجهاز (رمز الإشعارات) | نعم | لا | وظائف التطبيق | نعم |

- البيانات مشفّرة أثناء النقل: **نعم**
- يمكن للمستخدم طلب حذف بياناته: **نعم**، برابط صفحة حذف الحساب أعلاه.
- **Location permissions declaration**: التطبيق يستخدم الموقع **في المقدمة فقط** (Foreground)، فما يحتاج تصريح الموقع في الخلفية.

## Apple ← App Privacy

اختر **Data Linked to You** للبيانات التالية (لا شيء منها للتتبع أو الإعلانات، Tracking = No):

- **Contact Info**: Name، Phone Number، Email Address (Optional) ← App Functionality
- **Location**: Precise Location ← App Functionality
- **User Content**: Photos (Technicians)، Other User Content (Chat, request details) ← App Functionality
- **Financial Info**: Payment Info (IBAN for technicians), Purchases ← App Functionality. بيانات البطاقة تُعالج لدى ميسّر ولا تُحفظ عندنا.
- **Identifiers**: User ID، Device ID (push token) ← App Functionality
- **Sensitive Info**: National ID / Iqama (Technicians) ← App Functionality

---

## ملاحظات للمراجعين (App Review / Play review)

### قبلها في Firebase Console

Authentication ← Sign-in method ← Phone ← **Phone numbers for testing**:

| الرقم | الرمز | الدور |
|---|---|---|
| +966 50 000 0001 | 123456 | عميل (سجّله من التطبيق كعميل) |
| +966 50 000 0002 | 123456 | فني (سجّله كفني فني مكيفات، ثم اعتمده من حساب الأدمن) |

وفعّل حالة "متاح" للفني التجريبي وموقعه قريب من موقع الاختبار.

> 💡 سجّل فيديو قصير للدورة كاملة (طلب ← دفع ← قبول الفني ← إنهاء) وأرفقه مع ملاحظات المراجعة،
> لأن المراجع ما يقدر يدفع مبلغ حقيقي.

### النص اللي تلصقه في خانة Notes

```
Thamer connects customers with home-service technicians (plumber, electrician, AC, washing machine).

Sign-in uses phone number + SMS code. Test accounts (no real SMS is sent):
- Customer: +966 50 000 0001, code 123456
- Technician (pre-approved): +966 50 000 0002, code 123456

To test: sign in as the customer, choose a service, select options and send a request.
Sign in as the technician on a second device to accept it.

Location is used only while the app is in use: to find the nearest technician
and to show the technician's arrival to the customer.

Payments are for physical, real-world services performed at the customer's home
(App Store Guideline 3.1.3(e)), processed by the licensed Saudi gateway Moyasar
(card / Apple Pay / STC Pay). No digital content is sold. Completing a real payment is not needed to review
the app; a screen recording of the full paid flow is attached.

Account deletion: Account (person icon) → Delete account.
```

---

## الصور المطلوبة

| | المقاس | الحالة |
|---|---|---|
| أيقونة Google Play | 512×512 | ✅ `assets/branding/app_icon.png` (صغّرها إلى 512) |
| Feature graphic | 1024×500 | ✅ `store/play_feature_graphic.png` |
| لقطات أندرويد | 2–8 صور، عرض 1080 على الأقل | ⏳ صوّرها من الجوال |
| لقطات iPhone | 6.9" (1320×2868) أو 6.5" (1284×2778)، 3–10 صور | ⏳ صوّرها من محاكي iPhone 16 Pro Max |

التطبيق مضبوط **للآيفون فقط**، فما تحتاج لقطات iPad.

اقتراح للقطات بالترتيب:
1. الرئيسية (الخدمات الأربع)
2. طلب مكيف (اختيار النوع والمطلوب)
3. السعر والمدة
4. متابعة الطلب (الفني في الطريق)
5. المحادثة
6. لوحة الفني
