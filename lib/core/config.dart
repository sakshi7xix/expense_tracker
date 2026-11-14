/// Where the app's online data lives.
///
/// The publishable key is meant to ship inside the app: it only allows what the
/// database's row level security allows. The secret key must never be here.
abstract final class SupabaseConfig {
  static const url = 'https://asohtlwsgfuoqpjzhaho.supabase.co';
  static const publishableKey = 'sb_publishable_AnCcdnOO9y4GlVZkLGKHgQ_txP9x4GP';
}

/// Where people write with questions and complaints (DPDP grievance contact).
/// Replace with the real support address before publishing.
const supportEmail = 'support@example.com';
