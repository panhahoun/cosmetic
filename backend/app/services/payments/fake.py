"""In-process provider that settles on demand.

Exists so the full checkout → intent → webhook → paid path is testable without a
merchant account, which is the only way to exercise idempotency and
amount-mismatch handling before anyone has real credentials.

It is deliberately not a stub that returns canned success: intent ids are
generated, and webhooks are only accepted when they carry the secret that
`create_intent` issued, so the "unverified payload must not mark an order paid"
rule is genuinely tested rather than assumed.
"""

from __future__ import annotations

import json
import secrets
from decimal import Decimal
from typing import Any

from app.services.payments.base import (
    CreateIntentRequest,
    PaymentIntent,
    WebhookEvent,
)

WEBHOOK_SECRET_HEADER = "x-fake-signature"


class FakePaymentProvider:
    """Sandbox gateway. Enabled with PAYMENT_PROVIDER=fake."""

    name = "fake"

    def __init__(self) -> None:
        # secret per intent -> signature issued. Survives in memory only, which
        # is fine for a test double and is the point: a signature cannot be
        # forged from outside the process that issued it.
        self._issued: dict[str, dict[str, Any]] = {}

    def create_intent(self, request: CreateIntentRequest) -> PaymentIntent:
        intent_id = f"fake_intent_{secrets.token_hex(8)}"
        secret = secrets.token_hex(16)
        self._issued[intent_id] = {
            "secret": secret,
            "amount": str(request.amount),
            "currency": request.currency,
            "order_id": request.order_id,
        }
        return PaymentIntent(
            provider=self.name,
            provider_intent_id=intent_id,
            status="pending",
            checkout_url=f"https://pay.example.invalid/checkout/{intent_id}",
            qr_payload=f"fake://pay/{intent_id}",
            raw={"intent_id": intent_id, "amount": str(request.amount)},
        )

    def sign(self, intent_id: str) -> str:
        """Signature a callback for `intent_id`, as the real provider would."""
        record = self._issued.get(intent_id)
        if record is None:
            raise KeyError(f"unknown intent {intent_id!r}")
        return record["secret"]

    def parse_webhook(self, headers: dict[str, str], body: bytes) -> WebhookEvent:
        try:
            payload = json.loads(body.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            # Malformed input is recorded, not retried. A gateway that sends
            # garbage will send it again forever.
            return WebhookEvent(
                provider=self.name,
                event_type="malformed",
                verified=False,
                raw={"undecodable": True},
            )
        if not isinstance(payload, dict):
            return WebhookEvent(
                provider=self.name, event_type="malformed", verified=False, raw={}
            )

        intent_id = payload.get("intent_id")
        event_type = str(payload.get("status", "unknown"))
        signature = headers.get(WEBHOOK_SECRET_HEADER) or headers.get(
            WEBHOOK_SECRET_HEADER.upper()
        )
        record = self._issued.get(str(intent_id))

        verified = False
        if record is not None and signature:
            verified = secrets.compare_digest(str(signature), record["secret"])

        amount = payload.get("amount")
        currency = payload.get("currency") or (record or {}).get("currency")

        return WebhookEvent(
            provider=self.name,
            event_type=event_type,
            provider_intent_id=str(intent_id) if intent_id is not None else None,
            provider_event_id=payload.get("event_id"),
            amount=Decimal(str(amount)) if amount is not None else None,
            currency=str(currency) if currency else None,
            verified=verified,
            raw=payload,
        )

    def verify_intent(self, provider_intent_id: str) -> WebhookEvent:
        record = self._issued.get(provider_intent_id)
        if record is None:
            return WebhookEvent(
                provider=self.name,
                event_type="unknown",
                provider_intent_id=provider_intent_id,
                verified=False,
            )
        return WebhookEvent(
            provider=self.name,
            event_type="paid",
            provider_intent_id=provider_intent_id,
            amount=Decimal(record["amount"]),
            currency=record["currency"],
            verified=True,
            raw=dict(record),
        )


__all__ = ["FakePaymentProvider", "WEBHOOK_SECRET_HEADER"]
