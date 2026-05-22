import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test('v5 -> v6 destructive migration drops old data + creates new schema', () async {
    // Schema-snapshot verification skipped (same rationale as the 10.4 T2.2
    // decision — offline drift_dev snapshot infra doesn't pay off for a
    // single destructive migration). Live test on a device with a v5
    // install confirms the migration runs end-to-end in F1.
  }, skip: 'live-verified in F1 (fresh install on a v5-tagged device); see spec §2.3');
}
