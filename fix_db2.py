import re

with open('C:/Projects/orthoscan/lib/services/database_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add typed_data import
if "import 'dart:typed_data'" not in content:
    content = "import 'dart:typed_data';\n" + content

# 2. Bump version
content = content.replace('version: 12,', 'version: 13,')

# 3. Add migration after oldVersion < 12 block
old_mig = "    if (oldVersion < 12) {\n      try { await db.execute('ALTER TABLE work_orders ADD COLUMN linkedWorkOrderId TEXT'); } catch (e) {}\n    }"
new_mig = old_mig + "\n    if (oldVersion < 13) {\n      try { await db.execute('ALTER TABLE work_orders ADD COLUMN leftDiagramPng BLOB'); } catch (ignored) {}\n      try { await db.execute('ALTER TABLE work_orders ADD COLUMN rightDiagramPng BLOB'); } catch (ignored) {}\n    }"
content = content.replace(old_mig, new_mig)

# 4. Add columns to createTables
content = content.replace('          linkedWorkOrderId TEXT,', '          linkedWorkOrderId TEXT,\n          leftDiagramPng BLOB,\n          rightDiagramPng BLOB,')

# 5. Add to toMap
content = content.replace("      'linkedWorkOrderId': wo.linkedWorkOrderId,", "      'linkedWorkOrderId': wo.linkedWorkOrderId,\n      'leftDiagramPng': wo.leftDiagramPng,\n      'rightDiagramPng': wo.rightDiagramPng,")

# 6. Add to fromMap
content = content.replace("      linkedWorkOrderId: map['linkedWorkOrderId'] as String?,", "      linkedWorkOrderId: map['linkedWorkOrderId'] as String?,\n      leftDiagramPng: map['leftDiagramPng'] as Uint8List?,\n      rightDiagramPng: map['rightDiagramPng'] as Uint8List?,")

with open('C:/Projects/orthoscan/lib/services/database_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done')
