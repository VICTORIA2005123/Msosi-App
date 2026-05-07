import * as crypto from "crypto";
import cors from "cors";
import express, { Request, Response } from "express";
import * as admin from "firebase-admin";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import Stripe from "stripe";

const appPaymentSecrets = defineSecret("APP_PAYMENT_SECRETS");

type PaymentSecrets = {
  stripeSecretKey?: string;
  razorpayKeyId?: string;
  razorpayKeySecret?: string;
};

function parseSecrets(): PaymentSecrets {
  const raw = appPaymentSecrets.value();
  try {
    return JSON.parse(raw) as PaymentSecrets;
  } catch {
    throw new Error("APP_PAYMENT_SECRETS must be valid JSON");
  }
}

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

async function verifyBearerUid(req: Request): Promise<string> {
  const authHeader = req.headers.authorization || "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw Object.assign(new Error("Missing Authorization bearer token"), { status: 401 });
  }
  const decoded = await admin.auth().verifyIdToken(match[1]);
  return decoded.uid;
}

// ============================================================================
// PHASE 4: SECURE ORDER CREATION
// ============================================================================

app.post("/orders/create", async (req: Request, res: Response) => {
  try {
    const uid = await verifyBearerUid(req);
    const body = req.body as Record<string, any>;
    
    const userId = String(body.user_id || "");
    const restaurantId = String(body.restaurant_id || "");
    const requestedPickupTimeStr = String(body.pickup_time || "");
    const items = (body.items as any[]) || [];

    // 1. Basic validation
    if (userId !== uid) {
      res.status(403).json({ error: "user_id must match signed-in user" });
      return;
    }
    if (!restaurantId || items.length === 0 || !requestedPickupTimeStr) {
      res.status(400).json({ error: "Invalid restaurant_id, items, or pickup_time" });
      return;
    }

    const requestedPickupTime = new Date(requestedPickupTimeStr);
    if (isNaN(requestedPickupTime.getTime())) {
      res.status(400).json({ error: "Invalid pickup_time format" });
      return;
    }

    // 2. Fetch Restaurant Data
    const restaurantSnap = await db.collection("restaurants").doc(restaurantId).get();
    if (!restaurantSnap.exists) {
      res.status(404).json({ error: "Restaurant not found" });
      return;
    }
    const restaurantData = restaurantSnap.data()!;
    if (restaurantData.is_open !== true) {
      res.status(400).json({ error: "Restaurant is currently closed" });
      return;
    }

    const prepCapacity = Number(restaurantData.prep_capacity) || 15;

    // 3. Fetch Menu Items and Recompute Total / Max Prep Time
    let computedTotal = 0;
    let maxPrepTime = 0;
    const validatedItems = [];

    for (const item of items) {
      const menuId = item.menu_id;
      const quantity = Number(item.quantity) || 1;
      
      const menuSnap = await db.collection("restaurants").doc(restaurantId).collection("menuItems").doc(menuId).get();
      if (!menuSnap.exists) {
        res.status(400).json({ error: `Menu item ${menuId} not found` });
        return;
      }
      
      const menuData = menuSnap.data()!;
      if (menuData.available !== true) {
        res.status(400).json({ error: `Item ${menuData.item_name} is currently unavailable` });
        return;
      }

      const price = Number(menuData.price) || 0;
      const prepTime = Number(menuData.prep_time) || 15;

      computedTotal += (price * quantity);
      if (prepTime > maxPrepTime) {
        maxPrepTime = prepTime;
      }

      validatedItems.push({
        menu_id: menuId,
        item_name: menuData.item_name,
        price: price,
        quantity: quantity
      });
    }

    // 4. Validate Time Slot Constraint
    const now = new Date();
    const earliestPossible = new Date(now.getTime() + maxPrepTime * 60000);
    
    if (requestedPickupTime < earliestPossible) {
      res.status(400).json({ 
        error: "Requested pickup time is too soon. Minimum prep time is " + maxPrepTime + " minutes." 
      });
      return;
    }

    // 5. Validate Vendor Capacity for this 10-minute slot
    // A slot is defined by rounding the minutes down to the nearest 10
    const slotStart = new Date(requestedPickupTime);
    slotStart.setMinutes(Math.floor(slotStart.getMinutes() / 10) * 10, 0, 0);
    const slotEnd = new Date(slotStart.getTime() + 10 * 60000); // +10 mins

    const slotOrdersSnap = await db.collection("orders")
      .where("restaurant_id", "==", restaurantId)
      .where("pickup_time", ">=", slotStart.toISOString())
      .where("pickup_time", "<", slotEnd.toISOString())
      .get();

    if (slotOrdersSnap.size >= prepCapacity) {
      res.status(400).json({ 
        error: "This time slot is fully booked. Please select another time." 
      });
      return;
    }

    // 6. Create Order inside a Transaction
    const result = await db.runTransaction(async (transaction) => {
      // Re-read capacity in transaction
      const rSnap = await transaction.get(db.collection("restaurants").doc(restaurantId));
      if (!rSnap.exists) throw { status: 404, message: "Restaurant not found" };
      const rData = rSnap.data()!;
      const cap = Number(rData.prep_capacity) || 15;

      // Re-check slot capacity (Note: Firestore transactions on queries are tricky,
      // but reading the restaurant doc provides a lock on that restaurant's state)
      const slotSnap = await db.collection("orders")
        .where("restaurant_id", "==", restaurantId)
        .where("pickup_time", ">=", slotStart.toISOString())
        .where("pickup_time", "<", slotEnd.toISOString())
        .get();

      if (slotSnap.size >= cap) {
        throw { status: 400, message: "This time slot just filled up. Please try another." };
      }

      const orderRef = db.collection("orders").doc();
      transaction.set(orderRef, {
        user_id: userId,
        vendor_id: rData.vendor_id || "",
        restaurant_id: restaurantId,
        total_price: computedTotal,
        status: "pending",
        created_at: now.toISOString(),
        pickup_time: requestedPickupTime.toISOString(),
        items: validatedItems,
      });

      return { orderId: orderRef.id };
    });

    res.json({ success: true, ...result, total_price: computedTotal });

  } catch (e: any) {
    const status = e.status || 500;
    res.status(status).json({ error: e.message || String(e) });
  }
});

