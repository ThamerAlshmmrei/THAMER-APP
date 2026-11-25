const {setGlobalOptions} = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onTaskDispatched} = require("firebase-functions/v2/tasks");
const {
  onCall,
  onRequest,
  HttpsError,
} = require("firebase-functions/v2/https");
const {getFunctions} = require("firebase-admin/functions");
const {getMessaging} = require("firebase-admin/messaging");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

admin.initializeApp();

const payments = require("./payments");

const db = admin.firestore();

const REGION = "me-central2";

// مهلة رد الفني على الطلب (بالثواني).
const OFFER_TIMEOUT_SECONDS = 120;

// إذا أنهى الفني العمل ولم يؤكد العميل، يُعتمد الطلب تلقائياً بعد هذه المدة.
const AUTO_CONFIRM_SECONDS = 3 * 60 * 60;

setGlobalOptions({
  region: REGION,
  maxInstances: 10,
});

const SERVICE_NAMES = {
  plumber: "سباكة",
  electrician: "كهرباء",
  ac: "مكيفات",
  washing_machine: "غسالات",
};

/**
 * Calculates the distance between two GPS locations in kilometers.
 * @param {number} lat1 First latitude.
 * @param {number} lon1 First longitude.
 * @param {number} lat2 Second latitude.
 * @param {number} lon2 Second longitude.
 * @return {number} Distance in kilometers.
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const toRadians = (value) => (value * Math.PI) / 180;
  const earthRadius = 6371;

  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) ** 2;

  return 2 * earthRadius *
    Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Sends a push notification to a user if they registered a device token.
 * Failures are logged and never break the request flow.
 * @param {?string} uid Target user id.
 * @param {string} title Notification title.
 * @param {string} body Notification body.
 * @param {Object<string, string>} data Extra payload.
 * @return {Promise<void>} Resolves when done.
 */
async function notifyUser(uid, title, body, data = {}) {
  if (!uid) return;

  try {
    const userSnapshot = await db.collection("users").doc(uid).get();
    const token = userSnapshot.exists ?
      userSnapshot.data().fcmToken :
      null;

    if (typeof token !== "string" || token.length === 0) return;

    await getMessaging().send({
      token,
      notification: {title, body},
      data,
      android: {
        priority: "high",
        notification: {sound: "default"},
      },
      apns: {
        payload: {aps: {sound: "default"}},
      },
    });
  } catch (error) {
    logger.warn("Push notification failed", {uid, error: error.message});
  }
}

/**
 * Releases a technician that is reserved for the given request.
 * Must be called inside a transaction after all reads are done.
 * @param {FirebaseFirestore.Transaction} transaction Active transaction.
 * @param {FirebaseFirestore.DocumentReference} technicianRef Technician.
 * @param {FirebaseFirestore.DocumentSnapshot} technicianSnapshot Snapshot.
 * @param {string} requestId Request id.
 */
function releaseTechnician(
    transaction,
    technicianRef,
    technicianSnapshot,
    requestId,
) {
  if (
    technicianSnapshot.exists &&
    technicianSnapshot.data().currentRequestId === requestId
  ) {
    transaction.update(technicianRef, {
      currentRequestId: null,
      available: true,
    });
  }
}

/**
 * Finds and assigns the nearest eligible technician to a request.
 * @param {FirebaseFirestore.DocumentReference} requestRef Request document.
 * @param {string} expectedStatus Expected request status.
 * @param {?string} previousTechnicianId Previously assigned technician.
 * @return {Promise<void>} Resolves when assignment is completed.
 */
