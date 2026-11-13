import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'failures.dart';

/// Server-side RPC error tokens (raised by PostgreSQL functions) mapped to
/// safe, user-facing Bengali messages. Raw SQL errors are never shown.
const Map<String, String> _rpcMessages = <String, String>{
  'NOT_AUTHENTICATED': 'আগে লগইন করুন।',
  'NOT_FRIENDS': 'আপনি এবং এই ইউজার এখনো বন্ধু নন।',
  'INVITE_NOT_FOUND': 'এই ইনভাইট কোডটি পাওয়া যায়নি।',
  'CANNOT_FRIEND_SELF': 'নিজেকে বন্ধু হিসেবে যোগ করা যাবে না।',
  'ALREADY_FRIENDS': 'আপনারা ইতিমধ্যে বন্ধু।',
  'ALREADY_REQUESTED': 'আগেই একটি অনুরোধ পাঠানো হয়েছে।',
  'BLOCKED_RELATIONSHIP': 'ব্লক করা ইউজারের সাথে এটি করা যাবে না।',
  'REQUEST_NOT_FOUND': 'অনুরোধটি পাওয়া যায়নি বা আর সক্রিয় নেই।',
  'MATCH_NOT_FOUND': 'ম্যাচটি পাওয়া যায়নি।',
  'NOT_PARTICIPANT': 'এই ম্যাচে আপনার অংশগ্রহণ নেই।',
  'MATCH_NOT_JOINABLE': 'এই ম্যাচে এখন যোগ দেওয়া যাবে না।',
  'MATCH_NOT_ACTIVE': 'ম্যাচটি এখন ভোটের জন্য খোলা নেই।',
  'ALREADY_VOTED': 'আপনি ইতিমধ্যে ভোট দিয়েছেন।',
  'INVALID_CHOICE': 'ভোটটি বৈধ নয়।',
  'VOTING_CLOSED': 'ভোট দেওয়ার সময় শেষ হয়ে গেছে।',
  'RATE_LIMITED': 'অনেক দ্রুত অনুরোধ করছেন। একটু পরে চেষ্টা করুন।',
  'INSUFFICIENT_COINS': 'পর্যাপ্ত কয়েন নেই।',
  'PUNISHMENT_NOT_FOUND': 'এই শাস্তির তথ্য পাওয়া যায়নি।',
  'INVALID_STATE': 'এই কাজটি এখন করা যাবে না।',
  'PROFILE_NOT_FOUND': 'প্রোফাইল পাওয়া যায়নি।',
  'ROUND_NOT_FOUND': 'রাউন্ডটি পাওয়া যায়নি।',
  'CASE_NOT_FOUND': 'মামলাটি পাওয়া যায়নি।',
  'CONTRACT_NOT_FOUND': 'চুক্তিটি পাওয়া যায়নি।',
  'CONTRACT_EXISTS': 'এই বন্ধুর সাথে ইতিমধ্যে একটি চুক্তি আছে।',
  'CONFESSION_NOT_FOUND': 'কনফেশনটি পাওয়া যায়নি।',
  'TITLE_NOT_EARNED': 'এই টাইটেলটি এখনো আনলক হয়নি।',
  'RECIPIENT_MUTED': 'বন্ধু এই ধরনের পিং বন্ধ রেখেছে।',
  'INVITE_CODE_GENERATION_FAILED': 'ইনভাইট কোড তৈরি করা যাচ্ছে না।',
};

AppFailure mapErrorToFailure(Object error) {
  if (error is AppFailure) {
    return error;
  }
  if (error is AuthException) {
    return AuthFailure(message: _authMessage(error));
  }
  if (error is PostgrestException) {
    return _postgrestFailure(error);
  }
  if (error is SocketException || error is TimeoutException) {
    return const NetworkFailure();
  }
  return const ServerFailure();
}

AppFailure _postgrestFailure(PostgrestException error) {
  final String message = error.message.trim();
  final String token = message.toLowerCase();
  if (token.contains('jwt') || token.contains('invalid claim')) {
    return const AuthFailure(message: 'সেশন মেয়াদোত্তীর্ণ। আবার লগইন করুন।');
  }
  if (token.contains('duplicate key')) {
    return const ValidationFailure(
      message: 'এই তথ্য আগেই ব্যবহার করা হয়েছে।',
    );
  }
  if (token.contains('permission denied') || error.code == '42501') {
    return const UnauthorizedFailure();
  }
  final String? mapped = _rpcMessages[message.toUpperCase()];
  if (mapped != null) {
    if (message.toUpperCase() == 'RATE_LIMITED') {
      return RateLimitFailure(message: mapped);
    }
    if (message.toUpperCase() == 'INSUFFICIENT_COINS') {
      return ValidationFailure(message: mapped, code: 'INSUFFICIENT_COINS');
    }
    return ValidationFailure(message: mapped, code: message.toUpperCase());
  }
  return const ServerFailure();
}

String _authMessage(AuthException error) {
  final String lower = error.message.toLowerCase();
  if (lower.contains('invalid login credentials')) {
    return 'ইমেইল বা পাসওয়ার্ড সঠিক নয়।';
  }
  if (lower.contains('already registered')) {
    return 'এই ইমেইল দিয়ে আগেই অ্যাকাউন্ট আছে।';
  }
  if (lower.contains('email not confirmed')) {
    return 'ইমেইল ভেরিফাই করা হয়নি। ইনবক্স দেখুন।';
  }
  if (lower.contains('password should be at least')) {
    return 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের হতে হবে।';
  }
  if (lower.contains('rate limit') || lower.contains('too many')) {
    return 'অনেকবার চেষ্টা হয়েছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।';
  }
  return 'লগইন সংক্রান্ত সমস্যা হয়েছে। আবার চেষ্টা করুন।';
}
