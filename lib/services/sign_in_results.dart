import 'package:flutter_chess_app/models/user_model.dart';

abstract class SignInResult {}

class SignInSuccess extends SignInResult {
  final ChessUser user;
  SignInSuccess(this.user);
}

class SignInEmailNotVerified extends SignInResult {
  final String email;
  SignInEmailNotVerified(this.email);
}

class SignInError extends SignInResult {
  final String message;
  SignInError(this.message);
}
