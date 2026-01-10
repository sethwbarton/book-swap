# frozen_string_literal: true

# Google Cloud Vision API configuration for book image recognition
#
# To configure in production, set credentials via one of:
# 1. Environment variable: GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
# 2. Rails credentials: rails credentials:edit
#    google_cloud:
#      project_id: your-project-id
#      credentials: <base64 encoded service account JSON>
#
# See: https://cloud.google.com/vision/docs/setup

if Rails.application.credentials.dig(:google_cloud, :credentials)
  require "google/cloud/vision"

  Google::Cloud::Vision.configure do |config|
    credentials_json = Base64.decode64(Rails.application.credentials.google_cloud[:credentials])
    config.credentials = JSON.parse(credentials_json)
  end
end
