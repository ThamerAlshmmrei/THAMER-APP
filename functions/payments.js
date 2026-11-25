// الدفع عبر ميسّر (Moyasar).
//
// المفتاح السري لا يوضع في الكود. يُحفظ في Firebase Secret Manager:
//   firebase functions:secrets:set MOYASAR_SECRET_KEY
//   firebase functions:secrets:set MOYASAR_WEBHOOK_SECRET
const {defineSecret} = require("firebase-functions/params");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

const MOYASAR_SECRET_KEY = defineSecret("MOYASAR_SECRET_KEY");
const MOYASAR_WEBHOOK_SECRET = defineSecret("MOYASAR_WEBHOOK_SECRET");

// يمكن تغييره للاختبار المحلي فقط.
const MOYASAR_API_URL =
  process.env.MOYASAR_API_URL || "https://api.moyasar.com/v1";

const db = () => admin.firestore();

/**
 * Calls the Moyasar REST API with the secret key.
 * @param {string} method HTTP method.
 * @param {string} path API path, e.g. /payments/{id}.
 * @param {?Object} body JSON body.
 * @return {Promise<Object>} Parsed JSON response.
 */
async function moyasarRequest(method, path, body = null) {
  const key = MOYASAR_SECRET_KEY.value();

  if (!key) {
    throw new Error("MOYASAR_SECRET_KEY is not configured");
  }

  const response = await fetch(`${MOYASAR_API_URL}${path}`, {
    method,
    headers: {
      "Authorization": "Basic " + Buffer.from(`${key}:`).toString("base64"),
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    const error = new Error(
        `Moyasar ${method} ${path} failed: ${response.status} ` +
        `${data.message || ""}`,
    );
    error.status = response.status;
    throw error;
  }

  return data;
}

/**
 * Fetches a payment from Moyasar (never trust what the client sends).
 * @param {string} paymentId Moyasar payment id.
 * @return {Promise<Object>} Payment object.
 */
function fetchPayment(paymentId) {
  return moyasarRequest("GET", `/payments/${encodeURIComponent(paymentId)}`);
}

/**
 * Expected amount in halalas for a request.
 * @param {Object} request Request document data.
 * @return {number} Amount in halalas.
 */
function expectedHalalas(request) {
  return Math.round(Number(request.totalPrice) * 100);
}

/**
 * Refunds a payment fully.
 * @param {string} paymentId Moyasar payment id.
 * @return {Promise<Object>} Refunded payment.
 */
function refundPayment(paymentId) {
  return moyasarRequest(
      "POST",
      `/payments/${encodeURIComponent(paymentId)}/refund`,
  );
}

/**
 * Verifies a Moyasar payment and, if valid, marks the request as paid and
 * starts the technician search. Safe to call many times (callback + webhook).
 * @param {string} requestId Request id.
 * @param {Object} payment Payment fetched from Moyasar.
 * @return {Promise<string>} Outcome code.
 */
async function applyVerifiedPayment(requestId, payment) {
  const requestRef = db().collection("requests").doc(requestId);
  const metadataRequestId = payment.metadata && payment.metadata.request_id;

  if (metadataRequestId !== requestId) {
    logger.warn("Payment does not belong to request", {
      requestId,
      paymentId: payment.id,
    });
    return "mismatch";
  }

  if (payment.status !== "paid") {
    return `not_paid:${payment.status}`;
  }

  let refundDuplicate = false;

  const outcome = await db().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(requestRef);

    if (!snapshot.exists) return "not_found";

    const request = snapshot.data();

    if (
      payment.currency !== "SAR" ||
      payment.amount !== expectedHalalas(request)
    ) {
      logger.error("Payment amount mismatch", {
        requestId,
        paymentId: payment.id,
        paid: payment.amount,
        expected: expectedHalalas(request),
      });
      return "amount_mismatch";
    }

    if (request.paymentId === payment.id) return "already_applied";

    if (request.paymentStatus === "paid" || request.paymentId) {
      // دفعة ثانية لنفس الطلب: تُسترجع.
      refundDuplicate = true;
      return "duplicate";
    }

    if (request.status === "cancelled") {
      // ألغى العميل أثناء الدفع: نسجل الدفعة ثم نسترجعها.
      transaction.update(requestRef, {
        paymentId: payment.id,
        paymentStatus: "paid",
        paidAmount: payment.amount / 100,
        paidAt: FieldValue.serverTimestamp(),
      });
      refundDuplicate = true;
      return "cancelled";
    }

    if (request.status !== "awaiting_payment") return "unexpected_status";

    transaction.update(requestRef, {
      paymentId: payment.id,
      paymentStatus: "paid",
      paymentMethod: (payment.source && payment.source.type) || null,
      paidAmount: payment.amount / 100,
      paidAt: FieldValue.serverTimestamp(),
      status: "searching",
    });

    return "paid";
  });

  if (refundDuplicate) {
    try {
      await refundPayment(payment.id);
      if (outcome === "cancelled") {
        await requestRef.update({
          paymentStatus: "refunded",
          refundedAt: FieldValue.serverTimestamp(),
        });
      }
      logger.info("Extra payment refunded", {requestId, paymentId: payment.id});
    } catch (error) {
      logger.error("Refund of extra payment failed", {
        requestId,
        paymentId: payment.id,
        error: error.message,
      });
    }
  }

  logger.info("Payment processed", {requestId, paymentId: payment.id, outcome});

  return outcome;
}

/**
 * Refunds the payment of a cancelled request (if it was paid).
 * @param {FirebaseFirestore.DocumentReference} requestRef Request.
 * @param {Object} request Request data after cancellation.
 * @return {Promise<void>} Resolves when done.
 */
async function refundCancelledRequest(requestRef, request) {
  if (request.paymentStatus !== "paid" || !request.paymentId) return;

  try {
    await refundPayment(request.paymentId);
    await requestRef.update({
      paymentStatus: "refunded",
      refundedAt: FieldValue.serverTimestamp(),
    });
    logger.info("Cancelled request refunded", {requestId: requestRef.id});
  } catch (error) {
    // يظهر للأدمن في لوحة المدفوعات ليسترجعه يدوياً من لوحة ميسّر.
    await requestRef.update({
      paymentStatus: "refund_failed",
      refundError: String(error.message || error).slice(0, 300),
    });
    logger.error("Refund failed", {
      requestId: requestRef.id,
      error: error.message,
    });
  }
}

/**
 * Records the technician's earning when a paid request is completed.
 * @param {FirebaseFirestore.DocumentReference} requestRef Request.
 * @param {Object} request Request data.
 * @return {Promise<void>} Resolves when done.
 */
async function recordTechnicianEarning(requestRef, request) {
  if (request.paymentStatus !== "paid" || !request.technicianId) return;

  const amount =
    Number(request.laborCost || 0) + Number(request.materialsCost || 0);

  try {
    await db().collection("technicianEarnings").doc(requestRef.id).create({
      requestId: requestRef.id,
      technicianId: request.technicianId,
      technicianName: request.technicianName || "",
      serviceType: request.serviceType || "",
      amount,
      appFee: Number(request.appFee || 0),
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    // ALREADY_EXISTS: سُجلت مسبقاً (تشغيل مكرر للـ trigger).
    if (error.code !== 6) throw error;
  }
}

module.exports = {
  MOYASAR_SECRET_KEY,
  MOYASAR_WEBHOOK_SECRET,
  fetchPayment,
  applyVerifiedPayment,
  refundCancelledRequest,
  recordTechnicianEarning,
};
