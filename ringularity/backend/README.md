# 💍 Ringularity Backend

![Rails](https://img.shields.io/badge/rails-%23CC0000.svg?style=for-the-badge&logo=ruby-on-rails&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Postgres](https://img.shields.io/badge/postgres-%23316192.svg?style=for-the-badge&logo=postgresql&logoColor=white)

This is the **Ruby on Rails API** serving as the backbone for the Ringularity health tracking ecosystem. It handles data persistence, user authentication, and serves health metrics to the Flutter mobile application.

## 🏗 Architectural Overview

The backend is built with **Ruby on Rails 7** (API mode) and follows a classic MVC pattern, optimized for health data retrieval:

* **API Layer:** RESTful endpoints for vitals (HR, HRV, Stress, Sleep) and activity logs.
* **Authentication:** Secure user management and session handling.
* **Database:** PostgreSQL for robust relational data storage.
* **Containerization:** Fully containerized using Docker for consistent deployment.

---

## 🛠 Tech Stack

* **Framework:** Ruby on Rails 7 (API Mode)
* **Language:** Ruby
* **Database:** PostgreSQL
* **Containerization:** Docker & Docker Compose
* **Server:** Puma

---

## 🔐 Security & Master Key

Since the `master.key` is never stored in the repository, it must be generated when setting up the project for the first time.

### Generating a New Master Key
If you are setting up the project from scratch and do not have a key, delete the existing `config/credentials.yml.enc` (if present) and run:
`bin/rails credentials:edit`

Rails will automatically generate a new config/master.key and a corresponding encrypted credentials file. Make sure to store this key in a secure location!

### Editing Secrets

To add or modify environment secrets (like API keys), use: `EDITOR="nano" bin/rails credentials:edit`

---

## ⚙️ Environment Variables
The application relies on environment variables for database configuration (see `config/database.yml). For local development, you can create a .env file in the root directory:

```
DB_HOST=localhost
DB_NAME=ringularity_production
DB_USER=postgres
DB_PASSWORD=your_password
RAILS_MASTER_KEY=your_generated_key
```

---

## 🚦 Development Workflows

You can develop locally using a direct Rails installation (faster for coding) or via Docker (best for environment consistency).

### 💻 Option A: Local Development (Recommended for Coding)
Use this if you have Ruby and PostgreSQL installed on your machine.
* **Navigate to the backend directory:** `cd ringularity/backend`
* **Install dependencies:** `bundle install`
* **Setup database:** `bin/rails db:prepare`
* **Start Server:** `bin/rails s -b 0.0.0.0`

<i>(Note: Using -b 0.0.0.0 allows access from other devices in your local network, such as your Flutter test device or emulator).</i>

### 🐳 Option B: Docker Development
Use this to avoid local installations or to test the production-like environment.
* **Build and start containers:** `docker-compose up --build`
* **Prepare database (first time):** `docker-compose run web bin/rails db:prepare`

---

## 🔗 Integration with Flutter (Frontend)

To connect the Flutter application to this backend, you must ensure the API endpoint matches your environment.

* **File to modify:** `services/api/api_service.dart` in the Flutter project. 

---

## 🔍 API Health Check

To verify if the backend is running correctly (especially when troubleshooting Docker or network issues), you can use the built-in "alive" endpoint:

* **Endpoint:** `GET /api/alive`
* **Expected Response:** `{"status": "ok"}`

You can also open your browser to `http://localhost:3000/api/alive` to verify the same response.

---

## 🚢 Deployment (Production)

The backend is deployed via Docker. On the production server (e.g., FH internal server), the container is managed through a shell script to ensure security.

**Deployment Script** (run_docker.sh)

Important: Never commit the actual script or the master.key to version control. The script on the server should look like this:

```bash 
sudo docker run -d \
  --name ringularity-app \
  -p 3000:3000 \
  -e RAILS_ENV=production \
  -e RAILS_MASTER_KEY="your_actual_master_key_here" \
  -e DB_HOST="10.25.6.11" \
  -e DB_NAME="postgres" \
  -e DB_USER="postgres" \
  -e DB_PASSWORD="your_db_password" \
  <your-username>/ringularity:latest
```

**Updating the Production Server**

* **Build and push from local:** `docker build -t <your-username>/ringularity:latest .`
* **Push to Docker Hub:** `docker push <your-username>/ringularity:latest`
* **On the server:** `sudo docker pull <your-username>/ringularity:latest`
* Restart the container using your run script

---

## 📂 Project Structure
`app/controllers/api/`: API logic for vitals, users, and activities.

`app/models/`: Data models for SleepLogs, HeartRateLogs, HRV, etc.

`db/migrate/`: Database schema evolution.

`config/`: Environment-specific configurations and secrets.

---

## 🎓 Contribution Notes 
* **Database Changes:** Always use migrations (rails generate migration your_migration_name).

* **Security:** If you add new environment variables, ensure they are also added to the production run_docker.sh on the server.

---

### 📖 API Documentation
This project uses YARD for documentation. To generate the latest HTML documentation, run:
`bundle exec yard doc 'app/**/*.rb'`
Then open `doc/index.html` in your browser.

---

<i>Note: This project was developed as a Bachelor Project for educational purposes.</i>

