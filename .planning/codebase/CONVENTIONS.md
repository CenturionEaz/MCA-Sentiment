# Codebase Conventions

## Java Backend Conventions
- **Architecture**: Standard Spring MVC layered architecture (Controller -> Service -> Repository -> Database).
- **Entity Management**: Uses JPA annotations for ORM. Lombok is used (`@Data`, `@Getter`, `@Setter`, etc.) to reduce boilerplate code in models and DTOs.
- **Dependency Injection**: Constructor-based dependency injection is favored (often using Lombok's `@RequiredArgsConstructor` or standard constructor wiring).
- **Views**: Thymeleaf templates are used for SSR (Server-Side Rendering), keeping views relatively simple and driven by model attributes provided by controllers.
- **Error Handling**: Uses Spring's built-in validation (`spring-boot-starter-validation`) and standard MVC exception handling.

## Python AI Service Conventions
- **Modularity**: AI tasks are separated into logical modules (`preprocessing.py`, `evaluation.py`, `explainability.py`) rather than dumping everything in the Flask server file.
- **Configuration**: Hyperparameters and setup variables are centralized in `config.py`.
- **Device Management**: Automatic hardware acceleration detection (CUDA, MPS for Apple Silicon, or CPU fallback) ensures models run optimally on available hardware.
- **Logging**: Implements rotating file logs to manage log size effectively.
- **API Responses**: Standardized JSON responses for predictable parsing by the Java backend.

## General Repository Conventions
- **Environment Agnosticism**: Configuration variables (like Database URLs, AI Service URLs) are externalized in `application.properties` and docker-compose configurations.
- **Documentation**: A comprehensive README.md provides setup, architecture, and running instructions.
