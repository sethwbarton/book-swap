# Future Ideas

Ideas and features discussed for future implementation.

---

## Payments & Transfers

### Delayed Seller Payouts
- **Context:** Don't transfer money to seller until buyer receives the book, in case of refunds/returns
- **Options discussed:**
  - Escrow / delayed transfers - hold funds until condition met
  - Stripe Connect's "Separate charges and transfers" - collect payment first, transfer to seller later
  - Hold period + dispute window (3-7 days after delivery confirmation)
- **Decision:** To be implemented - hold funds until delivery confirmed

---

## Disputes & Refunds

### Return Policy Decisions Needed
- **Who pays return shipping?** (Buyer, seller, or platform?)
- **Refund window:** 7 days? 30 days? After delivery only?
- **Refund conditions:** Item not as described? Damaged? Buyer's remorse?
- **Dispute mediation:** Platform mediates vs. let Stripe handle chargebacks?

### Return Flow Options
1. **Buyer returns book** - Buyer ships back, seller confirms receipt, platform refunds
2. **Refund without return** - For low-value items, buyer keeps book, platform refunds
3. **Partial refund** - Negotiate compromise, buyer keeps book

---

## Shipping Enhancements

### Delivery Tracking
- Integrate with carrier APIs (or EasyPost/AfterShip) to poll delivery status
- Auto-release funds to seller X days after "delivered" status (unless dispute opened)
- Webhook notifications for tracking updates

### Additional Shipping Options (Future)
- Add USPS Priority Mail as faster/more expensive option
- Let buyer choose shipping speed at checkout
- Consider other carriers (UPS, FedEx) for heavier shipments

### Shipping Rate Calculation Improvements
- Estimate weight from ISBN lookup (book databases)
- Allow seller to enter actual book weight when listing
- Dynamic shipping cost based on distance (seller → buyer zip codes)

---

## Email Notifications

### Transactional Emails Needed
- Label generation failure alert (after 4 retry attempts)
- Purchase confirmation to buyer
- Sale notification to seller (with shipping label link)
- Shipping/tracking updates
- Delivery confirmation
- Dispute opened/resolved notifications

---

## Seller Experience

### Seller Dashboard
- View all sales
- Download shipping labels
- Track shipment status
- View earnings/payouts

### Book Listing Improvements
- ISBN barcode scanning
- Auto-populate book details from ISBN
- Multiple book photos for condition evaluation
- Book condition rating system

---

## Platform Features

### Book Trading
- Original product vision includes trading books (not just selling)
- Allow users to offer trades instead of purchases
- Trade matching system

### Search & Discovery
- Search books by title, author, ISBN
- Browse by category/genre
- Recommendations based on user preferences
