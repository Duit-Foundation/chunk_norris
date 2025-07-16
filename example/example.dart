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

class User {
  final String name;
  final int age;
  final UserData data;
  final Map<String, dynamic> meta;
  final Map<String, dynamic> some;
  User({
    required this.name,
    required this.age,
    required this.data,
    required this.meta,
    required this.some,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        name: json['name'],
        age: json['age'],
        data: UserData.fromJson(json['data']),
        meta: json['meta'],
        some: json['some'],
      );

  @override
  String toString() =>
      'User(name: $name, age: $age, data: $data, meta: $meta, some: $some)';
}

Future<void> chunkObjectExample() async {
  print('\n=== ChunkObject example ===');

  final chunkedObject = ChunkObject.fromJson(
    {
      'name': 'John Doe',
      'age': 30,
      'data': '\$1',
      'meta': '\$2',
      'some': '\$3',
    },
    User.fromJson,
    chunkFields: {
      'data': ChunkField.object<UserData>(
        '1',
        (data) => UserData.fromJson(data),
      ),
      'meta': ChunkField(
        '2',
        (meta) => meta,
      ),
    },
  );

  // chunkedObject.listenChunkStates(onData) listen chunk state change
  // chunkedObject.listenChunkUpdate(onData) listen chunk update with resolved data
  // chunkedObject.listenRawChunkUpdate(onData) listen chunk update with raw data
  // chunkedObject.listenObjectUpdate(onData) listen root object update

  // listen when all chunks resolved
  chunkedObject.listenObjectResolve(
    (user) {
      print(
          "All chunks resolved! \n ${user.name} \n ${user.age} \n ${user.data} \n ${user.meta} \n ${user.some}");
    },
    onError: (error) {
      print("Error: $error");
    },
    onDone: () {
      print("Stream is done");
    },
  );

  await Future.delayed(const Duration(seconds: 1));

  await chunkedObject.processChunk({
    '1': {
      'address': '123 Main St',
      'phone': '123-456-7890',
    },
  });

  await Future.delayed(const Duration(seconds: 1));

  await chunkedObject.processChunk({
    '2': {
      'meta1': 'value1',
      'meta2': 'value2',
    },
  });

  await Future.delayed(const Duration(seconds: 1));

  await chunkedObject.processChunk({
    '3': {
      'some': 'value3',
    },
  });

  await chunkedObject.waitForData();
  chunkedObject.dispose();

  print("=" * 30);
}

Future<void> chunkJsonExample() async {
  print('\n=== ChunkJson example ===');

  final chunkedJson = ChunkJson.fromJson({
    'name': 'John Doe',
    'age': 30,
    'data': '\$1',
    'meta': '\$2',
    'some': '\$3',
  });

  final subscription = chunkedJson.listenUpdateStream((chunk) {
    print('Chunk update: $chunk');
    print('Current resolved json: ${chunkedJson.getResolvedData()}');
    print(
        'States: data=${chunkedJson.getKeyState('data')}, meta=${chunkedJson.getKeyState('meta')}, some=${chunkedJson.getKeyState('some')}');
  }, onError: (error) {
    print('Error: $error');
  }, onDone: () {
    print('Stream is done');
  });

  await Future.delayed(const Duration(seconds: 1));

  await chunkedJson.processChunk({
    '1': {
      'address': '123 Main St',
      'phone': '123-456-7890',
    },
  });

  await Future.delayed(const Duration(seconds: 1));

  await chunkedJson.processChunk({
    '2': {
      'meta1': 'value1',
      'meta2': 'value2',
    },
  });

  await Future.delayed(const Duration(seconds: 1));

  await chunkedJson.processChunk({
    '3': {
      'some': 'value3',
    },
  });

  // Ждём полной загрузки всех чанков
  final resolved = await chunkedJson.waitForAllData();
  print('All chunks resolved! Final json: $resolved');

  // Пример асинхронного получения значения
  final data = await chunkedJson.getValueAsync('data');
  print('Async loaded data: $data');

  subscription.cancel();
  chunkedJson.dispose();

  print("=" * 30);
}

void main() async {
  await chunkJsonExample();
  await chunkObjectExample();
}
