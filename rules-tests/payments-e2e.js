// اختبار تكامل الدفع على المحاكيات مع خادم ميسّر وهمي. التشغيل: npm run test:payments
process.env.FIRESTORE_EMULATOR_HOST="127.0.0.1:8081";
process.env.FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099";
const http=require("http");
const admin=require(require("path").resolve(__dirname, "../functions/node_modules/firebase-admin"));
admin.initializeApp({projectId:"demo-thamer"});
const db=admin.firestore();
const assert=require("assert");

// ---- fake Moyasar ----
const payments={}; const refunds=[];
const server=http.createServer((req,res)=>{
  const auth=req.headers.authorization||"";
  if(auth!=="Basic "+Buffer.from("sk_test_fake:").toString("base64")){res.writeHead(401);return res.end("{}");}
  const m=req.url.match(/^\/payments\/([^/]+)(\/refund)?$/);
  const p=m&&payments[m[1]];
  if(!p){res.writeHead(404);return res.end(JSON.stringify({message:"not found"}));}
  if(m[2]&&req.method==="POST"){p.status="refunded";refunds.push(p.id);}
  res.writeHead(200,{"content-type":"application/json"});res.end(JSON.stringify(p));
});
server.listen(7777);

async function idToken(uid){
  const ct=await admin.auth().createCustomToken(uid);
  const r=await fetch("http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=fake",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({token:ct,returnSecureToken:true})});
  return (await r.json()).idToken;
}
async function call(name,uid,data){
  const r=await fetch(`http://127.0.0.1:5000/demo-thamer/me-central2/${name}`,{method:"POST",headers:{"content-type":"application/json",authorization:"Bearer "+await idToken(uid)},body:JSON.stringify({data})});
  return {status:r.status, body:await r.json()};
}
const sleep=(ms)=>new Promise(r=>setTimeout(r,ms));
async function waitFor(fn,label){for(let i=0;i<40;i++){const v=await fn();if(v)return v;await sleep(250);}throw new Error("timeout: "+label);}
function req(id,extra={}){return {requestId:id,customerId:"cust",technicianId:null,serviceType:"ac",totalPrice:51.75,laborCost:45,appFee:6.75,materialsCost:0,status:"awaiting_payment",paymentStatus:"unpaid",customerLatitude:24.7,customerLongitude:46.7,createdAt:new Date(),...extra};}
function pay(id,reqId,extra={}){payments[id]={id,status:"paid",amount:5175,currency:"SAR",metadata:{request_id:reqId},source:{type:"creditcard"},...extra};}

const results=[];
async function step(name,fn){try{await fn();results.push("PASS "+name);}catch(e){results.push("FAIL "+name+": "+e.message);}}