async function assignNextTechnician(
    requestRef,
    expectedStatus,
    previousTechnicianId = null,
) {
  const requestSnapshot = await requestRef.get();

  if (!requestSnapshot.exists) return;

  const request = requestSnapshot.data();

  if (request.status !== expectedStatus) return;

  const attempted = request.attemptedTechnicianIds || [];

  const customerSnapshot = await db
      .collection("users")
      .doc(request.customerId)
      .get();

  if (
    !customerSnapshot.exists ||
    customerSnapshot.data().role !== "customer"
  ) {
    logger.error("Customer profile not found", {
      customerId: request.customerId,
    });
    return;
  }

  const techniciansSnapshot = await db
      .collection("technicians")
      .where("serviceType", "==", request.serviceType)
      .where("available", "==", true)
      .get();

  logger.info("Technician search results", {
    requestId: requestRef.id,
    serviceType: request.serviceType,
    techniciansFound: techniciansSnapshot.size,
  });

  const candidates = [];

  for (const doc of techniciansSnapshot.docs) {
    const tech = doc.data();

    if (attempted.includes(doc.id)) continue;

    if (
      typeof tech.latitude !== "number" ||
      typeof tech.longitude !== "number"
    ) {
      continue;
    }

    const userSnapshot = await db.collection("users").doc(doc.id).get();

    if (
      !userSnapshot.exists ||
      userSnapshot.data().role !== "technician"
    ) {
      continue;
    }

    candidates.push({
      id: doc.id,
      ref: doc.ref,
      distance: calculateDistance(
          request.customerLatitude,
          request.customerLongitude,
          tech.latitude,
          tech.longitude,
      ),
    });
  }

  candidates.sort((a, b) => a.distance - b.distance);

  const timeoutQueue = getFunctions().taskQueue(
      `locations/${REGION}/functions/expireTechnicianOffer`,
  );

  for (const candidate of candidates) {
    const offerToken = `${requestRef.id}_${candidate.id}_${Date.now()}`;

    try {
      const assigned = await db.runTransaction(async (transaction) => {
        const freshRequest = await transaction.get(requestRef);
        const freshTechnician = await transaction.get(candidate.ref);

        let previousRef = null;
        let previousSnapshot = null;

        if (
          previousTechnicianId &&
          previousTechnicianId !== candidate.id
        ) {
          previousRef = db.collection("technicians")
              .doc(previousTechnicianId);
          previousSnapshot = await transaction.get(previousRef);
        }

        if (!freshRequest.exists || !freshTechnician.exists) {
          return false;
        }

        const freshData = freshRequest.data();
        const techData = freshTechnician.data();

        if (freshData.status !== expectedStatus) return false;

        const freshAttempted = freshData.attemptedTechnicianIds || [];

        if (freshAttempted.includes(candidate.id)) return false;

        if (
          techData.available !== true ||
          (techData.currentRequestId != null &&
            techData.currentRequestId !== requestRef.id)
        ) {
          return false;
        }

        if (previousSnapshot) {
          releaseTechnician(
              transaction,
              previousRef,
              previousSnapshot,
              requestRef.id,
          );
        }

        transaction.update(candidate.ref, {
          currentRequestId: requestRef.id,
          available: false,
        });

        transaction.update(requestRef, {
          technicianId: candidate.id,
          status: "offered",
          attemptedTechnicianIds: [...freshAttempted, candidate.id],
          offeredAt: FieldValue.serverTimestamp(),
          offerToken,
        });

        return true;
      });

      if (assigned) {
        try {
          await timeoutQueue.enqueue(
              {
                requestId: requestRef.id,
                technicianId: candidate.id,
                offerToken,
              },
              {scheduleDelaySeconds: OFFER_TIMEOUT_SECONDS},
          );
        } catch (error) {
          logger.error("Could not schedule offer timeout", error);
        }

        logger.info("Request offered to technician", {
          requestId: requestRef.id,
          technicianId: candidate.id,
          distanceKm: candidate.distance,
        });

        const serviceName = SERVICE_NAMES[request.serviceType] || "";

        await notifyUser(
            candidate.id,
            "طلب خدمة جديد",
            `طلب ${serviceName} على بعد ` +
              `${candidate.distance.toFixed(1)} كم، ` +
              "لديك دقيقتان للرد",
            {requestId: requestRef.id, type: "new_offer"},
        );
        return;
      }
    } catch (error) {
      logger.error("Technician assignment failed", error);
    }
  }

  // No eligible technician remains.
  const marked = await db.runTransaction(async (transaction) => {
    const freshRequest = await transaction.get(requestRef);

    let previousRef = null;
    let previousSnapshot = null;

    if (previousTechnicianId) {
      previousRef = db.collection("technicians").doc(previousTechnicianId);
      previousSnapshot = await transaction.get(previousRef);
    }

    if (
      !freshRequest.exists ||
      freshRequest.data().status !== expectedStatus
    ) {
      return false;
    }

    if (previousSnapshot) {
      releaseTechnician(
          transaction,
          previousRef,
          previousSnapshot,
          requestRef.id,
      );
    }

    transaction.update(requestRef, {
      technicianId: null,
      status: "no_technician_available",
    });

    return true;
  });

  if (marked) {
    logger.info("No technician available", {requestId: requestRef.id});

    await notifyUser(
        request.customerId,
        "لا يوجد فني متاح حالياً",
        "تقدر تعيد البحث من صفحة الطلب بعد قليل",
        {requestId: requestRef.id, type: "no_technician"},
    );
  }
}

