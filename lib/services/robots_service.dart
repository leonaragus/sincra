import 'package:supabase_flutter/supabase_flutter.dart';

class RobotsService {
  static final _client = Supabase.instance.client;

  static Future<DateTime?> lastRun(String jobName) async {
    final res = await _client
        .from('robot_runs')
        .select('started_at')
        .eq('job_name', jobName)
        .order('started_at', ascending: false)
        .limit(1);
    if (res.isNotEmpty) {
      final v = res.first['started_at']?.toString();
      if (v != null && v.isNotEmpty) return DateTime.tryParse(v);
    }
    return null;
  }

  static Future<void> triggerFunction(String functionName) async {
    await _client.functions.invoke(functionName, body: const {});
  }

  static Future<DateTime?> lastRunAny(List<String> jobNames) async {
    for (final name in jobNames) {
      final dt = await lastRun(name);
      if (dt != null) return dt;
    }
    return null;
  }

  static Future<void> triggerAny(List<String> functionNames) async {
    for (final fn in functionNames) {
      try {
        await triggerFunction(fn);
        return;
      } catch (_) {
        // Intenta el siguiente alias
      }
    }
    throw Exception('No se pudo invocar ninguna función: ${functionNames.join(", ")}');
  }
}
