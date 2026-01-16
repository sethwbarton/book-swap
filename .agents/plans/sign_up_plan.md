# Sign-Up with Email Confirmation Plan

## Overview

Implement user registration with email confirmation. Currently users can only sign in if their account is seeded in the database. This plan adds a complete sign-up flow.

### Flow

1. User visits `/sign_up`
2. Enters email + password + password confirmation
3. Account created (unconfirmed)
4. Confirmation email sent with tokenized link
5. User clicks link -> account confirmed -> auto-logged in
6. Unconfirmed users cannot log in (with option to resend confirmation)

### Key Decisions

- **Unconfirmed users**: Blocked from logging in entirely
- **Resend confirmation**: Yes, available from login page
- **Post-confirmation**: Auto-login and redirect to app
- **Development emails**: Use `letter_opener` gem

---

## Phase 1: Setup & Infrastructure

### 1.1 Add letter_opener gem

Add to `Gemfile` in development group:

```ruby
group :development do
  gem "letter_opener"
end
```

Configure in `config/environments/development.rb`:

```ruby
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.perform_deliveries = true
```

### 1.2 Database Migration

Create migration to add email confirmation tracking:

```bash
rails generate migration AddEmailConfirmationToUsers email_confirmed_at:datetime
```

Only need `email_confirmed_at` because:
- `nil` = unconfirmed
- Timestamp = confirmed
- Token is stateless (signed by Rails, not stored)

### 1.3 User Model Updates

Add to `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_secure_password
  
  # Token for email confirmation (24 hour expiry)
  # Token invalidates when email_confirmed_at changes
  generates_token_for :email_confirmation, expires_in: 24.hours do
    email_confirmed_at
  end
  
  # ... existing associations ...
  
  def confirmed?
    email_confirmed_at.present?
  end
  
  def confirm_email!
    update!(email_confirmed_at: Time.current)
  end
end
```

---

## Phase 2: Registration Flow

### 2.1 Routes

Add to `config/routes.rb`:

```ruby
resources :registrations, only: [:new, :create]
resource :email_confirmation, only: [:show, :new, :create]
# show = confirm via token (GET /email_confirmation?token=xxx)
# new = resend form (GET /email_confirmation/new)
# create = send resend email (POST /email_confirmation)
```

### 2.2 RegistrationsController

Create `app/controllers/registrations_controller.rb`:

```ruby
class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 1.hour, only: :create, with: -> { 
    redirect_to new_registration_path, alert: "Too many sign-up attempts. Try again later." 
  }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    
    if @user.save
      RegistrationMailer.confirmation(@user).deliver_later
      redirect_to new_session_path, notice: "Check your email to confirm your account."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
  
  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
```

### 2.3 Registration Form View

Create `app/views/registrations/new.html.erb`:

- Email field
- Password field
- Password confirmation field
- Submit button
- Link to sign in page

Style to match existing session/new.html.erb form.

### 2.4 RegistrationMailer

Create `app/mailers/registration_mailer.rb`:

```ruby
class RegistrationMailer < ApplicationMailer
  def confirmation(user)
    @user = user
    mail(to: user.email_address, subject: "Confirm your Book Swap account")
  end
end
```

### 2.5 Email Templates

Create `app/views/registration_mailer/confirmation.html.erb`:

```erb
<p>Welcome to Book Swap!</p>

<p>Please confirm your email address by clicking the link below:</p>

<p><%= link_to "Confirm my account", email_confirmation_url(token: @user.generate_token_for(:email_confirmation)) %></p>

<p>This link will expire in 24 hours.</p>
```

Create `app/views/registration_mailer/confirmation.text.erb`:

```erb
Welcome to Book Swap!

Please confirm your email address by visiting:

<%= email_confirmation_url(token: @user.generate_token_for(:email_confirmation)) %>

This link will expire in 24 hours.
```

---

## Phase 3: Email Confirmation

### 3.1 EmailConfirmationsController

