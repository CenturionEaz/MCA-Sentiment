# Codebase Structure

The repository is structured as a monorepo containing both the main Spring Boot application and the auxiliary Python AI service.

## Root Directory
- `pom.xml`: Maven configuration and dependencies for the Java backend.
- `docker-compose.yml`: Multi-container orchestration (Postgres, Spring Boot, Python AI).
- `Dockerfile`: Multi-stage build for the Spring Boot application.
- `sample_data.csv`: Example input data.

## Java Backend (`src/`)
- `src/main/java/com/mca/econsult/`: Root package.
  - `MCAApplication.java`: Application entry point.
  - `config/`: Contains security and OAuth2 configurations (`SecurityConfig.java`).
  - `controller/`: REST and MVC controllers (`AuthController`, `AnalysisController`, `HistoryController`).
  - `service/`: Business logic and external API orchestration (`SentimentService`, `SummaryService`, `WordCloudService`, `ReportService`, `UserService`).
  - `model/`: JPA Entities (`User`, `AnalysisHistory`).
  - `repository/`: Spring Data JPA interfaces (`UserRepository`, `HistoryRepository`).
- `src/main/resources/`:
  - `application.properties`: Configuration properties.
  - `templates/`: Thymeleaf HTML views (`index.html`, `dashboard.html`, `login.html`, `signup.html`, `history.html`).
  - `static/`: Static assets (CSS, JS) and dynamically generated files (wordclouds, PDFs).

## Python AI Service (`python-ai-service/`)
- `ai_server.py`: Main Flask application and endpoint definitions.
- `config.py`: Hyperparameters and global settings.
- `preprocessing.py`: NLP text cleaning pipelines.
- `evaluation.py`: Model evaluation logic (Accuracy, F1, Confusion Matrix).
- `explainability.py`: XAI attention visualization logic.
- `requirements.txt`: Pip dependencies.
- `Dockerfile`: Container configuration for the AI service.

## Other Directories
- `research_paper/`: Documentation and IEEE formatted papers explaining the methodology.
