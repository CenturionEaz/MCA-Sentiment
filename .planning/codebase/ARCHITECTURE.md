# Codebase Architecture

## System Architecture
The application follows a loosely coupled microservices-style architecture combining a traditional monolith backend with a dedicated AI microservice.

### 1. Spring Boot Backend (Java)
- Acts as the primary web server and user-facing application (Port 8080).
- **Responsibilities**:
  - Serves web pages using Thymeleaf templates.
  - Handles authentication (Local + Google OAuth2).
  - Manages database interactions via Spring Data JPA.
  - Parses uploaded CSV files and structures data.
  - Generates downloadable reports (CSV, PDF using iText 7).
  - Orchestrates calls to the Python AI service.

### 2. Python AI Service (Flask)
- A standalone REST API serving ML model inferences (Port 5001).
- **Responsibilities**:
  - Sentiment classification using RoBERTa.
  - Abstractive chunk-based summarization using BART.
  - Word cloud image generation with domain-specific stopword filtering.
  - Attention-based explainability and model evaluation.

### 3. Database (PostgreSQL)
- Stores persistent state.
- **Key Tables**:
  - `users`: Stores user credentials and profile information.
  - `analysis_history`: Tracks past analysis executions, keeping a record of aggregate statistics (positive, neutral, negative percentages) and timestamps.

## Data Flow (Analysis Execution)
1. User uploads a CSV file containing `comment_text` via the Spring Boot dashboard.
2. `AnalysisController` receives the file, and hands it off to service classes.
3. `SentimentService`, `SummaryService`, and `WordCloudService` make HTTP POST requests to the Flask AI Service.
4. Python AI Service runs inferences on the data batches and returns structured JSON responses.
5. Spring Boot aggregates the ML results, saves summary metrics to the database (`AnalysisHistory`), and renders the result on the Dashboard UI.
