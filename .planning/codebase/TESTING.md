# Codebase Testing

## Java Backend
- **Framework**: `spring-boot-starter-test` is included, providing JUnit, Mockito, and Spring TestContext Framework.
- **Execution**: Tests can be run via Maven (`mvn test`). Currently, building skips tests via `-DskipTests` in the standard build instructions, suggesting comprehensive unit test coverage may be a future enhancement area.

## Python AI Service
- **Evaluation Pipeline**: A dedicated `evaluation.py` module exists to measure AI model performance.
- **Metrics**: Computes standard ML metrics including:
  - Accuracy
  - Precision
  - Recall
  - F1-Score
  - Confusion Matrix (generated as both JSON and PNG images for visualization).
- **Usage**: Evaluations can be triggered via the `/evaluate` REST endpoint on the AI service.

## Integration Testing
- Due to the dual-service nature of the app, full integration testing requires both the Postgres database and the AI Service to be running.
- `docker-compose.yml` provides a unified environment suitable for end-to-end integration testing.
