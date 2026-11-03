import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/account_repository.dart';
import 'package:buyonce/data/services/account_service.dart';
import 'package:buyonce/data/services/in_memory_account_service.dart';
import 'package:buyonce/domain/models/account.dart';
import 'package:flutter_test/flutter_test.dart';

class _RealService extends InMemoryAccountService {
  _RealService() : super(seed: false);

  @override
  Future<Result<Account?>> getAccount(String userId) async => const Ok(
    Account(userId: 'uid-1', email: 'real@example.com', givenName: 'Real'),
  );
}

void main() {
  test(
    'the phone owner uses the real service, other users stay fake',
    () async {
      final AccountService real = _RealService();
      final repository = AccountRepository(
        InMemoryAccountService(seed: true),
        real,
      );

      final me = (await repository.getAccount('me') as Ok<Account?>).value;
      final partner =
          (await repository.getAccount('partner') as Ok<Account?>).value;

      expect(me?.userId, 'uid-1');
      expect(partner?.givenName, 'Anna');
    },
  );

  test('without a real service everyone is fake', () async {
    final repository = AccountRepository(InMemoryAccountService(seed: true));

    final me = (await repository.getAccount('me') as Ok<Account?>).value;

    expect(me?.givenName, 'Alexander');
  });
}
