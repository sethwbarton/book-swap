import { Controller } from "@hotwired/stimulus"

// Barcode scanner controller using quagga2 for ISBN detection
// quagga2 is loaded dynamically as a UMD bundle and exposes window.Quagga
// Turbo is available globally via @hotwired/turbo-rails
//
// Usage:
// <div data-controller="barcode-scanner"
//      data-barcode-scanner-lookup-url-value="/book_lookups/isbn">
//   <div data-barcode-scanner-target="viewport"></div>
//   <div data-barcode-scanner-target="error"></div>
// </div>

const QUAGGA_CDN_URL = "https://cdn.jsdelivr.net/npm/@ericblade/quagga2@1.10.1/dist/quagga.min.js"

export default class extends Controller {
  static targets = ["viewport", "error", "loading"]
  static values = {
    lookupUrl: String
  }

  connect() {
    this.isScanning = false
    this.lastDetectedCode = null

    // Load Quagga dynamically then initialize scanner
    this.loadQuagga().then(() => {
      this.Quagga = window.Quagga
      this.initializeScanner()
    }).catch((error) => {
      console.error("Failed to load Quagga:", error)
      this.showError("Barcode scanner library failed to load. Please refresh the page.")
    })
  }

  loadQuagga() {
    return new Promise((resolve, reject) => {
      // If already loaded, resolve immediately
      if (window.Quagga) {
        resolve()
        return
      }

      // Check if script is already being loaded
      const existingScript = document.querySelector(`script[src="${QUAGGA_CDN_URL}"]`)
      if (existingScript) {
        // Wait for it to load
        existingScript.addEventListener("load", () => resolve())
        existingScript.addEventListener("error", () => reject(new Error("Script load error")))
        return
      }

      // Create and load the script
      const script = document.createElement("script")
      script.src = QUAGGA_CDN_URL
      script.async = true
      script.onload = () => resolve()
      script.onerror = () => reject(new Error("Failed to load Quagga from CDN"))
      document.head.appendChild(script)
    })
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
          "X-CSRF-Token": this.getMetaCsrfToken(),
          "Accept": "text/vnd.turbo-stream.html"
        },
        body: JSON.stringify({ isbn: isbn })
      })

      if (response.ok) {
        // Let Turbo handle the stream response
        const html = await response.text()
        window.Turbo.renderStreamMessage(html)
      } else {
        // Error responses also return Turbo Streams that update the error div
        const html = await response.text()
        window.Turbo.renderStreamMessage(html)
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
    this.restartScanner()
  }

  getMetaCsrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }
}
