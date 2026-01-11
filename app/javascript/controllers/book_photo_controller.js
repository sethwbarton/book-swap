import { Controller } from "@hotwired/stimulus"

// Photo capture controller for book identification and condition photos
// Turbo is available globally via @hotwired/turbo-rails
//
// Usage for identification:
// <div data-controller="book-photo"
//      data-book-photo-mode-value="identify"
//      data-book-photo-upload-url-value="/book_lookups/image"
//      data-book-photo-confirm-url-value="/books/scan/confirm"
//      data-book-photo-manual-url-value="/books/scan/manual">
//   <video data-book-photo-target="video"></video>
//   <canvas data-book-photo-target="canvas" class="hidden"></canvas>
//   <img data-book-photo-target="preview" class="hidden">
//   <input type="file" data-book-photo-target="fileInput" class="hidden">
//   <div data-book-photo-target="result"></div>
//   <div data-book-photo-target="error"></div>
//   <div data-book-photo-target="loading"></div>
// </div>
//
// Usage for condition photos:
// <div data-controller="book-photo"
//      data-book-photo-mode-value="condition">
//   ...
// </div>
export default class extends Controller {
  static targets = ["video", "canvas", "preview", "fileInput", "result", "error", "loading", "capturedPhotos"]
  static values = {
    mode: { type: String, default: "identify" }, // "identify" or "condition"
    uploadUrl: String,
    confirmUrl: String,   // URL to navigate to on successful identification
    manualUrl: String,    // URL for manual entry fallback
    csrfToken: String,
    maxPhotos: { type: Number, default: 5 }
  }

  connect() {
    this.stream = null
    this.capturedPhotos = [] // For condition mode
    this.imageMatches = []   // For identification mode

    if (this.modeValue === "identify") {
      this.startCamera()
    }
  }

  disconnect() {
    this.stopCamera()
  }

