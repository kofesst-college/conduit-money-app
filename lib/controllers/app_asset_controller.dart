import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/asset.dart';
import 'package:conduit_project/models/response.dart';
import 'package:conduit_project/models/user.dart';
import 'package:conduit_project/utils/app_response.dart';
import 'package:conduit_project/utils/app_utils.dart';

class AppAssetController extends ResourceController {
  AppAssetController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> get(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query("id") int? id,
    @Bind.query("q") String? query,
    @Bind.query("page") int page = 1,
    @Bind.query("limit") int limit = 10,
  }) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      if (id != null) {
        final qFind = Query<Asset>(managedContext)
          ..where((x) => x.id).equalTo(id)
          ..join(object: (x) => x.owner);
        final found = await qFind.fetchOne();
        if (found == null) {
          return AppResponse.badRequest(
            message: 'Счет не найден',
          );
        }
        found.owner!.removePropertiesFromBackingMap(
          [
            'refreshToken',
            'accessToken',
          ],
        );
        return Response.ok(
          found,
        );
      }
      final qAll = Query<Asset>(managedContext)
        ..where((x) => x.owner?.id).equalTo(idUser)
        ..where((x) => x.name).contains(query ?? "", caseSensitive: false)
        ..sortBy((x) => x.id, QuerySortOrder.ascending)
        ..offset = (page - 1) * limit
        ..fetchLimit = limit;
      final found = await qAll.fetch();
      return Response.ok(
        found,
      );
    } catch (exception) {
      return AppResponse.ok(
        body: exception,
        message: exception.toString(),
      );
    }
  }

  @Operation.post()
  Future<Response> create(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Asset model,
  ) async {
    if (model.name == null || model.balance == null) {
      return AppResponse.badRequest(
        message: 'Необходимо указать название и баланс счета',
      );
    }
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(idUser);
      final qCreate = Query<Asset>(managedContext)
        ..values.name = model.name
        ..values.balance = model.balance
        ..values.owner = user;
      final created = await qCreate.insert();
      created.owner!.removePropertiesFromBackingMap(
        [
          'refreshToken',
          'accessToken',
        ],
      );
      return Response.ok(
        created,
      );
    } catch (exception) {
      return AppResponse.ok(
        body: exception,
        message: exception.toString(),
      );
    }
  }

  @Operation.put('id')
  Future<Response> update(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Asset changes,
    @Bind.path("id") int id,
  ) async {
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qUpdate = Query<Asset>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.owner?.id).equalTo(userId);
      if (changes.name != null) {
        qUpdate.values.name = changes.name;
      }
      if (changes.balance != null) {
        qUpdate.values.balance = changes.balance;
      }
      final updated = await qUpdate.updateOne();
      if (updated == null) {
        return Response.badRequest(
          body: ModelResponse(
            message: 'Счет не найден',
          ),
        );
      }
      updated.owner!.removePropertiesFromBackingMap(
        [
          'refreshToken',
          'accessToken',
        ],
      );
      return Response.ok(
        updated,
      );
    } catch (exception) {
      return AppResponse.ok(
        body: exception,
        message: exception.toString(),
      );
    }
  }

  @Operation.delete('id')
  Future<Response> delete(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.path("id") int id,
  ) async {
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qDelete = Query<Asset>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.owner?.id).equalTo(userId);
      await qDelete.delete();
      return Response.ok('');
    } catch (exception) {
      return AppResponse.ok(
        body: exception,
        message: exception.toString(),
      );
    }
  }
}