Create `app/controllers/email_confirmations_controller.rb`:

```ruby
class EmailConfirmationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 1.hour, only: :create, with: -> {
    redirect_to new_email_confirmation_path, alert: "Too many requests. Try again later."
  }

  # GET /email_confirmation?token=xxx
  def show
    user = User.find_by_token_for(:email_confirmation, params[:token])
    
    if user.nil?
      redirect_to new_session_path, alert: "Confirmation link is invalid or has expired."
    elsif user.confirmed?
      redirect_to new_session_path, notice: "Email already confirmed. Please sign in."
    else
      user.confirm_email!
      start_new_session_for(user)
      redirect_to after_authentication_url, notice: "Email confirmed! Welcome to Book Swap."
    end
  end

  # GET /email_confirmation/new (resend form)
  def new
  end

  # POST /email_confirmation (resend email)
  def create
    user = User.find_by(email_address: params[:email_address])
    
    if user && !user.confirmed?
      RegistrationMailer.confirmation(user).deliver_later
    end
    
    # Always show success message (security: don't reveal if email exists)
    redirect_to new_session_path, notice: "If that email exists and is unconfirmed, we've sent a new confirmation link."
  end
end
```

### 3.2 Resend Confirmation View

Create `app/views/email_confirmations/new.html.erb`:

- Email field
- Submit button ("Resend confirmation email")
- Link back to sign in

---

## Phase 4: Login Gate

### 4.1 Update SessionsController

Modify `app/controllers/sessions_controller.rb` to block unconfirmed users:

```ruby
def create
  if user = User.authenticate_by(params.permit(:email_address, :password))
    if user.confirmed?
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Please confirm your email before signing in. Need a new link? <a href='#{new_email_confirmation_path}' class='underline'>Resend confirmation</a>".html_safe
    end
  else
    redirect_to new_session_path, alert: "Invalid email or password."
  end
end
```

### 4.2 Update Login View

Modify `app/views/sessions/new.html.erb`:

- Add "Sign up" link for new users
- Ensure flash messages can render HTML (for resend link)

---

## Phase 5: Tests (TDD)

Write tests BEFORE implementing each phase.

### 5.1 System Test

Create `test/system/sign_up_test.rb`:

```ruby
require "application_system_test_case"

class SignUpTest < ApplicationSystemTestCase
  test "full sign-up flow with email confirmation" do
    # Visit sign up page
    visit new_registration_path
    
    # Fill in form
    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "password123"
    fill_in "Password confirmation", with: "password123"
    click_button "Sign up"
    
    # Should redirect to sign in with message
    assert_text "Check your email to confirm your account"
    
    # Email should be sent
    assert_equal 1, ActionMailer::Base.deliveries.size
    
    # Extract token from email and visit confirmation link
    email = ActionMailer::Base.deliveries.last
    token = extract_token_from_email(email)
    visit email_confirmation_path(token: token)
    
    # Should be logged in and redirected
    assert_text "Email confirmed!"
    assert_current_path books_path
  end
  
  test "unconfirmed user cannot sign in" do
    # Create unconfirmed user
    user = User.create!(email_address: "unconfirmed@example.com", password: "password123")
    
    visit new_session_path
    fill_in "Email", with: "unconfirmed@example.com"
    fill_in "Password", with: "password123"
    click_button "Sign in"
    
    assert_text "Please confirm your email"
  end
end
```

### 5.2 Integration Tests

Create `test/controllers/registrations_controller_test.rb`:

- Test successful registration creates user
- Test validation errors render form
- Test confirmation email is sent
- Test rate limiting

Create `test/controllers/email_confirmations_controller_test.rb`:

- Test valid token confirms user and logs in
- Test expired token shows error
- Test invalid token shows error
- Test already confirmed user redirects appropriately
- Test resend sends email for unconfirmed user
- Test resend doesn't reveal if email exists

### 5.3 Model Tests

Add to `test/models/user_test.rb`:

