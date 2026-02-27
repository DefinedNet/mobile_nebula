import 'package:mobile_nebula/errors/parse_error.dart';
import 'package:mobile_nebula/models/cidr.dart';
import 'package:test/test.dart';

void main() {
  test('CIDR.fromString', () {
    var cidr = CIDR.fromString('1.1.1.1/32');
    expect(cidr.ip, '1.1.1.1');
    expect(cidr.bits, 32);

    cidr = CIDR.fromString('2600::1/128');
    expect(cidr.ip, '2600::1');
    expect(cidr.bits, 128);

    cidr = CIDR.fromString('::/0');
    expect(cidr.ip, '::');
    expect(cidr.bits, 0);

    expect(
      () => CIDR.fromString('blah'),
      throwsA(predicate((e) => e is ParseError && e.message == 'missing / separator')),
    );
    expect(
      () => CIDR.fromString('blah/bleg'),
      throwsA(predicate((e) => e is ParseError && e.message == 'ip prefix was not an ip address: blah')),
    );
    expect(
      () => CIDR.fromString('266.1.1.1/bleg'),
      throwsA(predicate((e) => e is ParseError && e.message == 'ip prefix was not an ip address: 266.1.1.1')),
    );
    expect(
      () => CIDR.fromString('rr::1/bleg'),
      throwsA(predicate((e) => e is ParseError && e.message == 'ip prefix was not an ip address: rr::1')),
    );
    expect(
      () => CIDR.fromString('1.1.1.1/bleg'),
      throwsA(predicate((e) => e is ParseError && e.message == 'prefix length was not an integer: bleg')),
    );
    expect(
      () => CIDR.fromString('1.1.1.1/-1'),
      throwsA(predicate((e) => e is ParseError && e.message == 'invalid prefix length: -1')),
    );
    expect(
      () => CIDR.fromString('2600::1/-1'),
      throwsA(predicate((e) => e is ParseError && e.message == 'invalid prefix length: -1')),
    );
    expect(
      () => CIDR.fromString('1.1.1.1/33'),
      throwsA(predicate((e) => e is ParseError && e.message == 'invalid prefix length: 33')),
    );
    expect(
      () => CIDR.fromString('2600::1/129'),
      throwsA(predicate((e) => e is ParseError && e.message == 'invalid prefix length: 129')),
    );
  });
}
