# frozen_string_literal: true

require "google/cloud/vision"
require "net/http"
require "json"
require "uri"

class BookImageRecognitionService
  MAX_RESULTS = 5
  GOOGLE_BOOKS_BASE_URL = "https://www.googleapis.com/books/v1/volumes"

  # ISBN patterns to detect in OCR text
  ISBN_PATTERN = /(?:ISBN[:\s-]*)?(\d{3}[-\s]?\d[-\s]?\d{2}[-\s]?\d{6}[-\s]?\d|\d{9}[\dXx])/i

  class << self
    def identify(image)
      extracted_text = extract_text_from_image(image)
      return [] if extracted_text.blank?

      # First, try to find an ISBN in the extracted text
      isbn = extract_isbn_from_text(extracted_text)
      if isbn
        isbn_result = IsbnLookupService.lookup(isbn)
        return [ isbn_result ] if isbn_result
      end

      # Fall back to text-based search
      search_books_by_text(extracted_text)
    rescue Google::Cloud::Error => e
      Rails.logger.error("Google Cloud Vision error: #{e.message}")
      []
    rescue StandardError => e
      Rails.logger.error("BookImageRecognitionService error: #{e.message}")
      []
    end

    private

    def extract_text_from_image(image)
      client = Google::Cloud::Vision.image_annotator
      response = client.text_detection(image: image)

      annotation = response.responses.first
      annotation&.text
    end

    def extract_isbn_from_text(text)
      match = text.match(ISBN_PATTERN)
      return nil unless match

      # Normalize: remove dashes and spaces
      match[1].gsub(/[-\s]/, "")
    end

    def search_books_by_text(text)
      search_query = build_search_query(text)
      return [] if search_query.blank?

      results = search_google_books(search_query)
      results.take(MAX_RESULTS)
    end

    def build_search_query(text)
      # Clean up OCR text for search
      # Remove common noise: prices, ISBNs, special characters
      cleaned = text.dup
      cleaned.gsub!(ISBN_PATTERN, "")
      cleaned.gsub!(/\$\d+\.?\d*/, "") # Remove prices
      cleaned.gsub!(/[^\w\s]/, " ")     # Remove special characters
      cleaned.gsub!(/\s+/, " ")         # Normalize whitespace
      cleaned.strip!

      # Take the first few meaningful words (likely title and author)
      words = cleaned.split
      words.take(10).join(" ")
    end

    def search_google_books(query)
      api_key = Rails.application.credentials.dig(:google_books_api_key)
      uri = URI.parse(GOOGLE_BOOKS_BASE_URL)

      params = { q: query, maxResults: MAX_RESULTS }
      params[:key] = api_key if api_key.present?
      uri.query = URI.encode_www_form(params)

      response = fetch_json(uri)
      return [] unless response && response["totalItems"].to_i > 0

      parse_google_books_results(response)
    rescue StandardError => e
      Rails.logger.error("Google Books search error: #{e.message}")
      []
    end

    def fetch_json(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def parse_google_books_results(data)
      items = data["items"] || []

      items.map do |item|
        volume = item["volumeInfo"]
        next unless volume

        identifiers = volume["industryIdentifiers"] || []
        isbn_10 = identifiers.find { |id| id["type"] == "ISBN_10" }&.dig("identifier")
        isbn_13 = identifiers.find { |id| id["type"] == "ISBN_13" }&.dig("identifier")

        {
          title: volume["title"],
          author: volume["authors"]&.first,
          isbn_10: isbn_10,
          isbn_13: isbn_13,
          cover_image_url: volume.dig("imageLinks", "thumbnail"),
          publisher: volume["publisher"],
          publication_year: extract_year(volume["publishedDate"]),
          page_count: volume["pageCount"],
          description: volume["description"]
        }
      end.compact
    end

    def extract_year(date_string)
      return nil unless date_string

      match = date_string.to_s.match(/\b(\d{4})\b/)
      match ? match[1].to_i : nil
    end
  end
end
