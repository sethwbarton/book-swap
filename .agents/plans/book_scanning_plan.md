# Book Scanning & Identification

## Summary

- **Barcode scanning:** Client-side with `quagga2` library
- **ISBN lookup:** Open Library (primary) + Google Books (fallback)
- **Image OCR:** Google Cloud Vision API
- **Fallback:** Manual entry allowed when identification fails
- **UX flow:** One book at a time (scan/identify -> confirm -> price -> list)
- **Condition photos:** Optional, stored via Active Storage
- **Storage:** Hetzner cloud storage (purchased separately)

---

## Architecture Overview

```
+---------------------------------------------------------------------+
|                         MOBILE BROWSER                               |
|  +----------------------+    +----------------------------------+   |
|  |  Barcode Scanner     |    |  Photo Capture                   |   |
|  |  (quagga2)           |    |  (HTML5 Camera API)              |   |
|  |  -> ISBN detected    |    |  -> Upload cover/spine/title     |   |
|  +----------+-----------+    +--------------+-------------------+   |
+-------------|------------------------------|------------------------+
              |                              |
              v                              v
+---------------------------------------------------------------------+
|                         RAILS BACKEND                                |
|  +----------------------+    +----------------------------------+   |
|  |  ISBN Lookup Service |    |  Image Recognition Service       |   |
|  |  1. Open Library     |    |  1. Google Cloud Vision (OCR)    |   |
|  |  2. Google Books     |    |  2. Extract title/author text    |   |
|  |     (fallback)       |    |  3. Search Open Library/Google   |   |
|  +----------+-----------+    +--------------+-------------------+   |
|             |                               |                       |
|             +--------------+----------------+                       |
|                            v                                        |
|                 +---------------------+                             |
|                 |  Book Match Results |                             |
|                 +---------------------+                             |
+---------------------------------------------------------------------+
```

---

## Two Identification Paths

### Path A: ISBN Barcode Scan (Primary)

For books with readable barcodes:
1. User points phone camera at barcode
2. Client-side `quagga2` library detects and decodes ISBN
3. Rails backend looks up ISBN in Open Library (then Google Books if not found)
4. Book details displayed for confirmation
5. User sets price, optionally adds condition photos, and lists

### Path B: Photo-Based Identification (Fallback)

For books without ISBNs (old books, international editions, damaged barcodes):
1. User takes photo of cover, spine, or title page
2. Photo uploaded to Rails backend
3. Google Cloud Vision extracts text via OCR
4. Extracted text searched in Open Library/Google Books
5. Top matches displayed for user to select
6. User confirms, sets price, optionally adds condition photos, and lists

---

## Service Choices

### Barcode Scanning (Client-Side)

**Choice: `quagga2`** (MIT license, ~150KB)
- Active fork of original Quagga
- Excellent ISBN/EAN barcode support
- Works well on mobile browsers

Alternatives considered:
- `zxing-js` - Good but requires more configuration
- `html5-qrcode` - Lighter but less barcode format support

### ISBN Lookup

**Primary: Open Library API** (Free, no API key required)
- Endpoint: `https://openlibrary.org/isbn/{ISBN}.json`
- Good coverage, community-maintained
- Returns: title, author, cover URL, publisher, publish date

**Fallback: Google Books API** (Free tier: 1000 requests/day)
- Endpoint: `https://www.googleapis.com/books/v1/volumes?q=isbn:{ISBN}`
- Excellent coverage
- Requires API key

### Image OCR

**Choice: Google Cloud Vision API** ($1.50 per 1000 images)
- `TEXT_DETECTION` feature extracts text from book covers/title pages
- Ruby gem: `google-cloud-vision`
- Reliable, well-documented

Alternatives considered:
- AWS Textract - Similar pricing, would use if already on AWS
- Tesseract (open-source) - Free but less accurate, requires server setup

---

## Implementation Phases

### Phase 1: Database Schema Changes

Add fields to `books` table for identification data:

```ruby
# New columns
isbn_10           # string - ISBN-10 format
isbn_13           # string - ISBN-13 format  
description       # text - book description from API
cover_image_url   # string - URL to cover image
publisher         # string
publication_year  # integer
page_count        # integer
identified_by     # string - "isbn", "image", or "manual"
```

**Files:**
- `db/migrate/xxx_add_book_identification_fields_to_books.rb`

---

### Phase 2: ISBN Lookup Service

Rails service to fetch book metadata from ISBN.

