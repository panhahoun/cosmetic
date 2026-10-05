"""Provider lookup, and the seam a real gateway plugs into.

Only `fake` is wired up. The three production gateways are deliberately not
implemented: each needs merchant credentials and a sandbox account, and
guessing at their request/response shapes would produce code that looks
finished and cannot work.

Selecting an unimplemented gateway raises at lookup, not at first checkout.
That ordering is deliberate — a deploy that enabled `baray` without an
implementation should refuse to boot rather than accept orders and 503 every
customer at the payment step.
"""

from __future__ import annotations

from app.core.config import settings
from app.services.payments.base import PaymentConfigurationError, PaymentProvider
from app.services.payments.fake import FakePaymentProvider

# Known to config (so credentials can be required for it) but not yet coded.
UNIMPLEMENTED_PROVIDERS: frozenset[str] = frozenset({"baray", "payway", "bakong"})


def build_provider(name: str | None = None) -> PaymentProvider:
    """Instantiate the configured gateway.

    Raises PaymentConfigurationError when checkout is set to 'none' or points at
    a gateway with no implementation. Both are honest failures: the caller asked
    to take money and nothing can.
    """
    provider_name = (name or settings.payment_provider or "none").strip().lower()

    if provider_name == "none":
        raise PaymentConfigurationError(
            "No payment provider is configured (PAYMENT_PROVIDER=none). "
            "Card checkout is unavailable; cash on delivery still works."
        )
    if provider_name in UNIMPLEMENTED_PROVIDERS:
        raise PaymentConfigurationError(
            f"The {provider_name!r} gateway is selected but not implemented yet. "
            f"Write a PaymentProvider in app/services/payments/{provider_name}.py, "
            "register it in build_provider(), and keep it behind "
            f"PAYMENT_PROVIDER=none until it passes sandbox tests. {provider_name!r} "
            "is left here as an explicit refusal rather than a stub that would "
            "fail at the customer's checkout instead of at deploy time."
        )
    if provider_name == "fake":
        return FakePaymentProvider()
    raise PaymentConfigurationError(f"Unknown payment provider {provider_name!r}.")


# The process-wide provider instance. Webhooks are handled in a request handler
# and must verify against the same secret store the intent was created from, so
# the instance is shared rather than rebuilt per request.
_provider: PaymentProvider | None = None


def get_provider() -> PaymentProvider:
    global _provider
    if _provider is None:
        _provider = build_provider()
    return _provider


def reset_provider() -> None:
    """Drop the cached instance. For tests that swap the configured provider."""
    global _provider
    _provider = None


__all__ = [
    "FakePaymentProvider",
    "UNIMPLEMENTED_PROVIDERS",
    "build_provider",
    "get_provider",
    "reset_provider",
]
