import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/product_names.dart';
import 'package:flutter_test/flutter_test.dart';

Product _p(String id, String name) =>
    Product(id: id, groupId: 'g', name: name, position: 0);

void main() {
  test('normalize trims, collapses spaces and clips', () {
    expect(ProductNames.normalize('  Oat   milk \n'), 'Oat milk');
    expect(ProductNames.normalize('x' * 150).length, 100);
    expect(ProductNames.normalize('   '), '');
  });

  test('an empty name is a problem', () {
    final c = ProductNames.check('  ', const []);
    expect(c.problem, NameProblem.empty);
    expect(c.ok, isFalse);
  });

  test('a name of another product is a duplicate in any case', () {
    final products = [_p('1', 'Milk'), _p('2', 'Ziemniaki')];
    expect(ProductNames.check('milk', products).problem, NameProblem.duplicate);
    expect(
      ProductNames.check(' ZIEMNIAKI ', products).problem,
      NameProblem.duplicate,
    );
    expect(ProductNames.check('Oat   milk', products).ok, isTrue);
    expect(
      ProductNames.check('ŁOSOŚ', [_p('3', 'łosoś')]).problem,
      NameProblem.duplicate,
    );
  });

  test(
    'the product itself is left out, so a rename may change only the case',
    () {
      final products = [_p('1', 'Milk'), _p('2', 'Tea')];
      final c = ProductNames.check('MILK', products, selfId: '1');
      expect(c.ok, isTrue);
      expect(c.name, 'MILK');
      expect(
        ProductNames.check('tea', products, selfId: '1').problem,
        NameProblem.duplicate,
      );
    },
  );

  test('the checked name is the cleaned one', () {
    expect(ProductNames.check('  Rye   bread ', const []).name, 'Rye bread');
  });
}
