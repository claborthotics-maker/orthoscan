import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/patient.dart';
import '../models/work_order.dart';
import '../models/work_order_template.dart';
import '../models/clinician.dart';
import '../models/clinic.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'orthoscan.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop old clinicians table and recreate with new schema
      await db.execute('DROP TABLE IF EXISTS clinicians');
      await db.execute('''
        CREATE TABLE clinicians (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          licenseNumber TEXT,
          isDefault INTEGER DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE clinics (
          id TEXT PRIMARY KEY,
          clinicianId TEXT NOT NULL,
          name TEXT NOT NULL,
          address TEXT,
          city TEXT,
          state TEXT,
          zip TEXT,
          phone TEXT,
          isDefault INTEGER DEFAULT 0,
          FOREIGN KEY (clinicianId) REFERENCES clinicians (id)
        )
      ''');
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        firstName TEXT NOT NULL,
        lastName TEXT NOT NULL,
        patientId TEXT,
        dateOfBirth TEXT,
        phone TEXT,
        email TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        scanFiles TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE work_orders (
        id TEXT PRIMARY KEY,
        patientId TEXT NOT NULL,
        name TEXT,
        templateType INTEGER,
        status INTEGER DEFAULT 0,
        footSide INTEGER DEFAULT 2,
        productType TEXT,
        materials TEXT,
        specialInstructions TEXT,
        clinicianName TEXT,
        clinicName TEXT,
        clinicianId TEXT,
        clinicId TEXT,
        quantityLeft INTEGER DEFAULT 1,
        quantityRight INTEGER DEFAULT 1,
        isPartialFootLeft INTEGER DEFAULT 0,
        isPartialFootRight INTEGER DEFAULT 0,
        toeFillerCountLeft INTEGER DEFAULT 1,
        toeFillerCountRight INTEGER DEFAULT 1,
        baseThickness TEXT,
        baseGrind TEXT,
        topCoverType TEXT,
        topCoverThickness TEXT,
        topCoverColor TEXT,
        patientWeight REAL,
        shellThickness TEXT,
        baseShellLength TEXT,
        midLayerType TEXT,
        midLayerThickness TEXT,
        archModification INTEGER DEFAULT 0,
        heelPost TEXT,
        forefootPost TEXT,
        heelWedge TEXT,
        forefootWedge TEXT,
        metPadFoot TEXT,
        metPadSize TEXT,
        metBarFoot TEXT,
        metBarSize TEXT,
        heelLiftFoot TEXT,
        heelLiftHeight TEXT,
        heelCup TEXT,
        createdAt TEXT NOT NULL,
        dateOfService TEXT,
        expectedDeliveryDate TEXT,
        submittedAt TEXT,
        completedAt TEXT,
        scanFiles TEXT,
        FOREIGN KEY (patientId) REFERENCES patients (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE clinicians (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        licenseNumber TEXT,
        isDefault INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE clinics (
        id TEXT PRIMARY KEY,
        clinicianId TEXT NOT NULL,
        name TEXT NOT NULL,
        address TEXT,
        city TEXT,
        state TEXT,
        zip TEXT,
        phone TEXT,
        isDefault INTEGER DEFAULT 0,
        FOREIGN KEY (clinicianId) REFERENCES clinicians (id)
      )
    ''');
  }

  // ─── Patient CRUD ──────────────────────────────────────────────────────────

  Future<void> insertPatient(Patient patient) async {
    final db = await database;
    await db.insert(
      'patients',
      {
        'id': patient.id,
        'firstName': patient.firstName,
        'lastName': patient.lastName,
        'patientId': patient.patientId,
        'dateOfBirth': patient.dateOfBirth,
        'phone': patient.phone,
        'email': patient.email,
        'notes': patient.notes,
        'createdAt': patient.createdAt.toIso8601String(),
        'scanFiles': patient.scanFiles.join(','),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updatePatient(Patient patient) async {
    final db = await database;
    await db.update(
      'patients',
      {
        'firstName': patient.firstName,
        'lastName': patient.lastName,
        'patientId': patient.patientId,
        'dateOfBirth': patient.dateOfBirth,
        'phone': patient.phone,
        'email': patient.email,
        'notes': patient.notes,
        'scanFiles': patient.scanFiles.join(','),
      },
      where: 'id = ?',
      whereArgs: [patient.id],
    );
  }

  Future<void> deletePatient(String id) async {
    final db = await database;
    await db.delete('patients', where: 'id = ?', whereArgs: [id]);
    await db.delete('work_orders', where: 'patientId = ?', whereArgs: [id]);
  }

  Future<List<Patient>> getAllPatients() async {
    final db = await database;
    final maps = await db.query('patients',
        orderBy: 'LOWER(firstName) ASC, LOWER(lastName) ASC');
    return maps.map((map) => Patient(
      id: map['id'] as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      patientId: map['patientId'] as String? ?? '',
      dateOfBirth: map['dateOfBirth'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      email: map['email'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      scanFiles: (map['scanFiles'] as String? ?? '').isEmpty
          ? []
          : (map['scanFiles'] as String).split(','),
    )).toList();
  }

  // ─── Work Order CRUD ───────────────────────────────────────────────────────

  Future<void> insertWorkOrder(WorkOrder wo) async {
    final db = await database;
    await db.insert(
      'work_orders',
      _workOrderToMap(wo),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateWorkOrder(WorkOrder wo) async {
    final db = await database;
    await db.update(
      'work_orders',
      _workOrderToMap(wo),
      where: 'id = ?',
      whereArgs: [wo.id],
    );
  }

  Future<void> deleteWorkOrder(String id) async {
    final db = await database;
    await db.delete('work_orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<WorkOrder>> getWorkOrdersForPatient(String patientId) async {
    final db = await database;
    final maps = await db.query(
      'work_orders',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => _workOrderFromMap(map)).toList();
  }

  Future<List<WorkOrder>> getAllWorkOrders() async {
    final db = await database;
    final maps = await db.query('work_orders', orderBy: 'createdAt DESC');
    return maps.map((map) => _workOrderFromMap(map)).toList();
  }

  Map<String, dynamic> _workOrderToMap(WorkOrder wo) {
    return {
      'id': wo.id,
      'patientId': wo.patientId,
      'name': wo.name,
      'templateType': wo.templateType?.index,
      'status': wo.status.index,
      'footSide': wo.footSide.index,
      'productType': wo.productType,
      'materials': wo.materials,
      'specialInstructions': wo.specialInstructions,
      'clinicianName': wo.clinicianName,
      'clinicName': wo.clinicName,
      'clinicianId': wo.clinicianId,
      'clinicId': wo.clinicId,
      'quantityLeft': wo.quantityLeft,
      'quantityRight': wo.quantityRight,
      'isPartialFootLeft': wo.isPartialFootLeft ? 1 : 0,
      'isPartialFootRight': wo.isPartialFootRight ? 1 : 0,
      'toeFillerCountLeft': wo.toeFillerCountLeft,
      'toeFillerCountRight': wo.toeFillerCountRight,
      'baseThickness': wo.baseThickness,
      'baseGrind': wo.baseGrind,
      'topCoverType': wo.topCoverType,
      'topCoverThickness': wo.topCoverThickness,
      'topCoverColor': wo.topCoverColor,
      'patientWeight': wo.patientWeight,
      'shellThickness': wo.shellThickness,
      'baseShellLength': wo.baseShellLength,
      'midLayerType': wo.midLayerType,
      'midLayerThickness': wo.midLayerThickness,
      'archModification': wo.archModification,
      'heelPost': wo.heelPost,
      'forefootPost': wo.forefootPost,
      'heelWedge': wo.heelWedge,
      'forefootWedge': wo.forefootWedge,
      'metPadFoot': wo.metPadFoot,
      'metPadSize': wo.metPadSize,
      'metBarFoot': wo.metBarFoot,
      'metBarSize': wo.metBarSize,
      'heelLiftFoot': wo.heelLiftFoot,
      'heelLiftHeight': wo.heelLiftHeight,
      'heelCup': wo.heelCup,
      'createdAt': wo.createdAt.toIso8601String(),
      'dateOfService': wo.dateOfService?.toIso8601String(),
      'expectedDeliveryDate': wo.expectedDeliveryDate?.toIso8601String(),
      'submittedAt': wo.submittedAt?.toIso8601String(),
      'completedAt': wo.completedAt?.toIso8601String(),
      'scanFiles': wo.scanFiles.join(','),
    };
  }

  WorkOrder _workOrderFromMap(Map<String, dynamic> map) {
    return WorkOrder(
      id: map['id'] as String,
      patientId: map['patientId'] as String,
      name: map['name'] as String? ?? '',
      templateType: map['templateType'] != null
          ? TemplateType.values[map['templateType'] as int]
          : null,
      status: WorkOrderStatus.values[map['status'] as int? ?? 0],
      footSide: FootSide.values[map['footSide'] as int? ?? 2],
      productType: map['productType'] as String? ?? '',
      materials: map['materials'] as String? ?? '',
      specialInstructions: map['specialInstructions'] as String? ?? '',
      clinicianName: map['clinicianName'] as String? ?? '',
      clinicName: map['clinicName'] as String? ?? '',
      clinicianId: map['clinicianId'] as String? ?? '',
      clinicId: map['clinicId'] as String? ?? '',
      quantityLeft: map['quantityLeft'] as int? ?? 1,
      quantityRight: map['quantityRight'] as int? ?? 1,
      isPartialFootLeft: (map['isPartialFootLeft'] as int? ?? 0) == 1,
      isPartialFootRight: (map['isPartialFootRight'] as int? ?? 0) == 1,
      toeFillerCountLeft: map['toeFillerCountLeft'] as int? ?? 1,
      toeFillerCountRight: map['toeFillerCountRight'] as int? ?? 1,
      baseThickness: map['baseThickness'] as String? ?? '3/16"',
      baseGrind: map['baseGrind'] as String? ?? 'None',
      topCoverType: map['topCoverType'] as String? ?? 'Microcel Puff',
      topCoverThickness: map['topCoverThickness'] as String? ?? 'None',
      topCoverColor: map['topCoverColor'] as String? ?? 'None',
      patientWeight: map['patientWeight'] as double?,
      shellThickness: map['shellThickness'] as String? ?? '1/8"',
      baseShellLength: map['baseShellLength'] as String? ?? 'None',
      midLayerType: map['midLayerType'] as String? ?? 'None',
      midLayerThickness: map['midLayerThickness'] as String? ?? 'None',
      archModification: map['archModification'] as int? ?? 0,
      heelPost: map['heelPost'] as String? ?? 'None',
      forefootPost: map['forefootPost'] as String? ?? 'None',
      heelWedge: map['heelWedge'] as String? ?? 'None',
      forefootWedge: map['forefootWedge'] as String? ?? 'None',
      metPadFoot: map['metPadFoot'] as String? ?? 'None',
      metPadSize: map['metPadSize'] as String? ?? 'None',
      metBarFoot: map['metBarFoot'] as String? ?? 'None',
      metBarSize: map['metBarSize'] as String? ?? 'None',
      heelLiftFoot: map['heelLiftFoot'] as String? ?? 'None',
      heelLiftHeight: map['heelLiftHeight'] as String? ?? '',
      heelCup: map['heelCup'] as String? ?? 'Standard',
      createdAt: DateTime.parse(map['createdAt'] as String),
      dateOfService: map['dateOfService'] != null
          ? DateTime.parse(map['dateOfService'] as String)
          : null,
      expectedDeliveryDate: map['expectedDeliveryDate'] != null
          ? DateTime.parse(map['expectedDeliveryDate'] as String)
          : null,
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'] as String)
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      scanFiles: (map['scanFiles'] as String? ?? '').isEmpty
          ? []
          : (map['scanFiles'] as String).split(','),
    );
  }

  // ─── Clinician CRUD ────────────────────────────────────────────────────────

  Future<void> insertClinician(Clinician clinician) async {
    final db = await database;
    await db.insert(
      'clinicians',
      {
        'id': clinician.id,
        'name': clinician.name,
        'licenseNumber': clinician.licenseNumber,
        'isDefault': clinician.isDefault ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateClinician(Clinician clinician) async {
    final db = await database;
    await db.update(
      'clinicians',
      {
        'name': clinician.name,
        'licenseNumber': clinician.licenseNumber,
        'isDefault': clinician.isDefault ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [clinician.id],
    );
  }

  Future<void> deleteClinician(String id) async {
    final db = await database;
    await db.delete('clinicians', where: 'id = ?', whereArgs: [id]);
    await db.delete('clinics',
        where: 'clinicianId = ?', whereArgs: [id]);
  }

  Future<List<Clinician>> getAllClinicians() async {
    final db = await database;
    final maps = await db.query('clinicians');
    return maps.map((map) => Clinician(
      id: map['id'] as String,
      name: map['name'] as String,
      licenseNumber: map['licenseNumber'] as String? ?? '',
      isDefault: (map['isDefault'] as int? ?? 0) == 1,
    )).toList();
  }

  Future<void> setDefaultClinician(String id) async {
    final db = await database;
    await db.update('clinicians', {'isDefault': 0});
    await db.update('clinicians', {'isDefault': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ─── Clinic CRUD ───────────────────────────────────────────────────────────

  Future<void> insertClinic(Clinic clinic) async {
    final db = await database;
    await db.insert(
      'clinics',
      {
        'id': clinic.id,
        'clinicianId': clinic.clinicianId,
        'name': clinic.name,
        'address': clinic.address,
        'city': clinic.city,
        'state': clinic.state,
        'zip': clinic.zip,
        'phone': clinic.phone,
        'isDefault': clinic.isDefault ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateClinic(Clinic clinic) async {
    final db = await database;
    await db.update(
      'clinics',
      {
        'name': clinic.name,
        'address': clinic.address,
        'city': clinic.city,
        'state': clinic.state,
        'zip': clinic.zip,
        'phone': clinic.phone,
        'isDefault': clinic.isDefault ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [clinic.id],
    );
  }

  Future<void> deleteClinic(String id) async {
    final db = await database;
    await db.delete('clinics', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Clinic>> getClinicsForClinician(String clinicianId) async {
    final db = await database;
    final maps = await db.query('clinics',
        where: 'clinicianId = ?', whereArgs: [clinicianId]);
    return maps.map((map) => Clinic(
      id: map['id'] as String,
      clinicianId: map['clinicianId'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      zip: map['zip'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isDefault: (map['isDefault'] as int? ?? 0) == 1,
    )).toList();
  }

  Future<void> setDefaultClinic(String clinicianId, String clinicId) async {
    final db = await database;
    await db.update('clinics', {'isDefault': 0},
        where: 'clinicianId = ?', whereArgs: [clinicianId]);
    await db.update('clinics', {'isDefault': 1},
        where: 'id = ?', whereArgs: [clinicId]);
  }

  Future<List<Clinic>> getAllClinics() async {
    final db = await database;
    final maps = await db.query('clinics');
    return maps.map((map) => Clinic(
      id: map['id'] as String,
      clinicianId: map['clinicianId'] as String,
      name: map['name'] as String,
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      zip: map['zip'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      isDefault: (map['isDefault'] as int? ?? 0) == 1,
    )).toList();
  }
}