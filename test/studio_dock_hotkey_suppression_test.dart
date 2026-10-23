import 'package:flutter_test/flutter_test.dart';
import 'package:subtitle_studio/utils/msone_hotkey_manager.dart';

void main() {
  test('desktop read-only shortcut suppression is nest-safe', () {
    final hotkeys = MSoneHotkeyManager.instance;
    expect(hotkeys.callbacksSuspended, isFalse);

    hotkeys.suspendCallbacks();
    expect(hotkeys.callbacksSuspended, isTrue);
    hotkeys.suspendCallbacks();
    hotkeys.resumeCallbacks();
    expect(hotkeys.callbacksSuspended, isTrue);
    hotkeys.resumeCallbacks();
    expect(hotkeys.callbacksSuspended, isFalse);

    // A route disposing twice cannot leave callbacks in an invalid state.
    hotkeys.resumeCallbacks();
    expect(hotkeys.callbacksSuspended, isFalse);
  });
}
