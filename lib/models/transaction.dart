import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/asset.dart';
import 'package:conduit_project/models/category.dart';

// Транзакция
class Transaction extends ManagedObject<_Transaction> implements _Transaction {}

class _Transaction {
  @primaryKey
  int? id;

  @Column(indexed: true)
  DateTime? date;

  @Column(indexed: true)
  String? title;

  @Column(indexed: true)
  double? amount;

  @Relate(#transactions, isRequired: true, onDelete: DeleteRule.cascade)
  Category? category;

  @Relate(#transactions, isRequired: true, onDelete: DeleteRule.cascade)
  Asset? asset;
}
