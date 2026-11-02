# Vendored hotkey_manager_linux

This directory is an unchanged copy of the Linux implementation of `hotkey_manager`
from https://github.com/gepbird/hotkey_manager.git at commit
`1b31e3ca4ab017ee72f54a7065b2073a88403d61` (2025-10-21).

It retains the upstream Clang 21 compatibility fix for Linux desktop builds.
Upstream author and license: leanflutter and contributors, MIT (see LICENSE).

The upstream Git reference caused fresh Flutter 3.47.5 `pub get` CI runs
to report a missing subdirectory even though GitHub's tree contains the files.
The top-level `pubspec.yaml` therefore overrides `hotkey_manager_linux` with
this repository-local package path. Keep it in sync when updating
`hotkey_manager`; review changes to the vendored C++ code and its license.

Only the Linux implementation is vendored. macOS and Windows plugin variants
continue to use their regular hosted packages.
