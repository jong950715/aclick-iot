import 'package:phone/models/event_record.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:path_provider/path_provider.dart';

class ReportRepository {
  ReportRepository._();
  static final instance = ReportRepository._();
  Future<Database> openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = '${dir.path}/app.db';
    return await databaseFactoryIo.openDatabase(dbPath);
  }

  final store = intMapStoreFactory.store('reports');

  Future<void> saveEventRecord(EventRecord eventRecord) async {
    final db = await openDb();
    await store.record(eventRecord.datetime.millisecondsSinceEpoch).put(db, eventRecord.toJson());
  }

  Future<List<EventRecord>> loadAllEventRecords() async {
    final db = await openDb();
    final records = await store.find(db);
    return records.map((r) => EventRecord.fromJson(r.value)).toList();
  }
}