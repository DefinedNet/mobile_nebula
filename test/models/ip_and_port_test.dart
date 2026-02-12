import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/models/ip_and_port.dart';
import 'package:test/test.dart';

void main() {
  group('IPAndPort.fromString', () {
    test('ipv4', () {
      var addr = IPAndPort.fromString('10.0.0.1:9999');
      expect(addr.ip, '10.0.0.1');
      expect(addr.port, 9999);
      expect(addr.toString(), '10.0.0.1:9999');
      expect(addr.toJson(), '10.0.0.1:9999');

      expect(
        () => IPAndPort.fromString('1.1.1.1'),
        throwsA(predicate((e) => e is ParseError && e.message == 'missing port in address')),
      );
      expect(
        () => IPAndPort.fromString('1:1:1'),
        throwsA(predicate((e) => e is ParseError && e.message == 'IPv6 address must be enclosed in brackets')),
      );
      expect(
        () => IPAndPort.fromString('256.255.255.255:999'),
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid address: 256.255.255.255')),
      );
      expect(
        () => IPAndPort.fromString('255.255.255.255:-1'),
        throwsA(predicate((e) => e is ParseError && e.message == 'port out of range: -1')),
      );
      expect(
        () => IPAndPort.fromString('255.255.255.255:65536'),
        throwsA(predicate((e) => e is ParseError && e.message == 'port out of range: 65536')),
      );
      expect(
        () => IPAndPort.fromString('255.255.255.255:derp'),
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid port: derp')),
      );
      expect(
        () => IPAndPort.fromString('10.10.10.10:'),
        throwsA(predicate((e) => e is ParseError && e.message == 'port is empty')),
      );
    });

    test('ipv6', () {
      var addr = IPAndPort.fromString('[2600::1]:9999');
      expect(addr.ip, '2600::1');
      expect(addr.port, 9999);
      expect(addr.toString(), '[2600::1]:9999');
      expect(addr.toJson(), '[2600::1]:9999');

      expect(
        () => IPAndPort.fromString('[woops'),
        throwsA(predicate((e) => e is ParseError && e.message == 'missing ] in address')),
      );
      expect(
        () => IPAndPort.fromString('[2600::1]'),
        throwsA(predicate((e) => e is ParseError && e.message == 'missing port in address')),
      );
      expect(
        () => IPAndPort.fromString('[this is silly]:1000'),
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid IPv6 address: this is silly')),
      );
      expect(
        () => IPAndPort.fromString('[2600::1]:-1'),
        throwsA(predicate((e) => e is ParseError && e.message == 'port out of range: -1')),
      );
      expect(
        () => IPAndPort.fromString('[2600::1]:65536'),
        throwsA(predicate((e) => e is ParseError && e.message == 'port out of range: 65536')),
      );
      expect(
        () => IPAndPort.fromString('[2600::1]:derp'),
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid port: derp')),
      );
      expect(
        () => IPAndPort.fromString('[2600::1]:'),
        throwsA(predicate((e) => e is ParseError && e.message == 'port is empty')),
      );
    });

    test('dns name', () {
      var addr = IPAndPort.fromString('totally.fine:9999');
      expect(addr.ip, 'totally.fine');
      expect(addr.port, 9999);
      expect(addr.toString(), 'totally.fine:9999');
      expect(addr.toJson(), 'totally.fine:9999');

      expect(
        () => IPAndPort.fromString('hey:9000'), // missing TLD
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid address: hey')),
      );
      expect(
        () => IPAndPort.fromString('hey.c:9000'),
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid address: hey.c')),
      );
      expect(
        () => IPAndPort.fromString('_hey.c:9000'),
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid address: _hey.c')),
      );
      expect(
        () => IPAndPort.fromString('_hey.com:9000'),
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid address: _hey.com')),
      );
      expect(
        () => IPAndPort.fromString('hey.com:derp'),
        throwsA(predicate((e) => e is ParseError && e.message == 'invalid port: derp')),
      );
      expect(
        () => IPAndPort.fromString('hey.com:'),
        throwsA(predicate((e) => e is ParseError && e.message == 'port is empty')),
      );
    });
  });
}
