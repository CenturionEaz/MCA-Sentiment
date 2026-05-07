# MCA eConsultation — Docker Setup Guide

## Prerequisites

| Tool | Version | Download |
|------|---------|----------|
| Docker Desktop | 24+ | https://www.docker.com/products/docker-desktop/ |
| Docker Compose | v2 (bundled) | Included with Docker Desktop |

Verify:
```bash
docker --version          # Docker version 24.x.x
docker compose version    # Docker Compose version v2.x.x
```

---

## Part A — Build Docker Images Individually

### Build 1: Spring Boot Backend

```bash
# From project ROOT directory (where Dockerfile exists)
cd mca-econsultation

docker build -t mca-backend:latest .
```

**What this does:**
1. Reads `Dockerfile` in project root
2. Stage 1: Compiles Java with Maven inside container (`mvn clean package`)
3. Stage 2: Copies only the JAR to a lightweight JRE image
4. Tags the result as `mca-backend:latest`

**Verify the image was built:**
```bash
docker images | grep mca-backend
# mca-backend    latest    abc123def456    2 minutes ago    350MB
```

---

### Build 2: Python AI Service

```bash
docker build -t mca-ai-service:latest ./python-ai-service
```

**What this does:**
1. Reads `python-ai-service/Dockerfile`
2. Installs gcc, curl (system deps)
3. `pip install -r requirements.txt` (PyTorch + Transformers — takes ~5 min)
4. Copies Flask app code
5. Tags as `mca-ai-service:latest`

**Verify:**
```bash
docker images | grep mca-ai-service
# mca-ai-service    latest    xyz789abc    5 minutes ago    4.2GB (PyTorch is large)
```

---

### Test Images Individually (Optional)

```bash
# Test AI service alone
docker run -p 5001:5001 mca-ai-service:latest
curl http://localhost:5001/health

# Test backend alone (will fail to connect to DB — expected)
docker run -p 8080:8080 \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://host.docker.internal:5432/mca_db \
  -e SPRING_DATASOURCE_PASSWORD=1234 \
  -e AI_SERVICE_URL=http://host.docker.internal:5001 \
  mca-backend:latest
```

---

## Part B — Docker Compose (Run Everything Together)

### Step 1: Create .env file

```bash
cp .env.example .env
```

Edit `.env`:
```env
POSTGRES_USER=postgres
POSTGRES_PASSWORD=YourStrongPassword123!
GOOGLE_CLIENT_ID=your-google-oauth-client-id
GOOGLE_CLIENT_SECRET=your-google-oauth-client-secret
```

> ⚠️ **Never commit `.env` to Git.** It's already in `.gitignore`.

---

### Step 2: Start All Services

```bash
# Build images AND start all containers
docker compose up --build

# OR: if images already built, just start
docker compose up

# OR: run in background (detached mode)
docker compose up -d
```

**What starts:**
1. `mca-postgres` — PostgreSQL 15 (waits for healthcheck)
2. `mca-ai-service` — Flask AI service (waits for model load)
3. `mca-backend` — Spring Boot (waits for both above)

**Watch logs as they start:**
```bash
docker compose logs -f                  # All services
docker compose logs -f app              # Backend only
docker compose logs -f ai-service       # AI service only
docker compose logs -f postgres         # Database only
```

---

### Step 3: Verify Everything is Running

```bash
docker compose ps
```

**Expected output:**
```
NAME              IMAGE               STATUS                    PORTS
mca-postgres      postgres:15         Up (healthy)              0.0.0.0:5432->5432/tcp
mca-ai-service    mca-ai-service      Up (healthy)              0.0.0.0:5001->5001/tcp
mca-backend       mca-backend         Up                        0.0.0.0:8080->8080/tcp
```

**Test each service:**
```bash
# Test AI service health
curl http://localhost:5001/health

# Test backend
curl http://localhost:8080/actuator/health   # if actuator enabled
# OR just open browser: http://localhost:8080
```

---

### Step 4: Access the Application

```
http://localhost:8080
```

---

## Part C — Useful Docker Commands

### Container Management
```bash
# Stop all services (containers removed, volumes kept)
docker compose down

# Stop AND remove volumes (WIPES ALL DATA)
docker compose down -v

# Restart a single service
docker compose restart app

# Rebuild only the backend image and restart
docker compose up --build app
```

### Debugging
```bash
# Get a shell inside the backend container
docker exec -it mca-backend bash

# Get a shell inside the AI service container
docker exec -it mca-ai-service bash

# Check backend logs (last 100 lines)
docker logs mca-backend --tail 100

# Check AI service logs
docker logs mca-ai-service --tail 100 -f

# Connect to the database directly
docker exec -it mca-postgres psql -U postgres -d mca_db
```

### Resource Monitoring
```bash
# See CPU/Memory usage of all containers
docker stats

# Inspect network
docker network ls
docker network inspect mca-econsultation_mca-network
```

---

## Part D — Push Images to DockerHub

> This step is required BEFORE Kubernetes deployment.

### Step 1: Create DockerHub Account
Go to https://hub.docker.com/ and create an account.

### Step 2: Login
```bash
docker login
# Enter your DockerHub username and password
```

### Step 3: Tag Images with Your Username
```bash
# Replace YOUR_USERNAME with your DockerHub username (e.g., akash123)
docker tag mca-backend:latest YOUR_USERNAME/mca-backend:latest
docker tag mca-ai-service:latest YOUR_USERNAME/mca-ai-service:latest
```

### Step 4: Push Images
```bash
docker push YOUR_USERNAME/mca-backend:latest
docker push YOUR_USERNAME/mca-ai-service:latest
```

### Step 5: Update Kubernetes Deployments
In `k8s/backend/deployment.yaml` and `k8s/ai-service/deployment.yaml`,
replace `YOUR_DOCKERHUB_USERNAME` with your actual DockerHub username.

```yaml
# k8s/backend/deployment.yaml (line with image:)
image: YOUR_USERNAME/mca-backend:latest

# k8s/ai-service/deployment.yaml (line with image:)
image: YOUR_USERNAME/mca-ai-service:latest
```

---

## DockerHub Image URLs

After pushing, your images are at:
```
https://hub.docker.com/r/YOUR_USERNAME/mca-backend
https://hub.docker.com/r/YOUR_USERNAME/mca-ai-service
```

Pull them anywhere with:
```bash
docker pull YOUR_USERNAME/mca-backend:latest
docker pull YOUR_USERNAME/mca-ai-service:latest
```