```ruby
# app/services/isbn_lookup_service.rb
class IsbnLookupService
  def self.lookup(isbn)
    # 1. Normalize ISBN (strip dashes, validate format)
    # 2. Try Open Library first
    # 3. Fall back to Google Books if not found
    # 4. Return normalized book data hash or nil
  end
end
```

**Response format:**
```ruby
{
  title: "To Kill a Mockingbird",
  author: "Harper Lee",
  isbn_10: "0061120081",
  isbn_13: "9780061120084",
  cover_image_url: "https://covers.openlibrary.org/b/isbn/9780061120084-L.jpg",
  publisher: "Harper Perennial",
  publication_year: 2006,
  page_count: 336,
  description: "The unforgettable novel of a childhood..."
}
```

**Files:**
- `app/services/isbn_lookup_service.rb`
- `test/services/isbn_lookup_service_test.rb`
- `config/credentials.yml.enc` (add `google_books_api_key`)

---

### Phase 3: Image Recognition Service

Rails service to extract text from book photos and identify books.

```ruby
# app/services/book_image_recognition_service.rb
class BookImageRecognitionService
  def self.identify(image)
    # 1. Send image to Google Cloud Vision TEXT_DETECTION
    # 2. Parse extracted text for title/author candidates
    # 3. Search Open Library with: title, author keywords
    # 4. Search Google Books as fallback
    # 5. Return array of possible matches (max 5)
  end
end
```

**Response format:**
```ruby
[
  { title: "To Kill a Mockingbird", author: "Harper Lee", confidence: 0.95, ... },
  { title: "Go Set a Watchman", author: "Harper Lee", confidence: 0.72, ... },
]
```

**Files:**
- `Gemfile` (add `google-cloud-vision` gem)
- `config/initializers/google_cloud_vision.rb`
- `app/services/book_image_recognition_service.rb`
- `test/services/book_image_recognition_service_test.rb`
- `config/credentials.yml.enc` (add Google Cloud credentials)

---

### Phase 4: Book Lookup API Endpoints

Controller endpoints for AJAX book lookups.

```ruby
# app/controllers/book_lookups_controller.rb
class BookLookupsController < ApplicationController
  # POST /book_lookups/isbn
  # Params: { isbn: "9780061120084" }
  # Returns: JSON book data or { error: "not_found" }
  def isbn
  end

  # POST /book_lookups/image
  # Params: { image: <uploaded file> }
  # Returns: JSON array of possible matches
  def image
  end
end
```

**Files:**
- `app/controllers/book_lookups_controller.rb`
- `test/controllers/book_lookups_controller_test.rb`
- `config/routes.rb` (add routes)

---

### Phase 5: Duplicate Detection

Check if user already has a book with the same ISBN listed.

```ruby
# In Book model or lookup controller
def check_duplicate(user, isbn_10: nil, isbn_13: nil)
  user.books.where(isbn_10: isbn_10).or(user.books.where(isbn_13: isbn_13)).exists?
end
```

**Behavior:**
- When duplicate found, show warning: "You already have this book listed"
- Allow user to proceed anyway (they might have multiple copies)
- Or navigate to existing listing to edit

**Files:**
- `app/models/book.rb` (add scope/method)
- Update `book_lookups_controller.rb` to check duplicates

---

### Phase 6: Barcode Scanner Stimulus Controller

Client-side barcode scanning using `quagga2`.

```javascript
// app/javascript/controllers/barcode_scanner_controller.js
import { Controller } from "@hotwired/stimulus"
import Quagga from "@ericblade/quagga2"

export default class extends Controller {
  static targets = ["video", "result", "error"]
  static values = { lookupUrl: String }
  
  connect() {
    this.initializeScanner()
  }
  
  disconnect() {
    Quagga.stop()
  }
  
  initializeScanner() {
    // Configure for EAN-13 (ISBN) barcodes
    // Start camera stream
  }
  
  onDetected(result) {
    const isbn = result.codeResult.code
    // POST to lookupUrlValue with ISBN
    // Handle response (show book details or error)
  }
}
```

**Files:**
- `package.json` (add `@ericblade/quagga2`)
- `app/javascript/controllers/barcode_scanner_controller.js`

---

### Phase 7: Photo Capture Stimulus Controller

Client-side photo capture for image-based identification.

```javascript
// app/javascript/controllers/book_photo_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "canvas", "preview", "fileInput"]
  static values = { 
    mode: String,  // "identify" or "condition"
    uploadUrl: String 
  }
  
  connect() {
    if (this.modeValue === "identify") {
      this.startCamera()
    }
  }
  
  capture() {
    // Draw video frame to canvas
    // Convert to blob
    // If identify mode: POST to uploadUrlValue
    // If condition mode: store for later upload with book
  }
  
  selectFromGallery() {
    // Trigger file input for selecting existing photo
  }
}
```

