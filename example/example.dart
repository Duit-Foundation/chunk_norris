import 'dart:async';
import 'dart:convert';

import 'package:chunk_norris/chunk_norris.dart';

void main() async {
  // // Пример 1: Базовое использование
  // print('=== Пример 1: Базовое использование ===');
  // await basicExample();

  // print('\n=== Пример 2: Асинхронная загрузка ===');
  // await asyncExample();

  print('\n=== Пример 3: Стриминг данных ===');
  await streamExample();
}

/// Пример базового использования
Future<void> basicExample() async {
  // Начальный JSON с плейсхолдерами
  final initialJson = <String, dynamic>{
    'user': {
      'name': 'John Doe',
      'avatar': '\$1', // Плейсхолдер для аватара
      'posts': '\$2', // Плейсхолдер для постов
    },
    'theme': 'dark',
  };

  // Создаем ChunkJson экземпляр
  final chunkJson = XJson(initialJson);

  // Получаем данные (плейсхолдеры пока не разрешены)
  print('Имя пользователя: ${chunkJson.getValue('user')['name']}');
  print('Аватар: ${chunkJson.getValue('user')['avatar']}'); // Выведет '\$1'

  // Для проверки состояния плейсхолдеров нужно проверить конкретное значение
  final userMap = chunkJson.getValue('user') as Map<String, dynamic>;
  print('Аватар (исходный): ${userMap['avatar']}');

  // Симулируем загрузку первого чанка
  final chunk1 = {
    '1': 'https://example.com/avatar.jpg',
  };

  chunkJson.processChunk(chunk1);

  // Теперь аватар разрешен
  print('Аватар после загрузки: ${chunkJson.getValue('user')['avatar']}');

  // Загружаем второй чанк
  final chunk2 = {
    '2': [
      {'id': 1, 'title': 'Первый пост'},
      {'id': 2, 'title': 'Второй пост'},
    ],
  };

  chunkJson.processChunk(chunk2);

  // Получаем полные данные
  final fullData = chunkJson.getResolvedData();
  print('Полные данные: ${jsonEncode(fullData)}');

  // Очищаем ресурсы
  chunkJson.dispose();
}

/// Пример асинхронной загрузки
Future<void> asyncExample() async {
  final initialJson = {
    'product': {
      'name': 'Смартфон',
      'price': 29999,
      'reviews': '\$1',
      'specifications': '\$2',
    },
  };

  final chunkJson = XJson(initialJson);

  // Запускаем асинхронную загрузку данных
  print('Загружаем отзывы...');

  // Симулируем задержку сети
  Timer(Duration(milliseconds: 500), () {
    chunkJson.processChunk(<String, dynamic>{
      '1': [
        {'author': 'Иван', 'rating': 5, 'text': 'Отличный телефон!'},
        {'author': 'Мария', 'rating': 4, 'text': 'Хорошее качество'},
      ],
    });
  });

  Timer(Duration(milliseconds: 1000), () {
    chunkJson.processChunk(
      <String, dynamic>{
        '2': {
          'screen': '6.1 дюйм',
          'memory': '128 ГБ',
          'camera': '48 Мп',
        },
      },
    );
  });

  try {
    // Ждем все чанки
    final fullProduct = await chunkJson.waitForAllChunks();

    // Теперь получаем reviews из полных данных
    final productData = fullProduct['product'] as Map<String, dynamic>;
    final reviewsList = productData['reviews'] as List;
    print('Отзывы загружены: ${reviewsList.length} отзывов');

    print('Все данные загружены: ${jsonEncode(fullProduct)}');
  } catch (e) {
    print('Ошибка загрузки: $e');
  }

  chunkJson.dispose();
}

/// Пример работы со стримами
Future<void> streamExample() async {
  final initialJson = <String, dynamic>{
    'dashboard': {
      'stats': '\$1',
      'charts': '\$2',
      'notifications': '\$3',
    },
  };

  final chunkJson = XJson(initialJson);

  print("Начальный JSON: $initialJson");

  // Подписываемся на обновления
  var subscription = chunkJson.updateStream.listen((chunk) {
    print('Получен новый чанк: ${chunk.keys.join(', ')}');

    // Проверяем, какие данные теперь доступны
    final resolved = chunkJson.getResolvedData();
    print('Текущие данные: $resolved');
  });

  // Подписываемся на ошибки
  chunkJson.errorStream.listen((error) {
    print('Ошибка: $error');
  });

  // Симулируем поступление чанков
  await Future.delayed(Duration(milliseconds: 300));
  chunkJson.processChunk({
    '1': {'users': 1250, 'orders': 89, 'revenue': 125000},
  });

  await Future.delayed(Duration(milliseconds: 300));
  chunkJson.processChunk({
    '2': {
      'sales': [10, 15, 8, 23, 18],
      'period': 'week'
    },
  });

  await Future.delayed(Duration(milliseconds: 300));
  chunkJson.processChunk({
    '3': [
      {'type': 'info', 'message': "\$4"},
      {'type': 'warning', 'message': 'Низкий остаток товара'},
    ],
  });

  // Даем время на обработку
  await Future.delayed(Duration(milliseconds: 300));

  chunkJson.processChunk({
    '4': {"lol": "popalsya"}
  });

  // Отписываемся и очищаем
  await subscription.cancel();
  chunkJson.dispose();

  print(chunkJson.getResolvedData());
}

/// Пример обработки потока чанков (например, из SSE)
Future<void> streamChunkProcessing() async {
  final initialJson = {
    'live_data': {
      'temperature': '\$1',
      'humidity': '\$2',
      'pressure': '\$3',
    },
  };

  final chunkJson = XJson(initialJson);

  // Создаем поток чанков (симулируем SSE)
  final chunkController = StreamController<String>();

  // Обрабатываем поток
  chunkJson.processChunkStream(chunkController.stream);

  // Симулируем поступление данных
  Timer.periodic(Duration(seconds: 1), (timer) {
    if (timer.tick > 3) {
      timer.cancel();
      chunkController.close();
      chunkJson.dispose();
      return;
    }

    final chunkData = {
      '${timer.tick}': 'data_${timer.tick}',
    };

    chunkController.add(jsonEncode(chunkData));
  });
}
