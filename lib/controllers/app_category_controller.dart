import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/category.dart';
import 'package:conduit_project/models/response.dart';
import 'package:conduit_project/models/user.dart';
import 'package:conduit_project/utils/app_response.dart';
import 'package:conduit_project/utils/app_utils.dart';

class AppCategoryController extends ResourceController {
  AppCategoryController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> get(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query("id") int? id,
    @Bind.query("q") String? query,
    @Bind.query("page") int page = 1,
    @Bind.query("limit") int limit = 10,
    @Bind.query("filter") String filter = "none",
  }) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      if (id != null) {
        final qFind = Query<Category>(managedContext)
          ..where((x) => x.id).equalTo(id)
          ..join(object: (x) => x.owner);
        final found = await qFind.fetchOne();
        if (found == null) {
          return AppResponse.badRequest(
            message: 'Категория не найдена',
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
      final qAll = Query<Category>(managedContext)
        ..where((x) => x.owner?.id).equalTo(idUser)
        ..where((x) => x.name).contains(query ?? "", caseSensitive: false)
        ..sortBy((x) => x.id, QuerySortOrder.ascending)
        ..offset = (page - 1) * limit
        ..fetchLimit = limit;
      switch (filter) {
        case "all":
          qAll.where((x) => x.deleted).oneOf([true, false]);
          break;
        case "hidden":
          qAll.where((x) => x.deleted).equalTo(true);
          break;
        default:
          qAll.where((x) => x.deleted).equalTo(false);
          break;
      }
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
    @Bind.body() Category model,
  ) async {
    if (model.name == null) {
      return AppResponse.badRequest(
        message: 'Необходимо указать название категории',
      );
    }
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      final user = await managedContext.fetchObjectWithID<User>(idUser);
      final qCreate = Query<Category>(managedContext)
        ..values.name = model.name
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
    @Bind.body() Map<String, dynamic> changes,
    @Bind.path("id") int id,
  ) async {
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qUpdate = Query<Category>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.owner?.id).equalTo(userId);
      if (changes.containsKey('name')) {
        qUpdate.values.name = changes['name'];
      }
      final updated = await qUpdate.updateOne();
      if (updated == null) {
        return Response.badRequest(
          body: ModelResponse(
            message: 'Категория не найдена',
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

  @Operation.put('id', 'show')
  Future<Response> show(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.path("id") int id,
  ) async {
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qUpdate = Query<Category>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.owner?.id).equalTo(userId)
        ..values.deleted = false;
      final enabled = await qUpdate.updateOne();
      return Response.ok(enabled);
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
      final qFind = Query<Category>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.owner?.id).equalTo(userId)
        ..join(set: (x) => x.transactions);
      final model = await qFind.fetchOne();
      if (model == null) {
        return Response.badRequest(
          body: {"message": "Категория не найдена"},
        );
      }
      if (model.transactions?.isEmpty == true) {
        final qDelete = Query<Category>(managedContext)
          ..where((x) => x.id).equalTo(id);
        await qDelete.delete();
        return Response.ok(true);
      }

      final qUpdate = Query<Category>(managedContext)
        ..where((x) => x.id).equalTo(id)
        ..values.deleted = true;
      final updated = await qUpdate.updateOne();
      return Response.ok(updated);
    } catch (exception) {
      return AppResponse.ok(
        body: exception,
        message: exception.toString(),
      );
    }
  }
}
