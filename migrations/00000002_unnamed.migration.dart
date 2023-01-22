import 'dart:async';
import 'package:conduit_core/conduit_core.dart';   

class Migration2 extends Migration { 
  @override
  Future upgrade() async {
   		database.addColumn("_Asset", SchemaColumn.relationship("owner", ManagedPropertyType.bigInteger, relatedTableName: "_User", relatedColumnName: "id", rule: DeleteRule.cascade, isNullable: false, isUnique: false));
		database.deleteColumn("_Asset", "type");
		database.deleteColumn("_Asset", "user");
		database.deleteColumn("_Transaction", "target");
  }
  
  @override
  Future downgrade() async {}
  
  @override
  Future seed() async {}
}
    