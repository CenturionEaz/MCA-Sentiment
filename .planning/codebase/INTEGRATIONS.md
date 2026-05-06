# Codebase Integrations

## External Integrations

### Google OAuth2
- **Purpose**: Provides single sign-on (SSO) authentication for users via their Google accounts.
- **Configuration**: Managed in `application.properties` using `spring.security.oauth2.client.registration.google`.
- **Flow**: Follows standard OAuth2 authorization code flow, managed automatically by Spring Security OAuth2 Client.

### HuggingFace Models
- **Purpose**: Provides pre-trained weights for RoBERTa and BART-large-CNN models.
- **Mechanism**: The Python AI Service automatically downloads model weights (~2GB) on the first run if they are not already cached locally. Can also use locally fine-tuned models if present in `policy_sentiment_final/`.

## Internal Integrations

### Spring Boot to Python AI Service
- **Purpose**: Spring Boot handles user requests, parses CSVs, and delegates heavy machine learning processing to the standalone Python AI Service.
- **Communication Protocol**: HTTP POST REST APIs.
- **Endpoints**:
  - `/predict` / `/predict_legacy` for Sentiment Classification
  - `/summarize` for Abstractive Summarization
  - `/wordcloud` for Visualization
  - `/explain` for Explainability (XAI)
  - `/evaluate` for Model Evaluation
- **Configuration**: The AI service URL is configurable in `application.properties` via `ai.service.url` (default: `http://localhost:5001`).
