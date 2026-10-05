"""Provider-agnostic payment primitives.

Every gateway in scope (Baray, ABA PayWay, Bakong/KHQR, Wing) has the same
shape underneath — create an intent, hand the customer something to scan or
follow, then be told asynchronously that the money arrived — but no two agree on
field names, encryption, or whether they push or require polling. This module
fixes one vocabulary so the rest of the backend never branches on a provider
name.

Adding a gateway means writing one module that satisfies `PaymentProvider` and
adding its name to `_KNOWN_PAYMENT_PROVIDERS` in app/core/config.py. No router
or service change.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from decimal import Decimal
from typing import Any, Protocol, runtime_checkable


class ProviderError(RuntimeError):
    """The gateway refused or failed. Carries a message safe to log."""

    def __init__(self, message: str, *, retryable: bool = False) -> None:
        super().__init__(message)
        self.retryable = retryable


class PaymentConfigurationError(RuntimeError):
    """Card checkout was requested but no provider is wired up."""


@dataclass(frozen=True)
class CreateIntentRequest:
    """Everything a provider needs. Built server-side, never from client input.

    `amount` originates from `Order.total_amount`, which was computed from cart
    snapshots. There is deliberately no amount field on any client-facing
    schema: a caller that can choose what to pay can pay $0.01 for a $200 order.
    """

    order_id: int
    order_number: str
    amount: Decimal
    currency: str
    description: str
    return_url: str
    cancel_url: str
    callback_url: str


@dataclass(frozen=True)
class PaymentIntent:
    """The provider's answer to a create-intent call."""

    provider: str
    provider_intent_id: str
    status: str
    checkout_url: str | None = None
    qr_payload: str | None = None
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class WebhookEvent:
    """A verified notification that money moved.

    `verified` is set only after the provider's own signature or encrypted
    field has been checked against a value we issued. An unverified payload may
    be stored for debugging but must never move an order to paid.
    """

    provider: str
    event_type: str
    provider_intent_id: str | None = None
    provider_event_id: str | None = None
    amount: Decimal | None = None
    currency: str | None = None
    verified: bool = False
    raw: dict[str, Any] = field(default_factory=dict)

    @property
    def is_success(self) -> bool:
        return self.event_type.lower() in {"paid", "settled", "payment_succeeded"}


@runtime_checkable
class PaymentProvider(Protocol):
    """What the backend requires of a gateway."""

    name: str

    def create_intent(self, request: CreateIntentRequest) -> PaymentIntent:
        """Register an intent with the gateway and return what to show the customer."""

    def parse_webhook(self, headers: dict[str, str], body: bytes) -> WebhookEvent:
        """Verify and normalise an inbound callback.

        Must not raise on a malformed body; return an unverified WebhookEvent so
        the caller can record it and answer 200. Raising here invites the
        gateway into a retry storm over a payload that will never become valid.
        """

    def verify_intent(self, provider_intent_id: str) -> WebhookEvent:
        """Reconcile: ask the gateway directly. The fallback when a webhook is lost."""


__all__ = [
    "CreateIntentRequest",
    "PaymentConfigurationError",
    "PaymentIntent",
    "PaymentProvider",
    "ProviderError",
    "WebhookEvent",
]