// First dispatch when a customer creates a request.
exports.dispatchNewRequest = onDocumentCreated(
    "requests/{requestId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const request = snapshot.data();

      if (request.status !== "searching") return;

      await assignNextTechnician(snapshot.ref, "searching");
    },
);

// Reacts to every status change of a request.
exports.handleRequestUpdate = onDocumentUpdated(
    {
      document: "requests/{requestId}",
      secrets: [payments.MOYASAR_SECRET_KEY],
    },
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const requestRef = event.data.after.ref;

      if (before.status === after.status) return;

      // Payment verified: start searching for a technician.
      if (
        before.status === "awaiting_payment" &&
        after.status === "searching"
      ) {
        await assignNextTechnician(requestRef, "searching");
        return;
      }

      // Technician rejects (or offer expired): assign the next technician.
      if (after.status === "rejected") {
        await assignNextTechnician(
            requestRef,
            "rejected",
            after.technicianId,
        );
        return;
      }

      // Customer retries after no technician was available.
      if (
        before.status === "no_technician_available" &&
        after.status === "searching"
      ) {
        await requestRef.update({attemptedTechnicianIds: []});
        await assignNextTechnician(requestRef, "searching");
        return;
      }

      // Customer cancels: release the reserved technician, if any.
      if (after.status === "cancelled") {
        const technicianId = after.technicianId || before.technicianId;

        if (technicianId) {
          const technicianRef = db.collection("technicians")
              .doc(technicianId);

          await db.runTransaction(async (transaction) => {
            const technician = await transaction.get(technicianRef);
            releaseTechnician(
                transaction,
                technicianRef,
                technician,
                requestRef.id,
            );
          });

          if (before.status === "offered") {
            await notifyUser(
                technicianId,
                "تم إلغاء الطلب",
                "قام العميل بإلغاء الطلب",
                {requestId: requestRef.id, type: "cancelled"},
            );
          }
        }

        await payments.refundCancelledRequest(requestRef, after);

        logger.info("Request cancelled", {requestId: requestRef.id});
        return;
      }

      // Technician accepts: reveal contact details and mark unavailable.
      if (after.status === "accepted" && after.technicianId) {
        const technicianRef = db
            .collection("technicians")
            .doc(after.technicianId);

        const [customerSnapshot, technicianUserSnapshot] =
          await Promise.all([
            db.collection("users").doc(after.customerId).get(),
            db.collection("users").doc(after.technicianId).get(),
          ]);

        const customerData = customerSnapshot.exists ?
          customerSnapshot.data() :
          {};

        const technicianUserData = technicianUserSnapshot.exists ?
          technicianUserSnapshot.data() :
          {};

        // Reveal contact details only after acceptance.
        await requestRef.update({
          customerName: customerData.name || "",
          customerPhone: customerData.phone || "",
          technicianName: technicianUserData.name || "",
          technicianPhone: technicianUserData.phone || "",
          technicianImageUrl: technicianUserData.profileImageUrl || null,
        });

        await db.runTransaction(async (transaction) => {
          const technician = await transaction.get(technicianRef);

          if (
            technician.exists &&
            technician.data().currentRequestId === requestRef.id
          ) {
            transaction.update(technicianRef, {available: false});
          }
        });

        logger.info("Request accepted", {
          requestId: requestRef.id,
          technicianId: after.technicianId,
        });

        await notifyUser(
            after.customerId,
            "تم قبول طلبك",
            `الفني ${technicianUserData.name || ""} في الطريق إليك`.trim(),
            {requestId: requestRef.id, type: "accepted"},
        );
        return;
      }

      // Technician finished: ask the customer to confirm, with a fallback.
      if (after.status === "waiting_customer_confirmation") {
        try {
          await getFunctions()
              .taskQueue(
                  `locations/${REGION}/functions/autoConfirmCompletion`,
              )
              .enqueue(
                  {requestId: requestRef.id},
                  {scheduleDelaySeconds: AUTO_CONFIRM_SECONDS},
              );
        } catch (error) {
          logger.error("Could not schedule auto confirmation", error);
        }

        await notifyUser(
            after.customerId,
            "الفني أنهى العمل",
            "فضلاً أكّد انتهاء الخدمة من التطبيق",
            {requestId: requestRef.id, type: "waiting_confirmation"},
        );
        return;
      }

      // Service completed: release the technician.
      if (after.status === "completed" && after.technicianId) {
        const technicianRef = db
            .collection("technicians")
            .doc(after.technicianId);

        await db.runTransaction(async (transaction) => {
          const requestSnapshot = await transaction.get(requestRef);
          const technician = await transaction.get(technicianRef);

          if (
            !requestSnapshot.exists ||
            requestSnapshot.data().status !== "completed"
          ) {
            return;
          }

          releaseTechnician(
              transaction,
              technicianRef,
              technician,
              requestRef.id,
          );
        });

        await payments.recordTechnicianEarning(requestRef, after);

        logger.info("Request completed", {
          requestId: requestRef.id,
          technicianId: after.technicianId,
        });

        await notifyUser(
            after.technicianId,
            "اكتمل الطلب",
            "تم تأكيد انتهاء الخدمة، أنت الآن متاح لطلبات جديدة",
            {requestId: requestRef.id, type: "completed"},
        );
      }
    },
);

