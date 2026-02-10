import 'package:flutter/material.dart';

class AppConstants {
  static const String supabaseUrl = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_URL', defaultValue: 'https://nqrrayelxvmzfnfuezll.supabase.co');
  static const String supabaseKey = String.fromEnvironment('NEXT_PUBLIC_SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5xcnJheWVseHZtemZuZnVlemxsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNzM1MjMsImV4cCI6MjA4MDg0OTUyM30.eJeM72E30iDbWFTxZH54X505XB-DoBf7mjJ-MdpkMx4');
  
  static const String billifyUrl = String.fromEnvironment('BILLIFY_URL', defaultValue: 'https://www.ezbillify.com');
  static const String billifyKey = String.fromEnvironment('BILLIFY_KEY', defaultValue: '');
  
  static const String billifySyncUrl = 'https://www.ezbillify.com/api/integrations/ez-launch/';
  static const String billifySyncToken = String.fromEnvironment('EZCONNECT_INTERNAL_TOKEN', defaultValue: 'Nw/5amLc0ZWScPMXktYsbtoCocOkDLgIJC+S5ZsiivlSh+0V0PbLooHxzIzT1EeF');
  
  // App Branding
  static const String appName = 'EZBillify V2';
  static const String appTagline = 'Smart Billing Solution';
  
  // Design Tokens
  static const double borderRadius = 16.0;
  static const double padding = 20.0;
  
  // Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color secondaryBlue = Color(0xFF3B82F6);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color slate50 = Color(0xFFF1F5F9);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate900 = Color(0xFF0F172A);
}
