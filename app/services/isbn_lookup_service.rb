# frozen_string_literal: true

class IsbnLookupService
  OPEN_LIBRARY_BASE_URL = "https://openlibrary.org"
  GOOGLE_BOOKS_BASE_URL = "https://www.googleapis.com/books/v1/volumes"

  class << self
    def lookup(isbn)
      normalized_isbn = normalize_isbn(isbn)
      return nil unless valid_isbn?(normalized_isbn)

      result = lookup_open_library(normalized_isbn)
      if result.nil?
        Rails.logger.info("Open Library lookup failed for ISBN #{normalized_isbn}, falling back to Google Books API")
        result = lookup_google_books(normalized_isbn)
      end
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
      response = http_client.get("#{OPEN_LIBRARY_BASE_URL}/isbn/#{isbn}.json")
      return nil unless response.success?

      parse_open_library_response(JSON.parse(response.body), isbn)
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("Open Library lookup error: #{e.message}")
      nil
    end

    def lookup_google_books(isbn)
      api_key = Rails.application.credentials.dig(:google_books_api_key)
      params = { q: "isbn:#{isbn}" }
      params[:key] = api_key if api_key.present?

      response = http_client.get(GOOGLE_BOOKS_BASE_URL, params)
      Rails.logger.info("Response from Google Books API: #{response.success?}")
      return nil unless response.success?

      data = JSON.parse(response.body)
      Rails.logger.info("Google Books Response DATA: #{data}")
      return nil unless data["totalItems"].to_i > 0

      parse_google_books_response(data)
    rescue Faraday::Error, JSON::ParserError => e
      Rails.logger.error("Google Books lookup error: #{e.message}")
      nil
    end

    def http_client
      @http_client ||= Faraday.new do |f|
        f.options.timeout = 10
        f.options.open_timeout = 5
      end
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

      response = http_client.get("#{OPEN_LIBRARY_BASE_URL}#{author_key}.json")
      return nil unless response.success?

      JSON.parse(response.body)["name"]
    rescue Faraday::Error, JSON::ParserError
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
