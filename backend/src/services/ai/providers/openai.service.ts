class OpenAIService implements AIInterface {
  private client: any; // OpenAI 客户端实例

  constructor(private settings: AIProviderSettings) {
    this.initializeClient();
  }

  async chat(prompt: string): Promise<string> {
    try {
      const response = await this.client.chat.completions.create({
        model: this.settings.model || 'gpt-4',
        messages: [{ role: 'user', content: prompt }]
      });
      return response.choices[0].message.content;
    } catch (error) {
      throw new AIServiceException('OpenAI 聊天失败', error);
    }
  }

  // ... 实现其他接口方法
} 