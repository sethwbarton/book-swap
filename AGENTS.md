# Book Swap - Agent Guidelines

## Product Overview

An online platform for users to sell or trade books from their home library. Users can:

- Create an account and list books by scanning barcodes or entering details manually
- Post photographs for condition evaluation
- Purchase books or offer trades with other users

To get an idea of some of what we are considering building or have built check the .agents folder.

## Tech Stack

- **Framework:** Ruby on Rails 8.0.2
- **Ruby Version:** 3.4.5
- **Database:** SQLite
- **Frontend:** Tailwind CSS, Hotwire (Turbo + Stimulus)
- **JavaScript:** Import maps (nobuild) - no npm/webpack for frontend dependencies
- **Payments:** Stripe Connect (10% platform fee)
- **Testing:** Minitest, Capybara, Mocha
- **Linting:** RuboCop (rubocop-rails-omakase)

### JavaScript Dependencies (Import Maps)

This app uses Rails 8's **import maps** approach (nobuild). Frontend JavaScript dependencies
are pinned in `config/importmap.rb` and loaded from CDNs, not installed via npm.

**Key points:**
- The top-level `package.json` is for **development tooling only** (linters, etc.), not frontend deps
- Use `bin/importmap pin <package>` to add JS dependencies
- For libraries that don't support ES modules (CommonJS/UMD), pin the UMD bundle from CDN
  and access via `window.<GlobalName>` in Stimulus controllers

**Example - Adding an ES module compatible library:**
```bash
bin/importmap pin lodash-es
```

**Example - Adding a UMD-only library (like quagga2):**
```ruby
# config/importmap.rb
pin "quagga2", to: "https://cdn.jsdelivr.net/npm/@ericblade/quagga2@1.10.1/dist/quagga.min.js"
```
```javascript
// In Stimulus controller - access from window since UMD exposes globally
connect() {
  this.Quagga = window.Quagga
}
```

## Build/Test/Lint Commands

```bash
# Run all tests (unit + system)
rails test:all

# Run a single test file
rails test test/controllers/books_controller_test.rb

# Run a specific test by line number
rails test test/controllers/books_controller_test.rb:25

# Run only model tests
rails test test/models/

# Run only system tests
rails test:system

# Run linter
rubocop

# Run linter with auto-fix
rubocop -a

# Security scan
brakeman

# Database setup
rails db:prepare
rails db:test:prepare
```

## Test-Driven Development Requirements

1. **Write tests first** - Before implementing any feature, write an automated test that will fail until the feature is
   built
2. **Prefer high-level tests** - Write tests representing user experience (system/integration tests) over unit tests
   when possible
3. **Never delete tests** without explicit permission
4. **Tests must pass** before moving to the next task
5. **Refactor after green** - When tests pass, consider simplifying code and removing unused production code
6. **No style testing** - Do not test CSS/styling; styles must be changeable without breaking tests

## Code Style Guidelines

### Ruby Conventions

- Use `snake_case` for files, methods, variables
- Use `CamelCase` for classes/modules
- Namespaced controllers go in subdirectories (e.g., `app/controllers/webhooks/stripe_controller.rb`)
- Array syntax with spaces inside brackets: `[ :show, :edit, :update ]`
- Symbol keys for hashes (no hash rockets): `{ key: value }`
- Bang methods for mutations: `mark_as_sold!`

### Controller Patterns

- Use `before_action` for shared setup logic
- Strong parameters with `*_params` naming convention
- Guard clauses for early returns
- Flash messages: `notice:` for success, `alert:` for errors
- Return `status: :unprocessable_entity` on validation failures

### Model Patterns

- Order: associations, validations, scopes, public methods, private methods
- Scopes as lambdas: `scope :completed, -> { where(status: "completed") }`
- Use `transaction` blocks for atomic operations
- Store money as cents (integers)
- Private validation methods

### Error Handling

```ruby
rescue Stripe::StripeError => e
Rails.logger.error("Stripe error: #{e.message}")
redirect_to new_purchase_path, alert: "Payment processing failed."
end
```

### Test Conventions

```ruby

class BooksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:seller_one)
    login_as(@user)
  end

  test "GET /books/new renders the new book form" do
    get new_book_path
    assert_response :success
    assert_select "h1", text: "Add a New Book"
  end

  private

  def login_as(user)
    post session_path, params: { email_address: user.email_address, password: "password" }
    follow_redirect! if response.redirect?
  end
end
```

### Mocking External Services (Stripe)

```ruby
require "mocha/minitest"

test "handles Stripe errors gracefully" do
  Stripe::Checkout::Session.stubs(:create).raises(Stripe::StripeError.new("Card declined"))

  assert_no_difference("Purchase.count") do
    post book_purchases_path(@book)
  end

  assert_redirected_to new_book_purchase_path(@book)
end
```

### Stimulus Controllers

```javascript
import {Controller} from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]
  static values = {url: String}

  connect() {
    // Called when controller connects to DOM
  }
}
```

## File Organization

```
app/
  controllers/
    concerns/          # Shared controller modules (e.g., authentication.rb)
    webhooks/          # Webhook handlers (e.g., stripe_controller.rb)
    users/             # User-namespaced controllers
  models/
  views/
    shared/            # Shared partials
    layouts/
test/
  controllers/
    webhooks/          # Mirror app structure
  models/
  system/              # Browser-based tests
  fixtures/            # Test data (YAML with ERB)
```

## Important Patterns

- **Authentication:** Custom session-based auth using `Current.user` (not Devise)
- **Money:** Store as cents (integers), display with formatting helpers
- **Componentization:** Use partials and Ruby classes, not ViewComponent
- **Forms:** Use Turbo by default; add `data: { turbo: false }` to disable
- **Current user:** Access via `Current.user` (ActiveSupport::CurrentAttributes)
