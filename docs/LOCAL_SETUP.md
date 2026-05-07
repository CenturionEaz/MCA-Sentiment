# MCA eConsultation — Local Setup Guide (No Docker)

## Prerequisites

Install these tools on your machine before proceeding:

| Tool | Version | Download |
|------|---------|----------|
| Java JDK | 17 | https://adoptium.net/temurin/releases/ |
| Maven | 3.9+ | https://maven.apache.org/download.cgi |
| Python | 3.10 | https://www.python.org/downloads/ |
| PostgreSQL | 15 | https://www.postgresql.org/download/ |
| Git | Any | https://git-scm.com/ |

Verify installations:
```bash
java -version          # Should show: openjdk version "17.x.x"
mvn -version           # Should show: Apache Maven 3.9.x
python --version       # Should show: Python 3.10.x
psql --version         # Should show: psql (PostgreSQL) 15.x
```

---

## Step 1 — Clone the Project

```bash
git clone https://github.com/YOUR_USERNAME/mca-econsultation.git
cd mca-econsultation
```

---

## Step 2 — Set Up PostgreSQL Database

### 2a. Create the database

Open psql or pgAdmin and run:
```sql
CREATE DATABASE mca_db;
CREATE USER postgres WITH PASSWORD '1234';
GRANT ALL PRIVILEGES ON DATABASE mca_db TO postgres;
```

Or via command line:
```bash
psql -U postgres -c "CREATE DATABASE mca_db;"
```

### 2b. Verify connection
```bash
psql -U postgres -d mca_db -c "\l"
# Should show mca_db in the list
```

---

## Step 3 — Set Up Python AI Service

### 3a. Create virtual environment
```bash
cd python-ai-service

# Windows
python -m venv .venv
.venv\Scripts\activate

# Linux/Mac
python3 -m venv .venv
source .venv/bin/activate
```

### 3b. Install dependencies
```bash
pip install -r requirements.txt
# This installs: Flask, PyTorch, Transformers, WordCloud, etc.
# NOTE: PyTorch download is large (~2GB). Be patient.
```

### 3c. Start AI service
```bash
python ai_server.py
```

**Expected output:**
```
 * Running on http://0.0.0.0:5001
 * Debug mode: off
INFO: Model loaded successfully
INFO: Flask app starting on port 5001
```

### 3d. Verify AI service is running
Open new terminal:
```bash
curl http://localhost:5001/health
# Expected: {"status": "ok", "model": "loaded"}
```

---

## Step 4 — Configure Backend

### 4a. Set environment variables

**Windows (Command Prompt):**
```cmd
set SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/mca_db
set SPRING_DATASOURCE_USERNAME=postgres
set SPRING_DATASOURCE_PASSWORD=1234
set AI_SERVICE_URL=http://localhost:5001
set GOOGLE_CLIENT_ID=your-google-client-id
set GOOGLE_CLIENT_SECRET=your-google-client-secret
```

**Windows (PowerShell):**
```powershell
$env:SPRING_DATASOURCE_URL="jdbc:postgresql://localhost:5432/mca_db"
$env:SPRING_DATASOURCE_PASSWORD="1234"
$env:AI_SERVICE_URL="http://localhost:5001"
```

**Linux/Mac:**
```bash
export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/mca_db
export SPRING_DATASOURCE_PASSWORD=1234
export AI_SERVICE_URL=http://localhost:5001
```

---

## Step 5 — Build and Run the Backend

```bash
# Navigate back to project root
cd ..   # (if you're still in python-ai-service/)

# Build the project
mvn clean package -DskipTests

# Run it
mvn spring-boot:run
```

**Alternative — run the JAR directly:**
```bash
mvn clean package -DskipTests
java -jar target/econsultation-1.0.0.jar
```

**Expected output:**
```
  .   ____          _            __ _ _
 /\\ / ___'_ __ _ _(_)_ __  __ _ \ \ \ \
Started EconsultationApplication in 12.345 seconds
Tomcat started on port(s): 8080
```

---

## Step 6 — Access the Application

Open your browser:
```
http://localhost:8080
```

You should see the MCA eConsultation dashboard/login page.

---

## Troubleshooting

### ❌ "Connection refused" on port 5432
- PostgreSQL is not running
- Fix: `pg_ctl start` or start PostgreSQL service from Services panel

### ❌ "AI service connection refused"
- Python AI service is not running
- Fix: Start it with `python ai_server.py` in a separate terminal

### ❌ "Port 8080 already in use"
```bash
# Find what's using port 8080
netstat -ano | findstr :8080    # Windows
lsof -i :8080                   # Linux/Mac

# Kill the process
taskkill /PID <PID> /F          # Windows
kill -9 <PID>                   # Linux/Mac
```

### ❌ Maven build fails
```bash
mvn clean install -DskipTests -X   # Verbose output for debugging
```

### ❌ Python import errors
```bash
pip list | grep torch      # Verify torch is installed
pip install --upgrade pip
pip install -r requirements.txt --force-reinstall
```