// Moves an unanswered offer to the next technician.
exports.expireTechnicianOffer = onTaskDispatched(
    {
      retryConfig: {
        maxAttempts: 5,
        minBackoffSeconds: 10,
      },
      rateLimits: {
        maxConcurrentDispatches: 10,
      },
    },
    async (req) => {
      const {requestId, technicianId, offerToken} = req.data;

      if (!requestId || !technicianId || !offerToken) {
        logger.error("Invalid technician offer timeout task", {
          requestId,
          technicianId,
        });
        return;
      }

      const requestRef = db.collection("requests").doc(requestId);

      await db.runTransaction(async (transaction) => {
        const requestSnapshot = await transaction.get(requestRef);

        if (!requestSnapshot.exists) return;

        const request = requestSnapshot.data();

        // لا تنتهي المهلة إذا تغير الفني أو قُبل الطلب.
        if (
          request.status !== "offered" ||
          request.technicianId !== technicianId ||
          request.offerToken !== offerToken
        ) {
          return;
        }

        transaction.update(requestRef, {
          status: "rejected",
          rejectedAt: FieldValue.serverTimestamp(),
        });

        logger.info("Technician offer expired", {requestId, technicianId});
      });
    },
);

// Confirms the job automatically if the customer never confirmed it,
// so the technician is not blocked from new requests.
exports.autoConfirmCompletion = onTaskDispatched(
    {
      retryConfig: {
        maxAttempts: 5,
        minBackoffSeconds: 30,
      },
      rateLimits: {
        maxConcurrentDispatches: 10,
      },
    },
    async (req) => {
      const {requestId} = req.data;
      if (!requestId) return;

      const requestRef = db.collection("requests").doc(requestId);

      await db.runTransaction(async (transaction) => {
        const requestSnapshot = await transaction.get(requestRef);

        if (
          !requestSnapshot.exists ||
          requestSnapshot.data().status !== "waiting_customer_confirmation"
        ) {
          return;
        }

        transaction.update(requestRef, {
          status: "completed",
          autoConfirmed: true,
          customerConfirmedAt: FieldValue.serverTimestamp(),
        });
      });

      logger.info("Request auto confirmed", {requestId});
    },
);

const ACTIVE_STATUSES = [
  "awaiting_payment",
  "searching",
  "offered",
  "rejected",
  "accepted",
  "waiting_customer_confirmation",
];