  async startCamera() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: "environment", // Back camera on mobile
          width: { ideal: 1280 },
          height: { ideal: 720 }
        }
      })

      if (this.hasVideoTarget) {
        this.videoTarget.srcObject = this.stream
        this.videoTarget.play()
      }
    } catch (error) {
      console.error("Camera access error:", error)
      this.showError("Could not access camera. Please ensure camera permissions are granted.")
    }
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }
  }

  capture() {
    if (!this.hasVideoTarget || !this.hasCanvasTarget) return

    const video = this.videoTarget
    const canvas = this.canvasTarget
    const context = canvas.getContext("2d")

    // Set canvas size to match video
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight

    // Draw current video frame to canvas
    context.drawImage(video, 0, 0, canvas.width, canvas.height)

    // Convert to blob
    canvas.toBlob((blob) => {
      if (this.modeValue === "identify") {
        this.uploadForIdentification(blob)
      } else {
        this.addConditionPhoto(blob)
      }
    }, "image/jpeg", 0.8)
  }

  selectFromGallery() {
    if (this.hasFileInputTarget) {
      this.fileInputTarget.click()
    }
  }

  handleFileSelect(event) {
    const file = event.target.files[0]
    if (!file) return

    if (this.modeValue === "identify") {
      this.uploadForIdentification(file)
    } else {
      this.addConditionPhoto(file)
    }

    // Reset file input
    event.target.value = ""
  }

  async uploadForIdentification(imageBlob) {
    this.showLoading()
    this.clearError()

    const formData = new FormData()
    formData.append("image", imageBlob, "capture.jpg")

    try {
      const response = await fetch(this.uploadUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": this.csrfTokenValue || this.getMetaCsrfToken(),
          "Accept": "application/json"
        },
        body: formData
      })

      const data = await response.json()

      if (response.ok) {
        this.handleIdentificationResult(data)
      } else {
        this.showError(data.message || "Could not identify book. Please try again or enter manually.")
      }
    } catch (error) {
      console.error("Image upload error:", error)
      this.showError("Network error. Please check your connection and try again.")
    } finally {
      this.hideLoading()
    }
  }

  handleIdentificationResult(data) {
    this.imageMatches = data.matches || []

    if (this.imageMatches.length === 0) {
      // No matches found, show message and option to enter manually
      if (this.hasResultTarget) {
        this.resultTarget.innerHTML = `
          <div class="text-center py-4">
            <p class="text-gray-600 mb-3">${data.message || "No books found in the image."}</p>
            <a href="${this.manualUrlValue}" 
               data-turbo-frame="scan_step"
               class="text-blue-600 hover:text-blue-800 underline">
              Enter book details manually
            </a>
          </div>
        `
      }
    } else if (this.imageMatches.length === 1) {
      // Single match, navigate directly to confirm
      this.navigateToConfirm(this.imageMatches[0])
    } else {
      // Multiple matches, show selection UI
      this.showMatchSelection()
    }
  }

  showMatchSelection() {
    if (!this.hasResultTarget) return

    this.resultTarget.innerHTML = `
      <div class="space-y-2">
        <p class="font-medium">Select the correct book:</p>
        ${this.imageMatches.map((book, index) => this.renderMatchOption(book, index)).join("")}
      </div>
    `
  }

  renderMatchOption(book, index) {
    const duplicateWarning = book.duplicate
      ? `<span class="text-amber-600 text-sm">(Already listed)</span>`
      : ""

    return `
      <button type="button"
              class="w-full text-left p-3 border rounded-lg hover:bg-gray-50 flex gap-3"
              data-action="click->book-photo#selectMatch"
              data-book-index="${index}">
        ${book.cover_image_url ? `<img src="${book.cover_image_url}" alt="Cover" class="w-12 h-auto rounded">` : ""}
        <div class="flex-1">
          <p class="font-medium">${this.escapeHtml(book.title)} ${duplicateWarning}</p>
          <p class="text-sm text-gray-600">${this.escapeHtml(book.author || "Unknown Author")}</p>
        </div>
      </button>
    `
  }

  selectMatch(event) {
    const index = parseInt(event.currentTarget.dataset.bookIndex, 10)
    if (this.imageMatches[index]) {
      this.navigateToConfirm(this.imageMatches[index])
    }
  }

  navigateToConfirm(bookData) {
    if (!this.hasConfirmUrlValue) {
      console.error("No confirm URL configured")
      return
    }

    // Build URL with book data as query params
    const params = new URLSearchParams()
    if (bookData.title) params.set("title", bookData.title)
    if (bookData.author) params.set("author", bookData.author)
    if (bookData.isbn_10) params.set("isbn_10", bookData.isbn_10)
    if (bookData.isbn_13) params.set("isbn_13", bookData.isbn_13)
    if (bookData.cover_image_url) params.set("cover_image_url", bookData.cover_image_url)
    if (bookData.publisher) params.set("publisher", bookData.publisher)
    if (bookData.publication_year) params.set("publication_year", bookData.publication_year)
    if (bookData.page_count) params.set("page_count", bookData.page_count)
    if (bookData.description) params.set("description", bookData.description)
    params.set("identified_by", "image")

    const confirmUrl = `${this.confirmUrlValue}?${params.toString()}`
    
    // Stop camera before navigating
    this.stopCamera()
    
    // Use Turbo to navigate within the frame
    window.Turbo.visit(confirmUrl, { frame: "scan_step" })
  }

  // Condition photo mode methods
  addConditionPhoto(blob) {
    if (this.capturedPhotos.length >= this.maxPhotosValue) {
      this.showError(`Maximum ${this.maxPhotosValue} photos allowed.`)
      return
    }

    // Convert blob to data URL for preview
    const reader = new FileReader()
    reader.onload = (e) => {
      const photoData = {
        blob: blob,
        dataUrl: e.target.result
      }
      this.capturedPhotos.push(photoData)
      this.updatePhotoPreview()

      // Dispatch event with photo data
      this.dispatch("photoAdded", {
        detail: {
          photo: blob,
          count: this.capturedPhotos.length
        }
      })
    }
    reader.readAsDataURL(blob)
  }

  removePhoto(event) {
    const index = parseInt(event.currentTarget.dataset.photoIndex, 10)
    this.capturedPhotos.splice(index, 1)
    this.updatePhotoPreview()

    this.dispatch("photoRemoved", {
      detail: { count: this.capturedPhotos.length }
    })
  }

  updatePhotoPreview() {
    if (!this.hasCapturedPhotosTarget) return

    if (this.capturedPhotos.length === 0) {
      this.capturedPhotosTarget.innerHTML = ""
      return
    }

    this.capturedPhotosTarget.innerHTML = `
      <div class="flex gap-2 flex-wrap">
        ${this.capturedPhotos.map((photo, index) => `
          <div class="relative">
            <img src="${photo.dataUrl}" alt="Condition photo ${index + 1}" class="w-20 h-20 object-cover rounded">
            <button type="button"
                    class="absolute -top-2 -right-2 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs"
                    data-action="click->book-photo#removePhoto"
                    data-photo-index="${index}">
              &times;
            </button>
          </div>
        `).join("")}
      </div>
    `
  }

  getPhotosForUpload() {
    return this.capturedPhotos.map(p => p.blob)
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
