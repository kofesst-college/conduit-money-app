import 'package:conduit/conduit.dart';
import 'package:conduit_project/models/transaction.dart';
import 'package:conduit_project/models/user.dart';

// Счёт
class Asset extends ManagedObject<_Asset> implements _Asset {}

class _Asset {
  @primaryKey
  int? id;

  @Column(indexed: true)
  String? name;

  @Column(indexed: true, defaultValue: '0.0')
  double? balance;

  @Relate(#assets, isRequired: true, onDelete: DeleteRule.cascade)
  User? owner;

  ManagedSet<Transaction>? transactions;
}