**Files:**
- `app/javascript/controllers/book_photo_controller.js`

---

### Phase 8: Condition Photos with Active Storage

Allow sellers to attach photos showing actual book condition.

**Setup:**
```ruby
# app/models/book.rb
class Book < ApplicationRecord
  has_many_attached :condition_photos
end
```

**Storage configuration:**
```yaml
# config/storage.yml
hetzner:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:hetzner, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:hetzner, :secret_access_key) %>
  region: eu-central
  bucket: book-swap-uploads
  endpoint: https://fsn1.your-objectstorage.com  # Hetzner endpoint
```

**Files:**
- `app/models/book.rb` (add `has_many_attached :condition_photos`)
- `config/storage.yml` (configure Hetzner storage)
- `config/environments/production.rb` (set `config.active_storage.service = :hetzner`)
- `app/views/books/_condition_photos_form.html.erb`

---

### Phase 9: Scanning UI Flow

Single book at a time flow:

**Step 1: Choose identification method**
- "Scan Barcode" button -> opens camera with barcode scanner
- "Take Photo" button -> opens camera for cover/title page photo
- "Enter Manually" link -> skip to manual form

**Step 2: Identification**
- Barcode: auto-lookup on detection
- Photo: upload, show "Identifying..." spinner, show matches to select
- Either path checks for duplicates and warns user

**Step 3: Confirm & Price**
- Show book details (cover, title, author, etc.)
- User confirms or edits
- User enters price
- Optional: "Add condition photos" expandable section

**Step 4: List**
- Submit creates book listing
- Redirect to book show page or "Add Another Book" prompt

**Files:**
- `app/controllers/books_controller.rb` (update `new` action, add `scan` action)
- `app/views/books/scan.html.erb` (main scanning interface)
- `app/views/books/_identification_step.html.erb`
- `app/views/books/_confirm_step.html.erb`
- `app/views/books/_manual_entry_form.html.erb`

---

### Phase 10: Manual Entry Fallback

When identification fails, allow manual entry.

**Triggers:**
- ISBN not found in any database
- Image recognition returns no matches
- User clicks "Enter Manually" link

**Form fields:**
- Title (required)
- Author (required)
- ISBN (optional)
- Description (optional)
- Cover photo upload (optional)

Book saved with `identified_by: "manual"`.

**Files:**
- `app/views/books/_manual_entry_form.html.erb`
- Update controllers to handle manual path

---

## Infrastructure Notes

### Storage

- **Provider:** Hetzner Object Storage
- **Usage:** Condition photos, manually uploaded cover photos
- **Configuration:** S3-compatible API via Active Storage

### External API Keys Required

1. **Google Books API** - for ISBN lookup fallback
   - Get from: Google Cloud Console
   - Store in: `Rails.application.credentials.google_books_api_key`

2. **Google Cloud Vision API** - for OCR
   - Get from: Google Cloud Console (enable Vision API)
   - Store in: `Rails.application.credentials.google_cloud` (service account JSON)

3. **Hetzner Object Storage** - for Active Storage
   - Get from: Hetzner Cloud Console
   - Store in: `Rails.application.credentials.hetzner`

---

## Cost Estimates

| Service | Usage | Cost |
|---------|-------|------|
| Open Library | Unlimited | Free |
| Google Books | 1000/day free | Free for MVP |
| Google Cloud Vision | Per 1000 images | ~$1.50 |
| Hetzner Storage | Per GB/month | ~$0.01/GB |

**Estimated monthly cost for 1000 image-based identifications:** ~$1.50 + storage

---

## Test Strategy

Following TDD per AGENTS.md:

1. **Phase 1:** N/A (migration only)
2. **Phase 2:** Mock HTTP calls to Open Library/Google Books, test parsing and fallback logic
3. **Phase 3:** Mock Google Cloud Vision responses, test text extraction and search
4. **Phase 4:** Integration tests for lookup endpoints (success, not found, error cases)
5. **Phase 5:** Model tests for duplicate detection
6. **Phase 6-7:** System tests with mocked responses (test the flow, not the actual camera)
7. **Phase 8:** Model tests for Active Storage attachments
8. **Phase 9-10:** System tests for full scanning flow including manual fallback

---

## Open Questions (Resolved)

1. ~~Condition photos storage~~ -> Active Storage with Hetzner
2. ~~Queue vs single book~~ -> Single book at a time for MVP
3. ~~Duplicate detection~~ -> Yes, warn user if same ISBN already listed