/**
 * Applies the same update to many documents in batches of 400.
 * @param {FirebaseFirestore.QueryDocumentSnapshot[]} docs Documents.
 * @param {?Object} data Update data, or null to delete the documents.
 * @return {Promise<void>} Resolves when all batches are committed.
 */
async function batchWrite(docs, data) {
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    for (const doc of docs.slice(i, i + 400)) {
      if (data === null) {
        batch.delete(doc.ref);
      } else {
        batch.update(doc.ref, data);
      }
    }
    await batch.commit();
  }
}

// حذف الحساب نهائياً (مطلوب من Apple و Google Play).
// يحذف بيانات المستخدم ويُخفي اسمه ورقمه من الطلبات السابقة،
// ويرفض الحذف إذا كان عنده طلب جاري.
// بعد تفعيل App Check في Console يمكن إضافة {enforceAppCheck: true}.
exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "سجّل الدخول أولاً");
  }

  const [asCustomer, asTechnician, technicianSnapshot] = await Promise.all([
    db.collection("requests")
        .where("customerId", "==", uid)
        .get(),
    db.collection("requests")
        .where("technicianId", "==", uid)
        .get(),
    db.collection("technicians").doc(uid).get(),
  ]);

  const hasActive = [...asCustomer.docs, ...asTechnician.docs].some(
      (doc) => ACTIVE_STATUSES.includes(doc.data().status),
  );

  if (
    hasActive ||
    (technicianSnapshot.exists &&
      technicianSnapshot.data().currentRequestId)
  ) {
    throw new HttpsError(
        "failed-precondition",
        "لديك طلب جاري. أنهِ الطلب أو ألغه ثم احذف الحساب.",
    );
  }

  const pendingEarnings = await db.collection("technicianEarnings")
      .where("technicianId", "==", uid)
      .where("status", "==", "pending")
      .limit(1)
      .get();

  if (!pendingEarnings.empty) {
    throw new HttpsError(
        "failed-precondition",
        "لك مستحقات لم تُحوّل بعد. تواصل مع الدعم لتحويلها ثم احذف الحساب.",
    );
  }

  // إخفاء البيانات الشخصية من الطلبات السابقة.
  await batchWrite(asCustomer.docs, {
    customerName: "",
    customerPhone: "",
    customerLatitude: null,
    customerLongitude: null,
    problemDescription: "",
    customerDeleted: true,
  });

  await batchWrite(asTechnician.docs, {
    technicianName: "",
    technicianPhone: "",
    technicianImageUrl: null,
    technicianDeleted: true,
  });

  // حذف رسائل المحادثة التي كتبها المستخدم.
  const messages = await db.collectionGroup("messages")
      .where("senderId", "==", uid)
      .get();
  await batchWrite(messages.docs, null);

  await Promise.all([
    db.collection("users").doc(uid).delete(),
    db.collection("technicians").doc(uid).delete(),
    db.collection("technicianApplications").doc(uid).delete(),
  ]);

  try {
    await admin.storage().bucket().deleteFiles({
      prefix: `technician_profiles/${uid}/`,
    });
  } catch (error) {
    logger.warn("Could not delete profile images", {uid, error});
  }

  await admin.auth().deleteUser(uid);

  logger.info("Account deleted", {uid});

  return {deleted: true};
});

// يستدعيه التطبيق بعد نجاح الدفع: يتحقق من الدفعة عند ميسّر ثم يبدأ البحث.
exports.confirmPayment = onCall(
    {secrets: [payments.MOYASAR_SECRET_KEY]},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      const {requestId, paymentId} = request.data || {};

      if (!uid) {
        throw new HttpsError("unauthenticated", "سجّل الدخول أولاً");
      }

      if (typeof requestId !== "string" || typeof paymentId !== "string") {
        throw new HttpsError("invalid-argument", "بيانات الدفع ناقصة");
      }

      const snapshot = await db.collection("requests").doc(requestId).get();

      if (!snapshot.exists || snapshot.data().customerId !== uid) {
        throw new HttpsError("not-found", "الطلب غير موجود");
      }

      let payment;
      try {
        payment = await payments.fetchPayment(paymentId);
      } catch (error) {
        logger.error("Could not fetch payment", {
          requestId,
          paymentId,
          error: error.message,
        });
        throw new HttpsError(
            "unavailable",
            "تعذر التحقق من الدفع الآن، بنعيد المحاولة تلقائياً",
        );
      }

      const outcome = await payments.applyVerifiedPayment(requestId, payment);

      if (outcome === "paid" || outcome === "already_applied") {
        return {status: "paid"};
      }

      if (outcome.startsWith("not_paid")) {
        throw new HttpsError("failed-precondition", "لم تكتمل عملية الدفع");
      }

      if (outcome === "duplicate" || outcome === "cancelled") {
        return {status: outcome};
      }

      throw new HttpsError("failed-precondition", "تعذر اعتماد الدفعة");
    },
);

