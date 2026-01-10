import { Controller } from "@hotwired/stimulus"

// Barcode scanner controller using quagga2 for ISBN detection
// quagga2 is loaded as a UMD bundle and exposes window.Quagga
//
// Usage:
// <div data-controller="barcode-scanner"
//      data-barcode-scanner-lookup-url-value="/book_lookups/isbn">
//   <div data-barcode-scanner-target="viewport"></div>
//   <div data-barcode-scanner-target="result"></div>
//   <div data-barcode-scanner-target="error"></div>
// </div>
export default class extends Controller {
  static targets = ["viewport", "result", "error", "loading"]
  static values = {
    lookupUrl: String,
    csrfToken: String
  }

  connect() {
    this.Quagga = window.Quagga
    this.isScanning = false
    this.lastDetectedCode = null

    if (!this.Quagga) {
      this.showError("Barcode scanner library not loaded. Please refresh the page.")
      return
    }

    this.initializeScanner()
  }

  disconnect() {
    this.stopScanner()
  }

  initializeScanner() {
    const config = {
      inputStream: {
        name: "Live",
        type: "LiveStream",
        target: this.viewportTarget,
        constraints: {
          facingMode: "environment", // Use back camera on mobile
          aspectRatio: { min: 1, max: 2 },
          width: { min: 640, ideal: 1280, max: 1920 },
          height: { min: 480, ideal: 720, max: 1080 }
        }
      },
      locator: {
        patchSize: "medium",
        halfSample: true
      },
      numOfWorkers: navigator.hardwareConcurrency || 4,
      decoder: {
        readers: [
          "ean_reader",      // EAN-13 (ISBN-13)
          "ean_8_reader",    // EAN-8
          "upc_reader",      // UPC-A
          "upc_e_reader"     // UPC-E
        ]
      },
      locate: true
    }

    this.Quagga.init(config, (err) => {
      if (err) {
        console.error("Quagga init error:", err)
        this.showError("Could not access camera. Please ensure camera permissions are granted.")
        return
      }

      this.Quagga.start()
      this.isScanning = true
      this.setupDetectionHandler()
    })
  }

  setupDetectionHandler() {
    this.Quagga.onDetected((result) => {
      if (!result || !result.codeResult) return

      const code = result.codeResult.code

      // Debounce: ignore if same code detected within 2 seconds
      if (code === this.lastDetectedCode) return

      // Validate that it looks like an ISBN (10 or 13 digits)
      if (!this.isValidIsbn(code)) return

      this.lastDetectedCode = code

      // Stop scanning and process the result
      this.stopScanner()
      this.lookupIsbn(code)

      // Reset after 2 seconds to allow rescanning
      setTimeout(() => {
        this.lastDetectedCode = null
      }, 2000)
    })
  }

  isValidIsbn(code) {
    // ISBN-13 starts with 978 or 979
    // ISBN-10 is 10 digits
    const cleaned = code.replace(/[-\s]/g, "")
    return (cleaned.length === 13 && (cleaned.startsWith("978") || cleaned.startsWith("979"))) ||
           cleaned.length === 10
  }

  async lookupIsbn(isbn) {
    this.showLoading()
    this.clearError()

    try {
      const response = await fetch(this.lookupUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfTokenValue || this.getMetaCsrfToken(),
          "Accept": "application/json"
        },
        body: JSON.stringify({ isbn: isbn })
      })

      const data = await response.json()

      if (response.ok) {
        this.showResult(data)
      } else if (response.status === 404) {
        this.showError(`No book found for ISBN: ${isbn}. Try manual entry.`)
        this.restartScanner()
      } else {
        this.showError(data.message || "An error occurred. Please try again.")
        this.restartScanner()
      }
    } catch (error) {
      console.error("ISBN lookup error:", error)
      this.showError("Network error. Please check your connection and try again.")
      this.restartScanner()
    } finally {
      this.hideLoading()
    }
  }

  showResult(bookData) {
    // Dispatch custom event with book data for parent controllers to handle
    this.dispatch("detected", {
      detail: {
        book: bookData,
        duplicate: bookData.duplicate || false,
        existingBookId: bookData.existing_book_id
      }
    })

    // Also update result target if present
    if (this.hasResultTarget) {
      this.resultTarget.innerHTML = this.renderBookPreview(bookData)
    }
  }

  renderBookPreview(book) {
    const duplicateWarning = book.duplicate
      ? `<p class="text-amber-600 font-medium">${book.duplicate_message}</p>`
      : ""

    return `
      <div class="bg-white rounded-lg shadow p-4">
        ${duplicateWarning}
        <div class="flex gap-4">
          ${book.cover_image_url ? `<img src="${book.cover_image_url}" alt="Book cover" class="w-24 h-auto rounded">` : ""}
          <div>
            <h3 class="font-bold text-lg">${this.escapeHtml(book.title)}</h3>
            <p class="text-gray-600">${this.escapeHtml(book.author || "Unknown Author")}</p>
            ${book.publisher ? `<p class="text-sm text-gray-500">${this.escapeHtml(book.publisher)}</p>` : ""}
            ${book.publication_year ? `<p class="text-sm text-gray-500">${book.publication_year}</p>` : ""}
          </div>
        </div>
      </div>
    `
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }
  }

  clearError() {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ""
      this.errorTarget.classList.add("hidden")
    }
  }

  showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
  }

  hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
  }

  stopScanner() {
    if (this.isScanning && this.Quagga) {
      this.Quagga.stop()
      this.isScanning = false
    }
  }

  restartScanner() {
    if (!this.isScanning) {
      this.initializeScanner()
    }
  }

  // Action to manually restart scanning
  restart() {
    this.clearError()
    if (this.hasResultTarget) {
      this.resultTarget.innerHTML = ""
    }
    this.restartScanner()
  }

  getMetaCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }

  escapeHtml(text) {
    if (!text) return ""
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
