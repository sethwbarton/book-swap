# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class IsbnLookupService
  OPEN_LIBRARY_BASE_URL = "https://openlibrary.org"
  GOOGLE_BOOKS_BASE_URL = "https://www.googleapis.com/books/v1/volumes"

  class << self
    def lookup(isbn)
      normalized_isbn = normalize_isbn(isbn)
      return nil unless valid_isbn?(normalized_isbn)

      result = lookup_open_library(normalized_isbn)
      result ||= lookup_google_books(normalized_isbn)
      result
    end

    private

    def normalize_isbn(isbn)
      isbn.to_s.gsub(/[-\s]/, "")
    end

    def valid_isbn?(isbn)
      isbn.match?(/\A\d{10}(\d{3})?\z/)
    end

    def lookup_open_library(isbn)
      uri = URI.parse("#{OPEN_LIBRARY_BASE_URL}/isbn/#{isbn}.json")
      response = fetch_json(uri)
      return nil unless response

      parse_open_library_response(response, isbn)
    rescue StandardError => e
      Rails.logger.error("Open Library lookup error: #{e.message}")
      nil
    end

    def lookup_google_books(isbn)
      api_key = Rails.application.credentials.dig(:google_books_api_key)
      uri = URI.parse(GOOGLE_BOOKS_BASE_URL)
      params = { q: "isbn:#{isbn}" }
      params[:key] = api_key if api_key.present?
      uri.query = URI.encode_www_form(params)

      response = fetch_json(uri)
      return nil unless response && response["totalItems"].to_i > 0

      parse_google_books_response(response)
    rescue StandardError => e
      Rails.logger.error("Google Books lookup error: #{e.message}")
      nil
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

    def parse_open_library_response(data, original_isbn)
      author_name = fetch_author_name(data["authors"]&.first&.dig("key"))

      {
        title: data["title"],
        author: author_name,
        isbn_10: extract_isbn(data["isbn_10"]),
        isbn_13: extract_isbn(data["isbn_13"]),
        cover_image_url: build_cover_url(original_isbn),
        publisher: data["publishers"]&.first,
        publication_year: extract_year(data["publish_date"]),
        page_count: data["number_of_pages"],
        description: extract_description(data["description"])
      }
    end

    def fetch_author_name(author_key)
      return nil unless author_key

      uri = URI.parse("#{OPEN_LIBRARY_BASE_URL}#{author_key}.json")
      response = fetch_json(uri)
      response&.dig("name")
    rescue StandardError
      nil
    end

    def parse_google_books_response(data)
      volume = data["items"]&.first&.dig("volumeInfo")
      return nil unless volume

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
    end

    def extract_isbn(isbn_array)
      isbn_array&.first
    end

    def extract_year(date_string)
      return nil unless date_string

      match = date_string.to_s.match(/\b(\d{4})\b/)
      match ? match[1].to_i : nil
    end

    def extract_description(description)
      return nil unless description

      description.is_a?(Hash) ? description["value"] : description.to_s
    end

    def build_cover_url(isbn)
      "https://covers.openlibrary.org/b/isbn/#{isbn}-L.jpg"
    end
  end
end
