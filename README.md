# README

## Local Dev Notes

- Run the dev server with `bin/dev`

- Run the Stripe CLI to receive webhook notifications at localhost with
  `stripe listen --forward-to localhost:3000/webhooks/stripe`
  You may have to re-add a new key (if the old one expired) with `VISUAL="vim" rails credentials:edit --environment
development`

## Deployment

### Server Access

- **Server IP:** `5.78.125.193` (Hetzner Cloud)
- **SSH Command:** `ssh root@5.78.125.193`
- **SSH Auth:** Key-only (via 1Password SSH agent)

### Prerequisites (One-Time Setup)

1. **Google Cloud Artifact Registry** - Create a repository:
   ```bash
   gcloud artifacts repositories create book-swap \
     --repository-format=docker \
     --location=us-central1 \
     --project=docker-images-484521
   ```

2. **Service Account** - Create and download a JSON key with Artifact Registry Writer permissions:
   ```bash
   # Create service account
   gcloud iam service-accounts create kamal-deployer \
     --display-name="Kamal Deployer" \
     --project=docker-images-484521

   # Grant permissions
   gcloud projects add-iam-policy-binding docker-images-484521 \
     --member="serviceAccount:kamal-deployer@docker-images-484521.iam.gserviceaccount.com" \
     --role="roles/artifactregistry.writer"

   # Download JSON key (temporarily, then delete after storing in 1Password/GitHub)
   gcloud iam service-accounts keys create kamal-deployer-key.json \
     --iam-account=kamal-deployer@docker-images-484521.iam.gserviceaccount.com
   ```

3. **Store secrets in 1Password** - Create an item called `book-swap-deploy` in the "Book Swap" vault with:
   - `gcp-service-account-key`: Raw JSON contents of `kamal-deployer-key.json`
   - `rails-master-key`: Contents of `config/master.key`

4. **Store secrets in GitHub** - Add these repository secrets (Settings > Secrets > Actions):
   - `GCP_SERVICE_ACCOUNT_KEY`: Base64-encoded GCP service account JSON (`base64 -i kamal-deployer-key.json`)
   - `RAILS_MASTER_KEY`: Contents of `config/master.key`
   - `SSH_PRIVATE_KEY`: SSH private key for server access

5. **Domain** - Update `config/deploy.yml` with your domain (line 22) and point DNS to the server IP.

6. **Delete the JSON key file** - Once stored in 1Password and GitHub, delete `kamal-deployer-key.json`.

### Deploying

#### Automatic (GitHub Actions)

Pushes to `main` trigger automatic deployment after CI passes. You can also manually trigger a deploy from the Actions tab.

#### Local Deploy

Requires 1Password CLI (`op`) installed and signed in:

```bash
# First-time setup
bin/kamal setup

# Subsequent deploys
bin/kamal deploy
```

### Useful Kamal Commands

```bash
bin/kamal logs          # Tail application logs
bin/kamal console       # Rails console on server
bin/kamal shell         # Bash shell on server
bin/kamal app exec 'bin/rails db:migrate'  # Run migrations
```

### Troubleshooting

If deployment fails and you need direct server access:

```bash
ssh root@5.78.125.193
docker ps -a            # See all containers
docker logs <container> # Check container logs
```

## Notes for Deploying to Prod

- Must create new Stripe account and get everything set up. Credentials file must be set.
- Must create new Google Books API Key for Prod (project book-swap-prod) and save in credentials.