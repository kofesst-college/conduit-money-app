import 'dart:io';

import 'package:conduit/conduit.dart';
import 'package:conduit_project/controllers/app_asset_controller.dart';
import 'package:conduit_project/controllers/app_auth_controllers.dart';
import 'package:conduit_project/controllers/app_category_controller.dart';
import 'package:conduit_project/controllers/app_token_controller.dart';
import 'package:conduit_project/controllers/app_transaction_controller.dart';
import 'package:conduit_project/controllers/app_user_controller.dart';

class AppService extends ApplicationChannel {
  late final ManagedContext managedContext;

  @override
  Future prepare() {
    final persistentStore = _initDatabase();
    managedContext = ManagedContext(
      ManagedDataModel.fromCurrentMirrorSystem(),
      persistentStore,
    );
    return super.prepare();
  }

  @override
  Controller get entryPoint => Router()
    ..route('auth/[:refresh]').link(
      () => AppAuthController(managedContext),
    )
    ..route('user')
        .link(AppTokenController.new)!
        .link(() => AppUserController(managedContext))
    ..route('assets[/:id]')
        .link(AppTokenController.new)!
        .link(() => AppAssetController(managedContext))
    ..route('categories[/:id[/:show]]')
        .link(AppTokenController.new)!
        .link(() => AppCategoryController(managedContext))
    ..route('transactions[/:id]')
        .link(AppTokenController.new)!
        .link(() => AppTransactionController(managedContext));

  PersistentStore _initDatabase() {
    final username = Platform.environment["DB_USERNAME"] ?? 'postgres';
    final password = Platform.environment["DB_PASSWORD"] ?? 'Parol123';
    final host = Platform.environment["DB_HOST"] ?? '127.0.0.1';
    final port = int.parse(Platform.environment["DB_PORT"] ?? '5432');
    final database = Platform.environment["DB_DATABASE"] ?? 'conduit_money_app';
    return PostgreSQLPersistentStore.fromConnectionInfo(
      username,
      password,
      host,
      port,
      database,
    );
  }
}
