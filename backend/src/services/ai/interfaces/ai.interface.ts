interface AIInterface {
  chat(prompt: string): Promise<string>;
  complete(prompt: string): Promise<string>;
  analyze(text: string): Promise<string[]>;
  analyzeAddress(address: string): Promise<AddressAnalysis>;
  normalizeAddress(address: string): Promise<string>;
  validateConnection(): Promise<boolean>;
  getUsage(): Promise<Record<string, any>>;
} 