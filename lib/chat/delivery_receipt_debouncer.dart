// Stubbed in Task 7. Full implementation lands in Task 10.
class DeliveryReceiptDebouncer {
  DeliveryReceiptDebouncer(this._noop);
  // ignore: unused_field
  final dynamic _noop;
  void enqueueDelivered({required String peer, required String msgId}) {}
  void enqueueRead({required String peer, required List<String> msgIds}) {}
  Future<void> flushAllForTest() async {}
}
