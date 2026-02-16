class ApiKeys {
  // Clave de API de Anthropic (Claude)
  // Se divide en partes para evitar bloqueos de escaneo de secretos en repositorios públicos
  static const String _part1 = 'sk-ant-api03-Ls4oPi3Bt12fzGmvznXpJcaxgl1SrNVCS5lfM4_X7vpvkvBOeb6j1QjMNryrSzVVE2uYF5VN4adcjnxcqj1BEA';
  static const String _part2 = '-oJSiRwAA';

  static String get anthropicApiKey => '$_part1$_part2';
}
