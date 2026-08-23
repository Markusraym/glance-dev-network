# Stripe Revenue (Scroll)

Your available Stripe balance, per currency.

Ships as a pair: **`stripe-revenue-scroll`** (192x32) and **`stripe-revenue`** (64x32). Same app, different panel width — set
whichever one matches your hardware; the settings below are identical.

## Setting it up

1. In the Stripe dashboard go to **Developers → API keys**.
2. Create a **restricted key**, not a secret key.
3. Give it **read** access to **Balance** and nothing else.
4. Paste it into **Stripe restricted key**.

## Settings

| setting | what it is |
|---|---|
| **Stripe restricted key** *(credential)* | Developers -> API keys -> restricted key with balance read access. |

## Notes

- **Use a restricted key.** A full secret key on a wall panel can move money; a balance-read restricted key cannot do anything but show a number.
- The balance shown is what Stripe has available, which is not the same as your revenue for the period.

---

Settings ride a colon-separated render descriptor, so **a value containing `:` is cut
at the first colon before the app sees it** — which is why URLs are entered without
their scheme, or split into parts. See [CONTRIBUTING.md](../../CONTRIBUTING.md).
