class AIFactory {
  static create(
    provider: AIProvider,
    settings: AIProviderSettings
  ): AIInterface {
    switch (provider) {
      case AIProvider.OPENAI:
        return new OpenAIService(settings);
      case AIProvider.GEMINI:
        return new GeminiService(settings);
      // ... 其他 AI 提供商
      default:
        throw new Error(`不支持的 AI 提供商: ${provider}`);
    }
  }
} 