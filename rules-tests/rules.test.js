// اختبارات قواعد Firestore. التشغيل: npm test (يحتاج Java).
const {test, before, after, beforeEach} = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const {
  doc, setDoc, updateDoc, getDoc, serverTimestamp,
} = require("firebase/firestore");

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-thamer",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8081,
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/cust"), {uid: "cust", role: "customer", createdAt: new Date()});
    await setDoc(doc(db, "users/tech"), {uid: "tech", role: "technician", createdAt: new Date()});
    await setDoc(doc(db, "users/admin"), {uid: "admin", role: "admin", createdAt: new Date()});
  });
});

// نفس حساب التطبيق (lib/core/pricing.dart)
function pricing(minutes) {
  const laborCost = minutes * 1.5;
  const halalas = Math.floor(laborCost * 15);
  const appFee = halalas >= 500 ? halalas / 100.0 : 5.0;
  return {laborCost, appFee, totalPrice: laborCost + appFee + 0.0};
}

function newRequest(minutes, extra = {}) {
  const p = pricing(minutes);
  return {
    requestId: "r1",
    customerId: "cust",
    technicianId: null,
    serviceType: "plumber",
    customerLatitude: 24.7,
    customerLongitude: 46.7,
    requestType: "technician_only",
    problemDescription: "تسريب",
    durationMinutes: minutes,
    materials: [],
    laborCost: p.laborCost,
    appFee: p.appFee,
    materialsCost: 0.0,
    totalPrice: p.totalPrice,
    status: "searching",
    createdAt: serverTimestamp(),
    ...extra,
  };
}

const customerDb = () => env.authenticatedContext("cust").firestore();

test("fee formula matches the rules for every duration 5..120", async () => {
  for (let m = 5; m <= 120; m++) {
    await assertSucceeds(
        setDoc(doc(customerDb(), `requests/r${m}`), newRequest(m)),
    );
  }
});

test("old flat fee is rejected for long jobs", async () => {
  await assertFails(setDoc(doc(customerDb(), "requests/r1"),
      newRequest(60, {appFee: 5.0, totalPrice: 95.0})));
});

test("AC request requires device and issue", async () => {
  await assertFails(setDoc(doc(customerDb(), "requests/r1"),
      newRequest(30, {serviceType: "ac"})));
  await assertSucceeds(setDoc(doc(customerDb(), "requests/r1"),
      newRequest(30, {
        serviceType: "ac", deviceType: "سبليت", issueType: "تعبئة فريون",
      })));
});

test("washing machine request with details succeeds", async () => {
  await assertSucceeds(setDoc(doc(customerDb(), "requests/r1"),
      newRequest(45, {
        serviceType: "washing_machine",
        deviceType: "أوتوماتيك تحميل أمامي",
        issueType: "لا تصرّف الماء",
      })));
});

test("unknown service type is rejected", async () => {
  await assertFails(setDoc(doc(customerDb(), "requests/r1"),
      newRequest(30, {serviceType: "carpenter"})));
});

async function seedRequest(status, technicianId = null) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "requests/r1"),
        {...newRequest(30), status, technicianId, createdAt: new Date()});
  });
}

test("customer can cancel before acceptance", async () => {
  await seedRequest("offered", "tech");
  await assertSucceeds(updateDoc(doc(customerDb(), "requests/r1"),
      {status: "cancelled", cancelledAt: serverTimestamp()}));
});

test("customer cannot cancel after acceptance", async () => {
  await seedRequest("accepted", "tech");
  await assertFails(updateDoc(doc(customerDb(), "requests/r1"),
      {status: "cancelled", cancelledAt: serverTimestamp()}));
});

test("customer can retry only when no technician was available", async () => {
  await seedRequest("no_technician_available");
  await assertSucceeds(updateDoc(doc(customerDb(), "requests/r1"),
      {status: "searching", retriedAt: serverTimestamp()}));

  await seedRequest("completed", "tech");
  await assertFails(updateDoc(doc(customerDb(), "requests/r1"),
      {status: "searching", retriedAt: serverTimestamp()}));
});

test("another user cannot cancel the request", async () => {
  await seedRequest("searching");
  const other = env.authenticatedContext("tech").firestore();
  await assertFails(updateDoc(doc(other, "requests/r1"),
      {status: "cancelled", cancelledAt: serverTimestamp()}));
});

test("technician accept flow still works", async () => {
  await seedRequest("offered", "tech");
  const techDb = env.authenticatedContext("tech").firestore();
  await assertSucceeds(updateDoc(doc(techDb, "requests/r1"),
      {status: "accepted", acceptedAt: serverTimestamp()}));
});

function application(extra = {}) {
  return {
    uid: "applicant",
    firstName: "أحمد",
    lastName: "علي",
    residenceId: "1234567890",
    phoneNumber: "+966500000000",
    email: "",
    specialization: "ac",
    profileImageUrl: null,
    status: "pending",
    createdAt: serverTimestamp(),
    ...extra,
  };
}

test("AC and washing machine technicians can apply", async () => {
  const db = env.authenticatedContext("applicant").firestore();
  await assertSucceeds(
      setDoc(doc(db, "technicianApplications/applicant"), application()));
});

test("rejected technician can re-apply, pending cannot overwrite", async () => {
  const db = env.authenticatedContext("applicant").firestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), "technicianApplications/applicant"),
        {...application(), status: "pending", createdAt: new Date()});
  });
  await assertFails(setDoc(doc(db, "technicianApplications/applicant"),
      application({specialization: "washing_machine"})));

  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), "technicianApplications/applicant"),
        {status: "rejected"});
  });
  await assertSucceeds(setDoc(doc(db, "technicianApplications/applicant"),
      application({specialization: "washing_machine"})));
});

test("user can save and clear their own FCM token only", async () => {
  await assertSucceeds(updateDoc(doc(customerDb(), "users/cust"),
      {fcmToken: "abc"}));
  await assertSucceeds(updateDoc(doc(customerDb(), "users/cust"),
      {fcmToken: null}));
  await assertFails(updateDoc(doc(customerDb(), "users/tech"),
      {fcmToken: "abc"}));
  await assertFails(updateDoc(doc(customerDb(), "users/cust"),
      {role: "admin"}));
});

test("admin can approve an AC technician", async () => {
  const adminDb = env.authenticatedContext("admin").firestore();
  await assertSucceeds(setDoc(doc(adminDb, "technicians/t2"), {
    uid: "t2", available: false, serviceType: "ac",
    profileImageUrl: null, latitude: null, longitude: null,
    locationUpdatedAt: null,
  }));
});

test("customer reads own request", async () => {
  await seedRequest("searching");
  await assertSucceeds(getDoc(doc(customerDb(), "requests/r1")));
});