app.post("/users/upgrade-to-vendor", async (req: Request, res: Response) => {
  try {
    const uid = await verifyBearerUid(req);
    await db.collection("users").doc(uid).update({
      role: "vendor"
    });
    res.json({ success: true });
  } catch (e: any) {
    const status = e.status || 500;
    res.status(status).json({ error: e.message || String(e) });
  }
});


// ============================================================================
// LEGACY PAYMENT API (Bypassed for MVP but preserved)
// ============================================================================

app.post("/payments/create-order", async (req: Request, res: Response) => {
  try {
    const uid = await verifyBearerUid(req);
    const body = req.body as Record<string, unknown>;
    const gateway = String(body.gateway || "").toLowerCase();
    const userId = String(body.user_id || "");
    const restaurantId = String(body.restaurant_id || "");
    const totalAmount = Number(body.total_amount);
    const currency = String(body.currency || "INR").toLowerCase();
    const items = (body.items as unknown[]) || [];

    if (userId !== uid) {
      res.status(403).json({ error: "user_id must match signed-in user" });
      return;
    }
    if (!restaurantId || !Number.isFinite(totalAmount) || totalAmount <= 0) {
      res.status(400).json({ error: "Invalid restaurant_id or total_amount" });
      return;
    }

    const orderRef = await db.collection("orders").add({
      user_id: userId,
      restaurant_id: restaurantId,
      total_price: totalAmount,
      status: "PendingPayment",
      created_at: new Date().toISOString(),
      items,
      gateway,
    });
    const appOrderId = orderRef.id;

    if (gateway === "stripe") {
      const secrets = parseSecrets();
      const sk = secrets.stripeSecretKey?.trim();
      if (!sk) {
        res.status(500).json({ error: "stripeSecretKey missing in APP_PAYMENT_SECRETS" });
        return;
      }
      const stripe = new Stripe(sk);
      const amountMinor = Math.round(totalAmount * 100);
      const pi = await stripe.paymentIntents.create({
        amount: amountMinor,
        currency,
        automatic_payment_methods: { enabled: true },
        metadata: {
          app_order_id: appOrderId,
          user_id: userId,
          restaurant_id: restaurantId,
        },
      });
      await orderRef.update({
        stripe_payment_intent_id: pi.id,
      });
      res.json({
        app_order_id: appOrderId,
        payment_intent_client_secret: pi.client_secret,
        payment_intent_id: pi.id,
      });
      return;
    }

    if (gateway === "razorpay") {
      const secrets = parseSecrets();
      const keyId = secrets.razorpayKeyId?.trim() || "";
      const keySecret = secrets.razorpayKeySecret?.trim() || "";
      if (!keyId || !keySecret) {
        res.status(500).json({ error: "razorpayKeyId / razorpayKeySecret missing in APP_PAYMENT_SECRETS" });
        return;
      }
      const auth = Buffer.from(`${keyId}:${keySecret}`).toString("base64");
      const rzRes = await fetch("https://api.razorpay.com/v1/orders", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${auth}`,
        },
        body: JSON.stringify({
          amount: Math.round(totalAmount * 100),
          currency: currency.toUpperCase(),
          receipt: appOrderId.slice(0, 40),
          notes: { app_order_id: appOrderId, user_id: userId },
        }),
      });
      if (!rzRes.ok) {
        const t = await rzRes.text();
        res.status(502).json({ error: "Razorpay order create failed", detail: t });
        return;
      }
      const rzJson = (await rzRes.json()) as { id?: string };
      const razorpayOrderId = rzJson.id || "";
      if (!razorpayOrderId) {
        res.status(502).json({ error: "Razorpay response missing id" });
        return;
      }
      await orderRef.update({ razorpay_order_id: razorpayOrderId });
      res.json({
        app_order_id: appOrderId,
        razorpay_order_id: razorpayOrderId,
        razorpay_key_id: keyId,
      });
      return;
    }

    res.status(400).json({ error: "Unsupported gateway" });
  } catch (e: unknown) {
    const err = e as { status?: number; message?: string };
    const status = err.status || 500;
    res.status(status).json({ error: err.message || String(e) });
  }
});

app.post("/payments/confirm", async (req: Request, res: Response) => {
  try {
    const uid = await verifyBearerUid(req);
    const body = req.body as Record<string, unknown>;
    const gateway = String(body.gateway || "").toLowerCase();
    const appOrderId = String(body.app_order_id || "");

    if (!appOrderId) {
      res.status(400).json({ error: "Missing app_order_id" });
      return;
    }

    const snap = await db.collection("orders").doc(appOrderId).get();
    if (!snap.exists) {
      res.status(404).json({ error: "Order not found" });
      return;
    }
    const data = snap.data() || {};
    if (String(data.user_id) !== uid) {
      res.status(403).json({ error: "Order does not belong to this user" });
      return;
    }

    if (gateway === "stripe") {
      const paymentIntentId = String(body.payment_intent_id || "");
      if (!paymentIntentId) {
        res.status(400).json({ error: "Missing payment_intent_id" });
        return;
      }
      const secrets = parseSecrets();
      const sk = secrets.stripeSecretKey?.trim();
      if (!sk) {
        res.status(500).json({ error: "stripeSecretKey missing in APP_PAYMENT_SECRETS" });
        return;
      }
      const stripe = new Stripe(sk);
      const pi = await stripe.paymentIntents.retrieve(paymentIntentId);
      if (pi.status !== "succeeded") {
        res.status(400).json({ error: `PaymentIntent status: ${pi.status}` });
        return;
      }
      if (String(pi.metadata?.app_order_id || "") !== appOrderId) {
        res.status(400).json({ error: "PaymentIntent metadata mismatch" });
        return;
      }
      await snap.ref.update({
        status: "Paid",
        payment_id: pi.id,
        paid_at: new Date().toISOString(),
      });
      res.json({ order_id: appOrderId, payment_id: pi.id, status: "paid" });
      return;
    }

    if (gateway === "razorpay") {
      const paymentId = String(body.razorpay_payment_id || "");
      const orderId = String(body.razorpay_order_id || "");
      const signature = String(body.razorpay_signature || "");
      if (!paymentId || !orderId || !signature) {
        res.status(400).json({ error: "Missing Razorpay confirmation fields" });
        return;
      }
      const secrets = parseSecrets();
      const keySecret = secrets.razorpayKeySecret?.trim() || "";
      if (!keySecret) {
        res.status(500).json({ error: "razorpayKeySecret missing in APP_PAYMENT_SECRETS" });
        return;
      }
      const expected = crypto
        .createHmac("sha256", keySecret)
        .update(`${orderId}|${paymentId}`)
        .digest("hex");
      if (expected !== signature) {
        res.status(400).json({ error: "Invalid Razorpay signature" });
        return;
      }
      await snap.ref.update({
        status: "Paid",
        payment_id: paymentId,
        paid_at: new Date().toISOString(),
      });
      res.json({ order_id: appOrderId, payment_id: paymentId, status: "paid" });
      return;
    }

    res.status(400).json({ error: "Unsupported gateway" });
  } catch (e: unknown) {
    const err = e as { status?: number; message?: string };
    const status = err.status || 500;
    res.status(status).json({ error: err.message || String(e) });
  }
});

// ============================================================================
// EXPORTS
// ============================================================================

export const api = onRequest(
  {
    region: "asia-south1",
    cors: true,
    secrets: [appPaymentSecrets],
    invoker: "public",
  },
  app,
);

// PHASE 6: NOTIFICATIONS TRIGGER
export const onOrderStatusChanged = onDocumentUpdated("orders/{orderId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();

  if (!before || !after) return;

  // Only trigger when status changes to 'ready'
  if (before.status !== "ready" && after.status === "ready") {
    const userId = after.user_id;
    const restaurantId = after.restaurant_id;

    // Get user's FCM token
    const userSnap = await db.collection("users").doc(userId).get();
    if (!userSnap.exists) return;
    
    const fcmToken = userSnap.data()?.fcm_token;
    if (!fcmToken) return;

    // Get restaurant name for the message
    const restaurantSnap = await db.collection("restaurants").doc(restaurantId).get();
    const restaurantName = restaurantSnap.exists ? restaurantSnap.data()?.name : "the restaurant";

    const payload = {
      token: fcmToken,
      notification: {
        title: "Order Ready! 👩🏾‍🍳",
        body: `Your order from ${restaurantName} is ready for pickup!`,
      },
      data: {
        orderId: event.params.orderId,
        click_action: "FLUTTER_NOTIFICATION_CLICK"
      }
    };

    try {
      await admin.messaging().send(payload);
      console.log(`Notification sent to ${userId} for order ${event.params.orderId}`);
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  }
});
