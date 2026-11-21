class ApiConstants {
  // Hardcoded Supabase Credentials provided by user
  static const String defaultSupabaseUrl = 'https://lhvhjslwvoengoyjngcd.supabase.co';
  static const String defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxodmhqc2x3dm9lbmdveWpuZ2NkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTUyMjg3MDQsImV4cCI6MjExMDgwNDcwNH0.jpQrX0PxaDOk7C5B8UTz3dw5iG9xGG-cFGcXHOP8ntQ';

  /// Normalizes URL to root project domain (stripping /rest/v1/ or trailing slash)
  static String normalizeSupabaseUrl(String rawUrl) {
    var url = rawUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/rest/v1')) {
      url = url.substring(0, url.length - '/rest/v1'.length);
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url.isEmpty ? defaultSupabaseUrl : url;
  }
}