// Webhook من ميسّر: نسخة احتياطية لو انقطع التطبيق بعد الدفع.
// الرابط في لوحة ميسّر:
// https://me-central2-thamer-e0fdd.cloudfunctions.net/moyasarWebhook
exports.moyasarWebhook = onRequest(
    {secrets: [payments.MOYASAR_SECRET_KEY, payments.MOYASAR_WEBHOOK_SECRET]},
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).send("Method not allowed");
        return;
      }

      const event = req.body || {};
      const expectedSecret = payments.MOYASAR_WEBHOOK_SECRET.value();

      if (!expectedSecret || event.secret_token !== expectedSecret) {
        logger.warn("Webhook rejected: bad secret token");
        res.status(401).send("Unauthorized");
        return;
      }

      const data = event.data || {};
      const requestId = data.metadata && data.metadata.request_id;

      if (event.type !== "payment_paid" || !data.id || !requestId) {
        res.status(200).send("ignored");
        return;
      }

      try {
        // نعيد جلب الدفعة من ميسّر بدل الثقة بمحتوى الطلب.
        const payment = await payments.fetchPayment(data.id);
        await payments.applyVerifiedPayment(requestId, payment);
        res.status(200).send("ok");
      } catch (error) {
        logger.error("Webhook processing failed", {error: error.message});
        res.status(500).send("error");
      }
    },
);

// الأدمن يسجل أنه حوّل مستحقات فني (تحويل بنكي خارج التطبيق).
exports.recordPayout = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;

  if (!uid) {
    throw new HttpsError("unauthenticated", "سجّل الدخول أولاً");
  }

  const adminSnapshot = await db.collection("users").doc(uid).get();

  if (!adminSnapshot.exists || adminSnapshot.data().role !== "admin") {
    throw new HttpsError("permission-denied", "للأدمن فقط");
  }

  const {technicianId, reference} = request.data || {};

  if (typeof technicianId !== "string" || technicianId.length === 0) {
    throw new HttpsError("invalid-argument", "الفني غير محدد");
  }

  const pending = await db.collection("technicianEarnings")
      .where("technicianId", "==", technicianId)
      .where("status", "==", "pending")
      .get();

  if (pending.empty) {
    throw new HttpsError("failed-precondition", "لا توجد مستحقات معلقة");
  }

  const total = pending.docs.reduce(
      (sum, doc) => sum + Number(doc.data().amount || 0),
      0,
  );

  const payoutRef = db.collection("payouts").doc();
  const technicianSnapshot = await db.collection("technicians")
      .doc(technicianId)
      .get();
  const technician = technicianSnapshot.exists ?
    technicianSnapshot.data() :
    {};

  const docs = pending.docs;
  for (let i = 0; i < docs.length; i += 400) {
    const batch = db.batch();
    for (const doc of docs.slice(i, i + 400)) {
      batch.update(doc.ref, {
        status: "paid_out",
        payoutId: payoutRef.id,
        paidOutAt: FieldValue.serverTimestamp(),
      });
    }
    if (i === 0) {
      batch.set(payoutRef, {
        technicianId,
        amount: Math.round(total * 100) / 100,
        count: docs.length,
        iban: technician.iban || null,
        reference: typeof reference === "string" ?
          reference.slice(0, 100) :
          "",
        createdBy: uid,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  await notifyUser(
      technicianId,
      "تم تحويل مستحقاتك",
      `تم تحويل ${total.toFixed(2)} ريال إلى حسابك البنكي`,
      {type: "payout"},
  );

  return {amount: total, count: docs.length};
});
