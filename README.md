# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Local Dev Notes

- Run the dev server with `bin/dev`

- Run the Stripe CLI to receive webhook notifications at localhost with
  `stripe listen --forward-to localhost:3000/webhooks/stripe`
  You may have to re-add a new key (if the old one expired) with `VISUAL="vim" rails credentials:edit --environment
development`

## Notes for Deploying to Prod

- Must create new Stripe account and get everything set up. Credentials file must be set.
- Must create new Google Books API Key for Prod (project book-swap-prod) and save in credentials.