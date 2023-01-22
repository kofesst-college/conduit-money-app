import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/asset.dart';
import 'package:conduit_project/models/response.dart';
import 'package:conduit_project/models/transaction.dart';
import 'package:conduit_project/utils/app_response.dart';
import 'package:conduit_project/utils/app_utils.dart';

class AppTransactionController extends ResourceController {
  AppTransactionController(this.managedContext);

  final ManagedContext managedContext;

  @Operation.get()
  Future<Response> get(
    @Bind.header(HttpHeaders.authorizationHeader) String header, {
    @Bind.query("id") int? id,
    @Bind.query("q") String? query,
    @Bind.query("page") int page = 1,
    @Bind.query("limit") int limit = 10,
    @Bind.query("category") int? categoryId,
    @Bind.query("asset") int? assetId,
  }) async {
    try {
      final idUser = AppUtils.getIdFromHeader(header);
      if (id != null) {
        final qFind = Query<Transaction>(managedContext)
          ..where((x) => x.id).equalTo(id)
          ..join(object: (x) => x.category)
          ..join(object: (x) => x.asset).join(object: (x) => x.owner)
          ..where((x) => x.asset?.owner?.id).equalTo(idUser);
        final found = await qFind.fetchOne();
        if (found == null) {
          return AppResponse.badRequest(
            message: 'Транзакция не найдена',
          );
        }
        return Response.ok(
          found,
        );
      }
      final qAll = Query<Transaction>(managedContext)
        ..join(object: (x) => x.category)
        ..join(object: (x) => x.asset)
        ..where((x) => x.asset?.owner?.id).equalTo(idUser)
        ..where((x) => x.title).contains(query ?? "", caseSensitive: false)
        ..sortBy((x) => x.id, QuerySortOrder.ascending)
        ..offset = (page - 1) * limit
        ..fetchLimit = limit;
      if (categoryId != null) {
        qAll.where((x) => x.category?.id).equalTo(categoryId);
      }
      if (assetId != null) {
        qAll.where((x) => x.asset?.id).equalTo(assetId);
      }
      final found = await qAll.fetch();
      return Response.ok(
        found,
      );
    } catch (exception) {
      return AppResponse.ok(
        message: exception.toString(),
      );
    }
  }

  @Operation.post()
  Future<Response> create(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Transaction model,
  ) async {
    if (model.title == null ||
        model.amount == null ||
        model.category?.id == null ||
        model.asset?.id == null) {
      return AppResponse.badRequest(
        message:
            'Необходимо указать описание, сумму, категорию и счет транзакции',
      );
    }
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qGetAsset = Query<Asset>(managedContext)
        ..where((x) => x.id).equalTo(model.asset!.id)
        ..where((x) => x.owner?.id).equalTo(userId);
      final asset = await qGetAsset.fetchOne();
      if (asset == null) {
        return AppResponse.badRequest(
          message: "Счет не найден",
        );
      }
      if (model.amount! > asset.balance!) {
        return AppResponse.badRequest(
          message: "Недостаточно средств",
        );
      }
      final qCreate = Query<Transaction>(managedContext)
        ..values.title = model.title
        ..values.amount = model.amount
        ..values.category?.id = model.category!.id
        ..values.asset?.id = model.asset!.id
        ..values.date = DateTime.now();
      final created = await qCreate.insert();
      final qUpdateAsset = Query<Asset>(managedContext)
        ..values.balance = asset.balance! - model.amount!
        ..where((x) => x.id).equalTo(model.asset!.id);
      await qUpdateAsset.updateOne();
      final transaction = await (Query<Transaction>(managedContext)
            ..where((x) => x.id).equalTo(created.id)
            ..join(object: (x) => x.category)
            ..join(object: (x) => x.asset))
          .fetchOne();
      return Response.ok(
        transaction,
      );
    } catch (exception) {
      return AppResponse.ok(
        message: exception.toString(),
      );
    }
  }

  @Operation.put('id')
  Future<Response> update(
    @Bind.header(HttpHeaders.authorizationHeader) String header,
    @Bind.body() Transaction model,
    @Bind.path("id") int id,
  ) async {
    try {
      final userId = AppUtils.getIdFromHeader(header);
      final qGet = Query<Transaction>(managedContext)
        ..join(object: (x) => x.category)
        ..join(object: (x) => x.asset).join(object: (x) => x.owner)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.asset?.owner?.id).equalTo(userId);
      var transaction = await qGet.fetchOne();
      if (transaction == null || transaction.asset?.owner?.id != userId) {
        return Response.badRequest(
          body: ModelResponse(
            message: 'Транзакция не найдена',
          ),
        );
      }
      final qGetAsset = Query<Asset>(managedContext)
        ..where((x) => x.id).equalTo(transaction.asset?.id)
        ..where((x) => x.owner?.id).equalTo(userId);
      final asset = await qGetAsset.fetchOne();
      if (asset == null) {
        return AppResponse.badRequest(
          message: "Счет не найден",
        );
      }
      final qUpdate = Query<Transaction>(managedContext)
        ..where((x) => x.id).equalTo(id);
      if (model.title != null) {
        qUpdate.values.title = model.title;
      }
      final qUpdateAsset = Query<Asset>(managedContext)
        ..where((x) => x.id).equalTo(transaction.asset?.id);
      if (model.amount != null) {
        if (model.amount! > asset.balance! + transaction.amount!) {
          return AppResponse.badRequest(
            message: "Недостаточно средств",
          );
        }
        qUpdate.values.amount = model.amount;
        qUpdateAsset.values.balance =
            asset.balance! + transaction.amount! - model.amount!;
      }
      await qUpdateAsset.updateOne();
      final updated = await qUpdate.updateOne();
      if (updated == null) {
        return Response.badRequest(
          body: ModelResponse(
            message: 'Транзакция не найдена',
          ),
        );
      }
      transaction = await qGet.fetchOne();
      transaction!.asset!.owner!.removePropertiesFromBackingMap(
        ['accessToken', 'refreshToken'],
      );
      return Response.ok(
        transaction,
      );
    } catch (exception) {
      return AppResponse.ok(
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
      final qGet = Query<Transaction>(managedContext)
        ..join(object: (x) => x.category)
        ..join(object: (x) => x.asset).join(object: (x) => x.owner)
        ..where((x) => x.id).equalTo(id)
        ..where((x) => x.asset?.owner?.id).equalTo(userId);
      final transaction = await qGet.fetchOne();
      if (transaction == null || transaction.asset?.owner?.id != userId) {
        return Response.badRequest(
          body: ModelResponse(
            message: 'Транзакция не найдена',
          ),
        );
      }
      final qUpdateAsset = Query<Asset>(managedContext)
        ..where((x) => x.id).equalTo(transaction.asset?.id)
        ..values.balance = transaction.asset!.balance! + transaction.amount!;
      await qUpdateAsset.updateOne();
      final qDelete = Query<Transaction>(managedContext)
        ..where((x) => x.id).equalTo(id);
      await qDelete.delete();
      return Response.ok(true);
    } catch (exception) {
      return AppResponse.ok(
        message: exception.toString(),
      );
    }
  }
}
