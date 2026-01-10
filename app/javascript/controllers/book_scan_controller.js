import { Controller } from "@hotwired/stimulus"

// Book scan flow controller - coordinates the multi-step scanning process
//
// Steps:
// 1. Method selection (barcode, photo, or manual)
// 2. Scanning/capture (barcode scanner or photo capture)
// 3. Confirmation (review and edit book details, set price)
export default class extends Controller {
  static targets = [
    "methodStep", "scannerStep", "photoStep", "confirmStep", "manualStep",
    "form", "duplicateWarning", "bookPreview",
    "titleField", "authorField", "descriptionField",
    "isbn10Field", "isbn13Field", "coverUrlField",
    "publisherField", "publicationYearField", "pageCountField", "identifiedByField",
    "coverImage", "previewTitle", "previewAuthor", "previewPublisher"
  ]

  static values = {
    isbnLookupUrl: String,
    imageLookupUrl: String,
    createUrl: String
  }

  connect() {
    this.currentStep = "method"
    this.bookData = null
    this.imageMatches = []
  }

  // Navigation
  showStep(stepName) {
    const steps = ["methodStep", "scannerStep", "photoStep", "confirmStep", "manualStep"]
    steps.forEach(step => {
      if (this[`has${this.capitalize(step)}Target`]) {
        this[`${step}Target`].classList.toggle("hidden", step !== `${stepName}Step`)
      }
    })
    this.currentStep = stepName
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }

  backToMethodSelection() {
    this.showStep("method")
    this.bookData = null
    this.imageMatches = []
  }

  // Step 1: Method selection
  startBarcodeScanner() {
    this.showStep("scanner")
  }

  startPhotoCapture() {
    this.showStep("photo")
  }

  showManualEntry() {
    this.showStep("manual")
  }

  // Step 2: Handle scan/photo results
  handleBarcodeDetected(event) {
    const { book, duplicate, existingBookId } = event.detail
    this.bookData = book
    this.bookData.duplicate = duplicate
    this.bookData.existingBookId = existingBookId
    this.bookData.identifiedBy = "isbn"
    this.showConfirmStep()
  }

  handlePhotoIdentified(event) {
    const { matches, message } = event.detail
    this.imageMatches = matches || []
    
    if (this.imageMatches.length === 0) {
      // No matches found, show manual entry with message
      this.showStep("manual")
    } else if (this.imageMatches.length === 1) {
      // Single match, go directly to confirm
      this.bookData = this.imageMatches[0]
      this.bookData.identifiedBy = "image"
      this.showConfirmStep()
    }
    // Multiple matches are shown in the photo controller's result area
    // User will click one to select it via handleMatchSelected
  }

  handleMatchSelected(event) {
    const { index } = event.detail
    if (this.imageMatches[index]) {
      this.bookData = this.imageMatches[index]
      this.bookData.identifiedBy = "image"
      this.showConfirmStep()
    }
  }

  // Step 3: Confirm & Price
  showConfirmStep() {
    if (!this.bookData) return

    this.showStep("confirm")
    this.populateForm()
    this.updatePreview()
    this.checkDuplicate()
  }

  populateForm() {
    const book = this.bookData

    if (this.hasTitleFieldTarget) {
      this.titleFieldTarget.value = book.title || ""
    }
    if (this.hasAuthorFieldTarget) {
      this.authorFieldTarget.value = book.author || ""
    }
    if (this.hasDescriptionFieldTarget) {
      this.descriptionFieldTarget.value = book.description || ""
    }
    if (this.hasIsbn10FieldTarget) {
      this.isbn10FieldTarget.value = book.isbn_10 || ""
    }
    if (this.hasIsbn13FieldTarget) {
      this.isbn13FieldTarget.value = book.isbn_13 || ""
    }
    if (this.hasCoverUrlFieldTarget) {
      this.coverUrlFieldTarget.value = book.cover_image_url || ""
    }
    if (this.hasPublisherFieldTarget) {
      this.publisherFieldTarget.value = book.publisher || ""
    }
    if (this.hasPublicationYearFieldTarget) {
      this.publicationYearFieldTarget.value = book.publication_year || ""
    }
    if (this.hasPageCountFieldTarget) {
      this.pageCountFieldTarget.value = book.page_count || ""
    }
    if (this.hasIdentifiedByFieldTarget) {
      this.identifiedByFieldTarget.value = book.identifiedBy || "manual"
    }
  }

  updatePreview() {
    const book = this.bookData

    if (this.hasPreviewTitleTarget) {
      this.previewTitleTarget.textContent = book.title || ""
    }
    if (this.hasPreviewAuthorTarget) {
      this.previewAuthorTarget.textContent = book.author || "Unknown Author"
    }
    if (this.hasPreviewPublisherTarget) {
      const publisherInfo = [book.publisher, book.publication_year].filter(Boolean).join(", ")
      this.previewPublisherTarget.textContent = publisherInfo
    }
    if (this.hasCoverImageTarget && book.cover_image_url) {
      this.coverImageTarget.src = book.cover_image_url
      this.coverImageTarget.classList.remove("hidden")
    }
  }

  checkDuplicate() {
    if (this.hasDuplicateWarningTarget) {
      const isDuplicate = this.bookData.duplicate === true
      this.duplicateWarningTarget.classList.toggle("hidden", !isDuplicate)
    }
  }
}
