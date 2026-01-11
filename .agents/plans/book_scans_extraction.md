# BookScans Model Extraction

## Overview

This document outlines a potential refactor to extract a `BookScan` model from the current book listing flow. The idea is to separate "identifying a book" from "listing a book for sale."

## Current State

The book scanning flow is a multi-step wizard that:

1. Collects book data through various methods (barcode, photo, manual entry, ISBN lookup)
2. Passes data through URL params between Turbo Frame steps
3. Creates a `Book` record at the end when the user submits the final form

The intermediate state is **transient** - stored only in form params, not persisted to the database.

### Current Flow

```
User -> Choose Method -> [Barcode/Photo/Manual/ISBN] -> Confirm Details -> Create Book
                              |
                              v
                    External API Lookup
                    (OpenLibrary, etc.)
```

## Proposed Model

### BookScan

A `BookScan` represents the intermediate state of identifying a book before it becomes a listing.

```ruby
# == Schema Information
#
# Table name: book_scans
#
#  id                 :integer          not null, primary key
#  user_id            :integer          not null
#  status             :string           default("pending")  # pending, completed, abandoned
#  identification_method :string        # barcode, photo, manual, isbn_entry
#  
#  # Book data (populated from lookup or manual entry)
#  title              :string
#  author             :string
#  isbn_10            :string
#  isbn_13            :string
#  description        :text
#  cover_image_url    :string
#  publisher          :string
#  publication_year   :integer
#  page_count         :integer
#  
#  # Audit/debug data
#  raw_isbn_scanned   :string           # Original ISBN before normalization
#  lookup_source      :string           # openlibrary, google_books, etc.
#  lookup_response    :json             # Raw API response for debugging
#  
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class BookScan < ApplicationRecord
  belongs_to :user
  has_one :book  # The resulting listing, if completed
  
  enum :status, { pending: "pending", completed: "completed", abandoned: "abandoned" }
  enum :identification_method, { 
    barcode: "barcode", 
    photo: "photo", 
    manual: "manual", 
    isbn_entry: "isbn_entry" 
  }
  
  scope :drafts, -> { pending.where("created_at > ?", 7.days.ago) }
  scope :stale, -> { pending.where("created_at < ?", 7.days.ago) }
end
```

### Updated Book Model

```ruby
class Book < ApplicationRecord
  belongs_to :user
  belongs_to :book_scan, optional: true  # Link back to how it was identified
  
  # ... existing code ...
end
```

## Proposed Flow

```
User -> Choose Method -> [Barcode/Photo/Manual/ISBN] -> BookScan Created (pending)
                              |                                    |
                              v                                    v
                    External API Lookup              User can resume later
                              |                                    |
                              v                                    v
                    Update BookScan               Confirm Details (from BookScan)
                                                                   |
                                                                   v
                                                  Create Book (mark BookScan completed)
```

## Pros

### 1. Persistence & Resumability
- Users can save progress and resume later
- Closing browser mid-flow doesn't lose work
- Show "drafts" or "incomplete listings" in dashboard

### 2. Cleaner Domain Model
- Separates "identifying a book" from "listing a book for sale"
- `BookScan` can exist without price, condition photos
- `Book` represents a complete, sellable listing

### 3. Better Audit Trail
- Track how each book was identified
- Store original scanned data vs user edits
- Debug issues with ISBN lookups by examining `lookup_response`

### 4. Enables New Features
- **Bulk scanning**: Scan multiple books, price/list them later
- **Wishlist from scan**: Scan a book you want to buy, not sell
- **Analytics**: Track scan success rates by method
- **Price suggestions**: Use historical data from scans

### 5. Simpler Controllers
```ruby
# BookScansController - handles identification/lookup
class BookScansController < ApplicationController
  def new          # Choose identification method
  def create       # Start a new scan (creates pending record)
  def barcode      # Barcode scanning step
  def photo        # Photo capture step
  def manual       # Manual entry step
  def update       # Update scan with lookup results
end

# BooksController - handles listing/pricing
class BooksController < ApplicationController
  def new          # Confirm details & set price (from BookScan)
  def create       # Create the listing
end
```

### 6. Easier Testing
- Test scan/identification logic independently
- Mock external APIs at `BookScan` level
- Simpler fixtures and factories

## Cons

### 1. Added Complexity
- New model, migration, controller, routes
- Lifecycle management (when to delete incomplete scans?)
- Two-step mental model for users

### 2. Database Clutter
- Abandoned `BookScan` records accumulate
- Need cleanup job or soft-delete strategy
- Extra storage for data that may never become a `Book`

### 3. UX Considerations
- Do users actually want drafts?
- Current flow may be fast enough that persistence adds no value
- More decisions for users ("Save draft?" "Discard?")

### 4. Migration Effort
- Refactor existing Turbo Frame flow
- Update JavaScript controllers
- Update Turbo Stream responses from ISBN lookup

### 5. Potential Over-Engineering
- If 95% of users complete in one session, persistence adds little value
- YAGNI concern if bulk scanning isn't planned

## Implementation Phases

### Phase 1: Model & Migration
1. Create `BookScan` model and migration
2. Add `book_scan_id` to `Book` model
3. Create basic CRUD for `BookScans`

### Phase 2: Refactor Controllers
1. Move identification logic to `BookScansController`
2. Update routes (consider nested: `/book_scans/:id/book/new`)
3. Keep `BooksController` focused on listing creation

### Phase 3: Update Views
1. Refactor Turbo Frame flow to work with persisted `BookScan`
2. Update partials to read from `@book_scan` instead of params
3. Add "Drafts" section to user dashboard

### Phase 4: Cleanup & Polish
1. Add background job to mark old scans as abandoned
2. Add job to delete stale abandoned scans
3. Analytics/reporting on scan methods

## Questions to Resolve

1. **Retention policy**: How long to keep incomplete scans? (Suggest: 7 days pending, then mark abandoned; delete abandoned after 30 days)

2. **User-facing language**: Call them "drafts"? "Incomplete listings"? "Scans"?

3. **Dashboard placement**: Prominent "Continue your draft" CTA? Or subtle "X drafts" link?

4. **Bulk scanning priority**: Is this a near-term feature? If not, simpler approach may suffice.

5. **Anonymous scans**: Should unauthenticated users be able to scan and then sign up? (Adds complexity)

## Alternative: Soft Extraction (No Database)

If persistence isn't needed, consider extracting `BookScan` as a **form object** or **service object** without a database table:

```ruby
class BookScan
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attribute :title, :string
  attribute :author, :string
  attribute :isbn_13, :string
  # ... etc
  
  def to_book
    Book.new(attributes.slice(*Book.column_names))
  end
end
```

This gives cleaner code organization without database overhead. The trade-off is no persistence/resumability.

## Recommendation

**Start with the soft extraction** (form object) to clean up the code without adding database complexity. This gives most of the code organization benefits with minimal risk.

If user research or analytics later show that:
- Users frequently abandon the flow mid-way
- Bulk scanning becomes a priority
- Audit trail becomes important

Then upgrade to full database persistence.

## Related Files

Current implementation:
- `app/controllers/books_controller.rb` (scan actions)
- `app/controllers/book_lookups_controller.rb` (ISBN/image lookup)
- `app/views/books/scan/` (all scan partials)
- `app/javascript/controllers/barcode_scanner_controller.js`
- `app/javascript/controllers/book_photo_controller.js`
