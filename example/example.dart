import 'package:chunk_norris/chunk_norris.dart';

class UserData {
  final String address;
  final String phone;

  UserData({
    required this.address,
    required this.phone,
  });

  factory UserData.fromJson(Map<String, dynamic> json) => UserData(
        address: json['address'],
        phone: json['phone'],
      );

  @override
  String toString() => 'UserData(address: $address, phone: $phone)';
}

// Подход с ChunkField (для более сложных случаев)
class User {
  final String name;
  final int age;
  final UserData data;
  final Map<String, dynamic> meta;
  User({
    required this.name,
    required this.age,
    required this.data,
    required this.meta,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        name: json['name'],
        age: json['age'],
        data: UserData.fromJson(json['data']),
        meta: json['meta'],
      );

  @override
  String toString() =>
      'TypedUser(name: $name, age: $age, data: $data, meta: $meta)';
}

void main() async {
  // print('\n=== Пример с ChunkField ===');
  // typedExample();

  final obj = ChunkObject.fromJson(
    {
      'name': 'John Doe',
      'age': 30,
      'data': '\$1',
      'meta': '\$2',
    },
    User.fromJson,
    chunkFields: {
      'data': ChunkField<UserData>(
        '1',
        (data) {
          print("Parsing UserData from chunk");
          return UserData.fromJson(data);
        },
      ),
      'meta': ChunkField(
        '2',
        (meta) => meta,
      ),
    },
  );

  print(obj);

  obj.fullyResolvedStream.listen((user) {
    print("New chunk: $user");
    obj.dispose();
  });

  await Future.delayed(const Duration(seconds: 1));

  obj.processChunk({
    '1': {
      'address': '123 Main St',
      'phone': '123-456-7890',
    },
  });

  await Future.delayed(const Duration(seconds: 1));

  obj.processChunk({
    '2': {
      'meta1': 'value1',
      'meta2': 'value2',
    },
  });
}