(async()=>{
  for(const u of ["cust","other","adminU"]) await admin.auth().createUser({uid:u});
  await db.doc("users/cust").set({uid:"cust",role:"customer",name:"عميل",phone:"+966500000001"});
  await db.doc("users/other").set({uid:"other",role:"customer"});
  await db.doc("users/adminU").set({uid:"adminU",role:"admin"});

  await step("valid payment starts the technician search", async()=>{
    await db.doc("requests/r1").set(req("r1")); pay("pay_1","r1");
    const r=await call("confirmPayment","cust",{requestId:"r1",paymentId:"pay_1"});
    assert.equal(r.status,200,JSON.stringify(r.body)); assert.equal(r.body.result.status,"paid");
    const d=await waitFor(async()=>{const x=(await db.doc("requests/r1").get()).data();return x.status!=="awaiting_payment"&&x.status!=="searching"?x:null;},"dispatch");
    assert.equal(d.paymentStatus,"paid"); assert.equal(d.paymentId,"pay_1"); assert.equal(d.paidAmount,51.75);
    assert.equal(d.status,"no_technician_available"); // no technicians exist in this test
  });

  await step("calling confirm twice is harmless", async()=>{
    const r=await call("confirmPayment","cust",{requestId:"r1",paymentId:"pay_1"});
    assert.equal(r.status,200); assert.equal(r.body.result.status,"paid");
  });

  await step("wrong amount is rejected", async()=>{
    await db.doc("requests/r2").set(req("r2")); pay("pay_2","r2",{amount:100});
    const r=await call("confirmPayment","cust",{requestId:"r2",paymentId:"pay_2"});
    assert.notEqual(r.status,200);
    assert.equal((await db.doc("requests/r2").get()).data().status,"awaiting_payment");
  });

  await step("payment for a different request is rejected", async()=>{
    pay("pay_3","r1");
    const r=await call("confirmPayment","cust",{requestId:"r2",paymentId:"pay_3"});
    assert.notEqual(r.status,200);
  });

  await step("failed payment is rejected", async()=>{
    pay("pay_4","r2",{status:"failed"});
    const r=await call("confirmPayment","cust",{requestId:"r2",paymentId:"pay_4"});
    assert.notEqual(r.status,200);
    assert.equal((await db.doc("requests/r2").get()).data().paymentStatus,"unpaid");
  });

  await step("another user cannot confirm someone else's request", async()=>{
    pay("pay_5","r2");
    const r=await call("confirmPayment","other",{requestId:"r2",paymentId:"pay_5"});
    assert.notEqual(r.status,200);
  });

  await step("second payment for same request is refunded", async()=>{
    pay("pay_6","r1");
    const r=await call("confirmPayment","cust",{requestId:"r1",paymentId:"pay_6"});
    assert.equal(r.body.result.status,"duplicate"); assert.ok(refunds.includes("pay_6"));
  });

  await step("cancelling a paid request refunds it", async()=>{
    await db.doc("requests/r1").update({status:"cancelled",cancelledAt:new Date()});
    const d=await waitFor(async()=>{const x=(await db.doc("requests/r1").get()).data();return x.paymentStatus==="refunded"?x:null;},"refund");
    assert.ok(refunds.includes("pay_1")); assert.ok(d.refundedAt);
  });

  await step("webhook with wrong secret is rejected", async()=>{
    const r=await fetch("http://127.0.0.1:5000/demo-thamer/me-central2/moyasarWebhook",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({type:"payment_paid",secret_token:"nope",data:{id:"pay_5",metadata:{request_id:"r2"}}})});
    assert.equal(r.status,401);
  });

  await step("webhook confirms a payment when the app was closed", async()=>{
    const r=await fetch("http://127.0.0.1:5000/demo-thamer/me-central2/moyasarWebhook",{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({type:"payment_paid",secret_token:"whsec_test",data:{id:"pay_5",metadata:{request_id:"r2"}}})});
    assert.equal(r.status,200);
    const d=(await db.doc("requests/r2").get()).data();
    assert.equal(d.paymentStatus,"paid"); assert.equal(d.paymentId,"pay_5");
  });

  await step("completed paid request creates the technician earning", async()=>{
    await db.doc("users/tech").set({uid:"tech",role:"technician",name:"فني"});
    await db.doc("technicians/tech").set({uid:"tech",available:false,currentRequestId:"r4",serviceType:"ac"});
    await db.doc("requests/r4").set(req("r4",{status:"waiting_customer_confirmation",paymentStatus:"paid",paymentId:"pay_x",technicianId:"tech",technicianName:"فني"}));
    await db.doc("requests/r4").update({status:"completed"});
    const e=await waitFor(async()=>{const x=await db.doc("technicianEarnings/r4").get();return x.exists?x.data():null;},"earning");
    assert.equal(e.amount,45); assert.equal(e.status,"pending"); assert.equal(e.technicianId,"tech");
  });

  await step("only admin can record a payout", async()=>{
    const bad=await call("recordPayout","cust",{technicianId:"tech"});
    assert.notEqual(bad.status,200);
    const r=await call("recordPayout","adminU",{technicianId:"tech",reference:"TRX-1"});
    assert.equal(r.status,200,JSON.stringify(r.body)); assert.equal(r.body.result.amount,45);
    assert.equal((await db.doc("technicianEarnings/r4").get()).data().status,"paid_out");
    const p=await db.collection("payouts").where("technicianId","==","tech").get();
    assert.equal(p.size,1); assert.equal(p.docs[0].data().reference,"TRX-1");
  });

  console.log("RESULTS\n"+results.join("\n"));
  server.close(); process.exit(results.some(r=>r.startsWith("FAIL"))?1:0);
})().catch(e=>{console.error(e);process.exit(1)});
