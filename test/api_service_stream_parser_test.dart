import 'package:flutter_test/flutter_test.dart';

import 'package:ai_anywhere/services/api_service.dart';
import 'package:ai_anywhere/services/log_service.dart';
import 'package:ai_anywhere/services/storage_service.dart';

void main() {
  late ApiService api;

  setUp(() async {
    final storage = StorageService();
    await storage.initialize();
    final log = LogService(storage);
    await log.initialize();
    api = ApiService(log);
  });

  test('parses fragmented/invalid OpenAI SSE lines safely', () {
    expect(api.parseOpenAiChunkForTest('data: {"choices":[{"delta":{"content":"Hi"}}]}'), 'Hi');
    expect(api.parseOpenAiChunkForTest('data: [DONE]'), isNull);
    expect(api.parseOpenAiChunkForTest('data: {"choices":['), isNull);
    expect(api.parseOpenAiChunkForTest('event: ping'), isNull);
  });

  test('parses malformed Ollama lines safely', () {
    expect(api.parseOllamaChunkForTest('{"message":{"content":"Hello"}}'), 'Hello');
    expect(api.parseOllamaChunkForTest('{"message":{"content":123}}'), isNull);
    expect(api.parseOllamaChunkForTest('{bad json'), isNull);
    expect(api.parseOllamaChunkForTest(''), isNull);
  });
}
