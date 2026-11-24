const {setGlobalOptions} = require("firebase-functions/v2");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const {onTaskDispatched} = require("firebase-functions/v2/tasks");
const {getFunctions} = require("firebase-admin/functions");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

admin.initializeApp();

const db = admin.firestore();

setGlobalOptions({
  region: "me-central2",
  maxInstances: 10,
});
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
// جلب بيانات العميل
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

const customerData = customerSnapshot.data();
  const techniciansSnapshot = await db
      .collection("technicians")
      .where("serviceType", "==", request.serviceType)
      .where("available", "==", true)
      .get();

  const candidates = [];
  logger.info("DEBUG TECHNICIAN QUERY", {
  serviceType: request.serviceType,
  availableCount: techniciansSnapshot.size,
  technicianIds: techniciansSnapshot.docs.map((doc) => doc.id),
});
  logger.info("Technician search results", {
  requestId: requestRef.id,
  serviceType: request.serviceType,
  techniciansFound: techniciansSnapshot.size,
  customerLatitude: request.customerLatitude,
  customerLongitude: request.customerLongitude,
});

  for (const doc of techniciansSnapshot.docs) {
    const tech = doc.data();
    logger.info("Checking technician", {
  technicianId: doc.id,
  available: tech.available,
  serviceType: tech.serviceType,
  latitude: tech.latitude,
  longitude: tech.longitude,
});

    if (attempted.includes(doc.id)) continue;

    if (
      typeof tech.latitude !== "number" ||
      typeof tech.longitude !== "number"
    ) {
      continue;
    }

    const userSnapshot = await db
        .collection("users")
        .doc(doc.id)
        .get();

    if (!userSnapshot.exists ||
    userSnapshot.data().role !== "technician") {
  continue;
}

;

    const distance = calculateDistance(
        request.customerLatitude,
        request.customerLongitude,
        tech.latitude,
        tech.longitude,
    );

   candidates.push({
  id: doc.id,
  ref: doc.ref,
  distance,
});
  }

  candidates.sort((a, b) => a.distance - b.distance);
  const timeoutQueue = getFunctions().taskQueue(
  "locations/me-central2/functions/expireTechnicianOffer"
);

  for (const candidate of candidates) {
    const offerToken =
  `${requestRef.id}_${candidate.id}_${Date.now()}`;
    try {
      await timeoutQueue.enqueue(
  {
    requestId: requestRef.id,
    technicianId: candidate.id,
    offerToken,
  },
  { scheduleDelaySeconds: 120 },
);
      const assigned = await db.runTransaction(async (transaction) => {
        const freshRequest = await transaction.get(requestRef);
        const freshTechnician = await transaction.get(candidate.ref);

        let previousRef = null;
        let previousSnapshot = null;

        if (previousTechnicianId &&
            previousTechnicianId !== candidate.id) {
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

        const freshAttempted =
          freshData.attemptedTechnicianIds || [];

        if (freshAttempted.includes(candidate.id)) return false;

        if (
          techData.available !== true ||
          (techData.currentRequestId != null &&
           techData.currentRequestId !== requestRef.id)
        ) {
          return false;
        }

        if (
          previousSnapshot &&
          previousSnapshot.exists &&
          previousSnapshot.data().currentRequestId === requestRef.id
        ) {
          transaction.update(previousRef, {
            currentRequestId: null,
            available: true,
          });
        }

        transaction.update(candidate.ref, {
  currentRequestId: requestRef.id,
  available: false,
});

       transaction.update(requestRef, {
  technicianId: candidate.id,
  status: "offered",

  // بيانات العميل
 

  // بيانات الفني
 
 
  attemptedTechnicianIds: [
    ...freshAttempted,
    candidate.id,
  ],

  offeredAt: FieldValue.serverTimestamp(),
  offerToken,
});

        return true;
      });

      if (assigned) {
        logger.info("Request assigned", {
          requestId: requestRef.id,
          technicianId: candidate.id,
          distanceKm: candidate.distance,
        });
        return;
      }
    } catch (error) {
      logger.error("Technician assignment failed", error);
    }
  }

  // No eligible technician remains.
  await db.runTransaction(async (transaction) => {
    const freshRequest = await transaction.get(requestRef);

    if (!freshRequest.exists ||
        freshRequest.data().status !== expectedStatus) {
      return;
    }

    if (previousTechnicianId) {
      const previousRef = db.collection("technicians")
          .doc(previousTechnicianId);
      const previousSnapshot = await transaction.get(previousRef);

      if (
        previousSnapshot.exists &&
        previousSnapshot.data().currentRequestId === requestRef.id
      ) {
        transaction.update(previousRef, {
          currentRequestId: null,
          available: true,
        });
      }
    }

    transaction.update(requestRef, {
      technicianId: null,
      status: "no_technician_available",
    });
  });

  logger.info("No technician available", {
    requestId: requestRef.id,
  });
}

// First dispatch when a customer creates a request.
exports.dispatchNewRequest = onDocumentCreated(
    "requests/{requestId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const request = snapshot.data();

      if (request.status !== "searching") return;

      await assignNextTechnician(
          snapshot.ref,
          "searching",
      );
    },
);

// Dispatch to the next technician after rejection.
// Also reserve the technician's availability after acceptance.
exports.handleRequestUpdate = onDocumentUpdated(
    "requests/{requestId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const requestRef = event.data.after.ref;

      // Technician rejects: assign the next technician.
      if (
        before.status !== "rejected" &&
      after.status === "rejected"
      ) {
        await assignNextTechnician(
            requestRef,
            "rejected",
            after.technicianId,
        );
        return;
      }

      // Technician accepts: reveal contact details and mark unavailable.
      if (
        before.status !== "accepted" &&
        after.status === "accepted" &&
        after.technicianId
      ) {
        const technicianRef = db
          .collection("technicians")
          .doc(after.technicianId);

        // Get both users and the technician's latest location.
       const [customerSnapshot, technicianUserSnapshot] =
  await Promise.all([
    db.collection("users").doc(after.customerId).get(),
    db.collection("users").doc(after.technicianId).get(),
  ]);

        const customerData = customerSnapshot.exists
          ? customerSnapshot.data()
          : {};

        const technicianUserData = technicianUserSnapshot.exists
          ? technicianUserSnapshot.data()
          : {};
          

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
            transaction.update(technicianRef, {
              available: false,
            });
          }
        });

        logger.info("Request accepted", {
          requestId: requestRef.id,
          technicianId: after.technicianId,
        });
        return;
      
      }

      // Customer confirms service completion:
      // release the technician.
      if (
        before.status === "waiting_customer_confirmation" &&
      after.status === "completed" &&
      after.technicianId
      ) {
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

          if (
            technician.exists &&
          technician.data().currentRequestId === requestRef.id
          ) {
            transaction.update(technicianRef, {
              available: true,
              currentRequestId: null,
            });
          }
        });

        logger.info("Request completed by both parties", {
          requestId: requestRef.id,
          technicianId: after.technicianId,
        });
      }
    },
);
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

      // لا تنتهي المهلة إذا تغير الفني أو قبل الطلب.
      if (
        request.status !== "offered" ||
        request.technicianId !== technicianId ||
        request.offerToken !== offerToken
      ) {
        return;
      }

      // انتهاء مهلة الفني الحالي.
      transaction.update(requestRef, {
        status: "rejected",
        rejectedAt: FieldValue.serverTimestamp(),
      });

      logger.info("Technician offer expired", {
        requestId,
        technicianId,
      });
    });
  },
);