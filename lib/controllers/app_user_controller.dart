import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/user.dart';
import 'package:conduit_project/utils/app_utils.dart';

import '../utils/app_response.dart';

class AppUserController extends ResourceController {
  AppUserController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> getProfile(
      @Bind.header(HttpHeaders.authorizationHeader) String header) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(id);
      user!.removePropertiesFromBackingMap([
        'refreshToken',
        'accessToken',
      ]);
      return AppResponse.ok(
        message: 'Успешное получение профиля',
        body: user.backing.contents,
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка получения профиля');
    }
  }

  @Operation.post()
  Future<Response> updateProfile(
      @Bind.header(HttpHeaders.authorizationHeader) String header,
      @Bind.body() User user) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final fUser = await managedContext.fetchObjectWithID<User>(id);
      final qUpdateUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id)
        ..values.userName = user.userName ?? fUser!.userName
        ..values.email = user.email ?? fUser!.email;
      await qUpdateUser.updateOne();
      final newUser = await managedContext.fetchObjectWithID<User>(id);
      newUser!.removePropertiesFromBackingMap([
        'refreshToken',
        'accessToken',
      ]);
      return AppResponse.ok(
        message: 'Успешное обновление данных',
        body: newUser.backing.contents,
      );
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления данных');
    }
  }

  @Operation.put()
  Future<Response> updatePassword(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.query('newPassword') String newPassword,
    @Bind.query('oldPassword') String oldPassword,
  ) async {
    try {
      final id = AppUtils.getIdFromHeader(header);
      final qFindUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id)
        ..returningProperties(
          (property) => [
            property.salt,
            property.hashPassword,
          ],
        );
      final fUser = await qFindUser.fetchOne();
      final oldHashPassword = generatePasswordHash(
        oldPassword,
        fUser!.salt ?? '',
      );
      if (oldHashPassword != fUser.hashPassword) {
        return AppResponse.badRequest(
          message: 'Неверный старый пароль',
        );
      }
      final newHashPassword = generatePasswordHash(
        newPassword,
        fUser.salt ?? '',
      );
      final qUpdateUser = Query<User>(managedContext)
        ..where((user) => user.id).equalTo(id)
        ..values.hashPassword = newHashPassword;
      await qUpdateUser.fetchOne();
      return AppResponse.ok(body: 'Пароль успешно обновлен');
    } catch (e) {
      return AppResponse.serverError(e, message: 'Ошибка обновления пароля');
    }
  }
}
