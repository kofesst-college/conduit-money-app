import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/transaction.dart';
import 'package:conduit_project/models/user.dart';

// Категория
class Category extends ManagedObject<_Category> implements _Category {}

class _Category {
  @primaryKey
  int? id;

  @Column(unique: true, indexed: true)
  String? name;

  @Column(indexed: true, defaultValue: "false")
  bool? deleted;

  @Relate(#categories, isRequired: true, onDelete: DeleteRule.cascade)
  User? owner;

  ManagedSet<Transaction>? transactions;
}
