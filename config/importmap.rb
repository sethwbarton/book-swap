# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Barcode scanning library (UMD - accessed via window.Quagga)
pin "quagga2", to: "https://cdn.jsdelivr.net/npm/@ericblade/quagga2@1.10.1/dist/quagga.min.js"
