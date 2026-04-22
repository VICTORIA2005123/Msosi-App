/**
 * Msosi payment API — Firebase Cloud Functions (Gen 2)
 *
 * Deploy:
 *   cd functions && npm install && npm run build
 *   firebase deploy --only functions:paymentsApi
 *
 * Secret (v2) — single JSON blob:
 *   firebase functions:secrets:set APP_PAYMENT_SECRETS
 * Value example:
 *   {"stripeSecretKey":"sk_test_...","razorpayKeyId":"rzp_test_...","razorpayKeySecret":"..."}
 * Include only keys for gateways you use; others can be omitted or empty strings.
 *
 * Flutter API_BASE_URL must be the function base URL, e.g.:
 *   https://asia-south1-<PROJECT_ID>.cloudfunctions.net/paymentsApi
 * so requests hit:
 *   .../paymentsApi/payments/create-order
 *   .../paymentsApi/payments/confirm
 */

import * as crypto from "crypto";
import cors from "cors";
import express, { Request, Response } from "express";
import * as admin from "firebase-admin";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
import Stripe from "stripe";

/** One secret JSON: { "stripeSecretKey": "sk_...", "razorpayKeyId": "rzp_...", "razorpayKeySecret": "..." } */
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

export const paymentsApi = onRequest(
  {
    region: "asia-south1",
    cors: true,
    secrets: [appPaymentSecrets],
    invoker: "public",
  },
  app,
);
