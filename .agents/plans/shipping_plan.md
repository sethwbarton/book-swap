# USPS Media Mail Shipping with EasyPost

## Summary

- **Provider:** EasyPost
- **Carrier:** USPS Media Mail only (for now)
- **Payment:** Buyer pays actual EasyPost shipping cost at checkout
- **Weight:** Flat 1 lb estimate for all books
- **Label Generation:** Automatic after checkout, with retry on failure
- **Seller Address:** Collected during Stripe Connect onboarding flow

---

## Implementation Phases

### Phase 1: Seller Ship-From Address

#### 1.1 Database Migration

Add address fields to `users` table:
- `ship_from_name` (string)
- `ship_from_address_line1` (string)
- `ship_from_address_line2` (string)
- `ship_from_city` (string)
- `ship_from_state` (string)
- `ship_from_postal_code` (string)
- `ship_from_country` (string, default "US")

#### 1.2 Collect Address After Stripe Onboarding

Modify the Stripe Connect return flow:
- After returning from Stripe, redirect to a "Enter Ship-From Address" form
- Once address is saved, redirect to the "Start Listing Your Books" page
- Add validation that prevents listing books without a ship-from address

**Files:**
- `db/migrate/xxx_add_ship_from_address_to_users.rb`
- `app/controllers/users/stripe_connections_controller.rb` (modify return action)
- `app/controllers/users/addresses_controller.rb` (new)
- `app/views/users/addresses/new.html.erb` (new - address form)
- `app/models/user.rb` (add `has_ship_from_address?` method)
- `config/routes.rb` (add address routes)

---

### Phase 2: EasyPost Integration & Shipping Service

#### 2.1 Setup

- Add `easypost` gem to Gemfile
- Add EasyPost API key to credentials
- Add shipping config (weight: 1 lb, dimensions: 9x6x2 inches typical book)

#### 2.2 Shipping Label Service

Create `app/services/shipping_label_service.rb`:
```ruby
class ShippingLabelService
  def self.create_label(purchase)
    # 1. Build EasyPost addresses (from/to)
    # 2. Create parcel (1 lb, book dimensions)
    # 3. Create shipment
    # 4. Buy USPS Media Mail rate
    # 5. Return tracking number + label URL
  end
end
```

**Files:**
- `Gemfile` (add easypost)
- `config/credentials.yml.enc` (add easypost api key)
- `config/initializers/easypost.rb` (configure client)
- `app/services/shipping_label_service.rb` (new)
- `test/services/shipping_label_service_test.rb` (new)

---

### Phase 3: Database Changes for Shipping/Tracking

#### 3.1 Migration

Add to `purchases` table:
- `shipping_label_url` (string) - EasyPost label PDF URL
- `tracking_number` (string) - USPS tracking number
- `tracking_carrier` (string, default "USPS")
- `shipping_cost_cents` (integer) - Actual cost charged
- `label_created_at` (datetime) - When label was generated
- `label_generation_attempts` (integer, default 0) - For retry logic

**Files:**
- `db/migrate/xxx_add_shipping_label_fields_to_purchases.rb`

---

### Phase 4: Checkout Flow with Shipping Cost

#### 4.1 Get Shipping Rate at Checkout

Before creating Stripe Checkout Session:
1. Call EasyPost to get USPS Media Mail rate for seller -> buyer
2. Add rate as `shipping_options` in Stripe Checkout

#### 4.2 Store Shipping Cost

Save the shipping cost on the Purchase record.

**Files:**
- `app/controllers/purchases_controller.rb` (add shipping rate lookup + shipping_options)
- `test/controllers/purchases_controller_test.rb` (update tests)

---

### Phase 5: Label Generation After Checkout

#### 5.1 Update Webhook Handler

After `checkout.session.completed`:
1. Save shipping cost from session
2. Call `ShippingLabelService.create_label(purchase)`
3. Store tracking number + label URL
4. If fails, enqueue retry job

#### 5.2 Retry Job

Create `ShippingLabelGenerationJob`:
- Exponential backoff: 1min, 4min, 16min, 64min (4 retries)
- Increment `label_generation_attempts`
- After 4 failures, leave in failed state (future: email alert)

**Files:**
- `app/controllers/webhooks/stripe_controller.rb` (call shipping service)
- `app/jobs/shipping_label_generation_job.rb` (new)
- `test/controllers/webhooks/stripe_controller_test.rb` (update)
- `test/jobs/shipping_label_generation_job_test.rb` (new)

---

### Phase 6: Seller Label Access

#### 6.1 Seller Dashboard / Order View

Add ability for seller to view their sales and download shipping labels.

**Files:**
- `app/controllers/sales_controller.rb` (new - seller's sold items)
- `app/views/sales/index.html.erb` (list of sales with label download)
- `app/views/sales/show.html.erb` (sale detail with label + buyer address)
- `config/routes.rb` (add sales routes)

---

## Test Strategy

Following TDD, tests will be written first for each phase:

1. **Phase 1:** Test that users can save ship-from address, test validation
2. **Phase 2:** Test ShippingLabelService with mocked EasyPost (success + failure cases)
3. **Phase 3:** N/A (migration only)
4. **Phase 4:** Test checkout includes shipping_options, test shipping cost stored
5. **Phase 5:** Test webhook triggers label generation, test retry job with exponential backoff
6. **Phase 6:** Test seller can view sales and access label URL

---

## Open Questions

1. **Book dimensions:** Assumed 9x6x2 inches as typical book dimensions. Should we use different defaults or make this configurable?

2. **Validation timing:** Should we prevent listing books until ship-from address is set, or just prevent sales? (Assumed: prevent listing)

3. **Seller address updates:** Can sellers update their ship-from address after setting it? If so, should it affect pending/completed purchases?
