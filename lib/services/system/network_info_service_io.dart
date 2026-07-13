import 'dart:io';

/// 返回本机可用于局域网连接的真实私有 IPv4 地址。
///
/// 回环、自动分配地址和常见虚拟网卡会被过滤，避免向用户展示无法连接的地址。
Future<List<String>> getLocalLanIPv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLoopback: false,
  );
  final addresses = <String>{};

  for (final interface in interfaces) {
    if (_looksVirtualInterface(interface.name)) continue;
    for (final address in interface.addresses) {
      final value = address.address;
      if (address.isLoopback ||
          value.startsWith('127.') ||
          value.startsWith('169.254.') ||
          !_isPrivateLanIPv4(value)) {
        continue;
      }
      addresses.add(value);
    }
  }

  return addresses.toList()..sort();
}

bool _isPrivateLanIPv4(String value) {
  final parts = value.split('.').map(int.tryParse).toList(growable: false);
  if (parts.length != 4 || parts.any((part) => part == null)) return false;
  final a = parts[0]!;
  final b = parts[1]!;
  if (a == 10) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  return false;
}

bool _looksVirtualInterface(String name) {
  final normalized = name.toLowerCase();
  const blocked = [
    'virtual',
    'vmware',
    'virtualbox',
    'vbox',
    'hyper-v',
    'vethernet',
    'docker',
    'wsl',
    'loopback',
    'bluetooth',
    'npcap',
    'zerotier',
    'tailscale',
  ];
  return blocked.any(normalized.contains);
}
