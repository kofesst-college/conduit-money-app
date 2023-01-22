import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/response.dart';
import 'package:conduit_project/models/user.dart';
import 'package:conduit_project/utils/app_utils.dart';
import 'package:jaguar_jwt/jaguar_jwt.dart';

class AppAuthController extends ResourceController {
  AppAuthController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.post('refresh')
  Future<Response> refreshToken(
      @Bind.path('refresh') String refreshToken,) async {
    try {
      final id = AppUtils.getIdFromToken(refreshToken);
      final user = await managedContext.fetchObjectWithID<User>(id);

      if (user!.refreshToken != refreshToken) {
        return Response.unauthorized(body: 'Некорректный токен');
      }

      _updateTokens(id, managedContext);
      return Response.ok(
        ModelResponse(
          data: user.backing.contents,
          message: 'Токен успешно обновлен',
        ),
      );
    } on QueryException catch (exception) {
      return Response.serverError(
        body: ModelResponse(
          message: exception.message,
        ),
      );
    }
  }

  @Operation.get()
  Future<Response> signIn(@Bind.body() User user,) async {
    if (user.password == null || user.userName == null) {
      return Response.badRequest(
        body: ModelResponse(
          message: 'Необходимо указать никнейм и пароль',
        ),
      );
    }
    try {
      final qFindUser = Query<User>(managedContext)
        ..where((el) => el.userName).equalTo(user.userName)
        ..returningProperties(
              (el) =>
          [
            el.id,
            el.salt,
            el.hashPassword,
          ],
        );
      final fUser = await qFindUser.fetchOne();
      if (fUser == null) {
        throw QueryException.input(
          'Пользователь не найден',
          [],
        );
      }
      final requestHashPassword = generatePasswordHash(
        user.password ?? '',
        fUser.salt ?? '',
      );
      if (requestHashPassword == fUser.hashPassword) {
        _updateTokens(fUser.id ?? -1, managedContext);
        final newUser = await managedContext.fetchObjectWithID<User>(fUser.id);
        return Response.ok(
          ModelResponse(
            data: newUser!.backing.contents,
            message: 'Успешная авторизация',
          ),
        );
      } else {
        throw QueryException.input(
          'Неверный пароль',
          [],
        );
      }
    } on QueryException catch (e) {
      return Response.serverError(
        body: ModelResponse(message: e.message),
      );
    }
  }

  @Operation.post()
  Future<Response> signUp(@Bind.body() User user) async {
    if (user.password == null || user.userName == null || user.email == null) {
      return Response.badRequest(
        body: ModelResponse(
          message: 'Необходимо указать никнейм, email и пароль',
        ),
      );
    }
    final salt = generateRandomSalt();
    final hashPassword = generatePasswordHash(user.password!, salt);
    try {
      final qCreateUser = Query<User>(managedContext)
        ..values.userName = user.userName
        ..values.email = user.email
        ..values.salt = salt
        ..values.hashPassword = hashPassword;
      final createdUser = await qCreateUser.insert();
      createdUser.removePropertiesFromBackingMap([
        'refreshToken',
        'accessToken',
      ]);
      _updateTokens(createdUser.id!, managedContext);
      return Response.ok(
        ModelResponse(
          data: createdUser.backing.contents,
          message: 'Успешная регистрация',
        ),
      );
    } on QueryException catch (e) {
      return Response.serverError(
        body: ModelResponse(message: e.message),
      );
    }
  }

  void _updateTokens(int id, ManagedContext managedContext) async {
    final Map<String, String> tokens = _getTokens(id);
    final qUpdateTokens = Query<User>(managedContext)
      ..where((el) => el.id).equalTo(id)
      ..values.accessToken = tokens['access']
      ..values.refreshToken = tokens['refresh'];
    await qUpdateTokens.updateOne();
  }

  Map<String, String> _getTokens(int id) {
    final key = Platform.environment['SECRET_KEY'] ?? 'SECRET_KEY';
    final accessClaimSet = JwtClaim(
      maxAge: Duration(hours: 1),
      otherClaims: {'id': id},
    );
    final refreshClaimSet = JwtClaim(
      otherClaims: {'id': id},
    );
    return <String, String>{
      'access': issueJwtHS256(accessClaimSet, key),
      'refresh': issueJwtHS256(refreshClaimSet, key),
    };
  }
}