class TestAccount {
  final String label;
  final String email;
  final String password;

  const TestAccount({
    required this.label,
    required this.email,
    required this.password,
  });
}

const List<TestAccount> kTestAccounts = [
  TestAccount(label: '독서왕1', email: 'reading1@test.com', password: '123456'),
  TestAccount(label: '독서왕2', email: 'reading2@test.com', password: '123456'),
  TestAccount(label: '독서왕3', email: 'reading3@test.com', password: '123456'),
  TestAccount(label: '독서왕4', email: 'reading4@test.com', password: '123456'),
  TestAccount(label: '독서왕5', email: 'reading5@test.com', password: '123456'),
];