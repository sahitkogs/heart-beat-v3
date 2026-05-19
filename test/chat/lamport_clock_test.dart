import 'package:app_v3/chat/lamport_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tick increments monotonically', () {
    final c = LamportClock();
    expect(c.tick(), 1);
    expect(c.tick(), 2);
    expect(c.tick(), 3);
  });

  test('observe advances if remote is higher', () {
    final c = LamportClock();
    c.tick(); // 1
    c.observe(5); // jumps to 5
    expect(c.tick(), 6);
  });

  test('observe is a no-op if remote is lower or equal', () {
    final c = LamportClock();
    c.tick(); // 1
    c.tick(); // 2
    c.observe(1);
    c.observe(2);
    expect(c.tick(), 3);
  });

  test('value getter exposes current count', () {
    final c = LamportClock();
    expect(c.value, 0);
    c.tick();
    expect(c.value, 1);
  });
}