- Test `confirmed?` returns false when `email_confirmed_at` is nil
- Test `confirmed?` returns true when `email_confirmed_at` is set
- Test `confirm_email!` sets timestamp
- Test token generation and validation

### 5.4 Mailer Tests

Create `test/mailers/registration_mailer_test.rb`:

- Test confirmation email is sent to correct address
- Test email contains confirmation link
- Test email subject is correct

---

## Phase 6: Fixture Updates

Update `test/fixtures/users.yml` to include confirmed users:

```yaml
seller_one:
  email_address: seller1@example.com
  password_digest: <%= BCrypt::Password.create('password') %>
  email_confirmed_at: <%= 1.day.ago %>

unconfirmed_user:
  email_address: unconfirmed@example.com
  password_digest: <%= BCrypt::Password.create('password') %>
  email_confirmed_at: null
```

---

## Files Summary

### New Files

| File | Purpose |
|------|---------|
| `db/migrate/*_add_email_confirmation_to_users.rb` | Migration |
| `app/controllers/registrations_controller.rb` | Sign-up form & creation |
| `app/controllers/email_confirmations_controller.rb` | Confirm & resend |
| `app/mailers/registration_mailer.rb` | Confirmation email |
| `app/views/registrations/new.html.erb` | Sign-up form |
| `app/views/email_confirmations/new.html.erb` | Resend form |
| `app/views/registration_mailer/confirmation.html.erb` | Email HTML |
| `app/views/registration_mailer/confirmation.text.erb` | Email text |
| `test/system/sign_up_test.rb` | System test |
| `test/controllers/registrations_controller_test.rb` | Controller test |
| `test/controllers/email_confirmations_controller_test.rb` | Controller test |
| `test/mailers/registration_mailer_test.rb` | Mailer test |

### Modified Files

| File | Changes |
|------|---------|
| `Gemfile` | Add letter_opener |
| `config/environments/development.rb` | Configure letter_opener |
| `config/routes.rb` | Add registration & confirmation routes |
| `app/models/user.rb` | Add token generation, confirmed?, confirm_email! |
| `app/controllers/sessions_controller.rb` | Block unconfirmed users |
| `app/views/sessions/new.html.erb` | Add sign-up link |
| `test/fixtures/users.yml` | Add email_confirmed_at to fixtures |

---

## Implementation Order

Following TDD principles, implement in this order:

1. **Setup**: letter_opener gem, migration, model methods
2. **Test first**: Write system test for full flow (will fail)
3. **Registration**: Controller, views, mailer (partial test pass)
4. **Confirmation**: Controller, views (more tests pass)
5. **Login gate**: Update sessions controller (all tests pass)
6. **Refactor**: Clean up, ensure all edge cases covered

---

## ActionMailer Learning Notes

For reference when implementing:

### Mailer Basics

```ruby
# Mailers are like controllers - actions render views
class RegistrationMailer < ApplicationMailer
  def confirmation(user)
    @user = user  # Instance vars available in views
    mail(to: user.email_address, subject: "Confirm your account")
  end
end
```

### Sending Email

```ruby
# Async (recommended) - uses Solid Queue
RegistrationMailer.confirmation(user).deliver_later

# Sync (blocks request)
RegistrationMailer.confirmation(user).deliver_now
```

### Email Views

- Located in `app/views/mailer_name/action_name.html.erb`
- Create both `.html.erb` and `.text.erb` for multipart emails
- Use `*_url` helpers (not `*_path`) for absolute URLs in emails

### Testing Emails

```ruby
# Emails collected in test mode
assert_emails 1 do
  RegistrationMailer.confirmation(user).deliver_now
end

# Access sent emails
email = ActionMailer::Base.deliveries.last
assert_equal ["user@example.com"], email.to
assert_match /Confirm/, email.subject
```

### letter_opener in Development

- Intercepts all outgoing emails
- Opens them in browser automatically
- No SMTP configuration needed
- Emails stored in `tmp/letter_opener/`
