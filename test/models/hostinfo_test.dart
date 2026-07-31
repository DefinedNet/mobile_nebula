import 'package:mobile_nebula/models/hostinfo.dart';
import 'package:test/test.dart';

Map<String, dynamic> _base() {
  return {
    'vpnAddrs': ['10.0.0.2'],
    'localIndex': 1,
    'remoteIndex': 2,
    'remoteAddrs': ['1.1.1.1:4242'],
    'messageCounter': 5,
    'currentRemote': '1.1.1.1:4242',
  };
}

void main() {
  group('HostInfo.fromJson', () {
    test('no relay fields', () {
      final h = HostInfo.fromJson(_base());
      expect(h.currentRelaysToMe, isEmpty);
      expect(h.currentRelaysThroughMe, isEmpty);
      expect(h.isRelayed, false);
    });

    test('relayed', () {
      final json = _base();
      json['currentRemote'] = '';
      json['remoteAddrs'] = [];
      json['currentRelaysToMe'] = ['10.0.0.1'];

      final h = HostInfo.fromJson(json);
      expect(h.currentRemote, null);
      expect(h.currentRelaysToMe, ['10.0.0.1']);
      expect(h.isRelayed, true);
    });

    test('relaying for others but direct to this host', () {
      final json = _base();
      json['currentRelaysThroughMe'] = ['10.0.0.3'];

      final h = HostInfo.fromJson(json);
      expect(h.currentRelaysThroughMe, ['10.0.0.3']);
      expect(h.isRelayed, false);
    });

    test('has a relay but is also direct', () {
      final json = _base();
      json['currentRelaysToMe'] = ['10.0.0.1'];

      final h = HostInfo.fromJson(json);
      expect(h.isRelayed, false);
    });
  });
}
