// Supabase Configuration
// This file contains Supabase configuration loaded from .env file

import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Get Supabase URL from .env file
  static String get supabaseUrl =>
      dotenv.get('SUPABASE_URL', fallback: 'Missing Supabase URL');

  // Get Supabase anonymous key from .env file
  static String get supabaseAnonKey =>
      dotenv.get('SUPABASE_ANON_KEY', fallback: 'Missing Supabase Anon Key');
}
