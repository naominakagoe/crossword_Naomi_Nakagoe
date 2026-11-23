import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:characters/characters.dart';
import 'package:intl/intl.dart';

part 'model.g.dart';

/// Una posición (x, y) en el crucigrama, empezando desde 0.
abstract class Location implements Built<Location, LocationBuilder> {
  static Serializer<Location> get serializer => _$locationSerializer;

  int get x;
  int get y;

  Location get left => rebuild((b) => b.x = x - 1);
  Location get right => rebuild((b) => b.x = x + 1);
  Location get up => rebuild((b) => b.y = y - 1);
  Location get down => rebuild((b) => b.y = y + 1);

  Location leftOffset(int offset) => rebuild((b) => b.x = x - offset);
  Location rightOffset(int offset) => rebuild((b) => b.x = x + offset);
  Location upOffset(int offset) => rebuild((b) => b.y = y - offset);
  Location downOffset(int offset) => rebuild((b) => b.y = y + offset);

  String prettyPrint() => '($x, $y)';

  factory Location.at(int x, int y) {
    return Location((b) {
      b
        ..x = x
        ..y = y;
    });
  }

  factory Location([void Function(LocationBuilder)? updates]) = _$Location;
  Location._();
}

/// Dirección de una palabra.
enum Direction {
  across,
  down;

  @override
  String toString() => name;
}

/// Una palabra colocada en el crucigrama.
abstract class CrosswordWord
    implements Built<CrosswordWord, CrosswordWordBuilder> {
  static Serializer<CrosswordWord> get serializer => _$crosswordWordSerializer;

  static int locationComparator(CrosswordWord a, CrosswordWord b) {
    final compareRows = a.location.y.compareTo(b.location.y);
    final compareColumns = a.location.x.compareTo(b.location.x);
    return switch (compareColumns) {
      0 => compareRows,
      _ => compareColumns,
    };
  }

  factory CrosswordWord.word({
    required String word,
    required Location location,
    required Direction direction,
  }) {
    return CrosswordWord(
      (b) => b
        ..word = word
        ..direction = direction
        ..location.replace(location),
    );
  }

  String get word;
  Location get location;
  Direction get direction;

  factory CrosswordWord([void Function(CrosswordWordBuilder)? updates]) =
      _$CrosswordWord;
  CrosswordWord._();
}

/// Un carácter del crucigrama, con las palabras que pasan por él.
abstract class CrosswordCharacter
    implements Built<CrosswordCharacter, CrosswordCharacterBuilder> {
  static Serializer<CrosswordCharacter> get serializer =>
      _$crosswordCharacterSerializer;

  factory CrosswordCharacter.character({
    required String character,
    CrosswordWord? acrossWord,
    CrosswordWord? downWord,
  }) {
    return CrosswordCharacter((b) {
      b.character = character;
      if (acrossWord != null) {
        b.acrossWord.replace(acrossWord);
      }
      if (downWord != null) {
        b.downWord.replace(downWord);
      }
    });
  }

  String get character;
  CrosswordWord? get acrossWord;
  CrosswordWord? get downWord;

  factory CrosswordCharacter([
    void Function(CrosswordCharacterBuilder)? updates,
  ]) = _$CrosswordCharacter;
  CrosswordCharacter._();
}

/// El crucigrama completo.
abstract class Crossword implements Built<Crossword, CrosswordBuilder> {
  static Serializer<Crossword> get serializer => _$crosswordSerializer;

    /// Verifica que el crucigrama cumpla las reglas de un crucigrama en inglés.
  bool get valid {
    // No puede haber palabras repetidas.
    final wordSet = words.map((word) => word.word).toBuiltSet();
    if (wordSet.length != words.length) {
      return false;
    }

    for (final entry in characters.entries) {
      final location = entry.key;
      final character = entry.value;

      // Todo carácter tiene que pertenecer a una palabra.
      if (character.acrossWord == null && character.downWord == null) {
        return false;
      }

      // Todo carácter tiene que estar dentro de la grilla.
      if (location.x < 0 ||
          location.y < 0 ||
          location.x >= width ||
          location.y >= height) {
        return false;
      }

      // Los vecinos de arriba y abajo tienen que ser de la misma palabra vertical.
      final up = characters[location.up];
      if (up != null) {
        if (character.downWord == null) return false;
        if (up.downWord != character.downWord) return false;
      }
      final down = characters[location.down];
      if (down != null) {
        if (character.downWord == null) return false;
        if (down.downWord != character.downWord) return false;
      }

      // Los vecinos de izquierda y derecha tienen que ser de la misma palabra horizontal.
      final left = characters[location.left];
      if (left != null) {
        if (character.acrossWord == null) return false;
        if (left.acrossWord != character.acrossWord) return false;
      }
      final right = characters[location.right];
      if (right != null) {
        if (character.acrossWord == null) return false;
        if (right.acrossWord != character.acrossWord) return false;
      }
    }

    return true;
  }

  /// Agrega una palabra. Devuelve null si la ubicación no es válida.
  Crossword? addWord({
    required Location location,
    required String word,
    required Direction direction,
  }) {
    // La palabra no puede estar ya en el crucigrama.
    if (words.map((crosswordWord) => crosswordWord.word).contains(word)) {
      return null;
    }

    var overlap = false;

    for (final (index, character) in word.characters.indexed) {
      final characterLocation = switch (direction) {
        Direction.across => location.rightOffset(index),
        Direction.down => location.downOffset(index),
      };

      final target = characters[characterLocation];
      if (target != null) {
        overlap = true;
        // Si la celda está ocupada, la letra tiene que coincidir.
        if (target.character != character) {
          return null;
        }
        // Y no puede haber otra palabra en la misma dirección.
        if (direction == Direction.across && target.acrossWord != null ||
            direction == Direction.down && target.downWord != null) {
          return null;
        }
      }
    }

    // Después de la primera, cada palabra tiene que cruzarse con otra.
    if (words.isNotEmpty && !overlap) {
      return null;
    }

    final candidate = rebuild(
      (b) => b
        ..words.add(
          CrosswordWord.word(
            word: word,
            direction: direction,
            location: location,
          ),
        ),
    );

    if (candidate.valid) {
      return candidate;
    } else {
      return null;
    }
  }

  @BuiltValueHook(finalizeBuilder: true)
  static void _fillCharacters(CrosswordBuilder b) {
    b.characters.clear();

    for (final word in b.words.build()) {
      for (final (idx, character) in word.word.characters.indexed) {
        switch (word.direction) {
          case Direction.across:
            b.characters.updateValue(
              word.location.rightOffset(idx),
              (b) => b.rebuild((bInner) => bInner.acrossWord.replace(word)),
              ifAbsent: () => CrosswordCharacter.character(
                acrossWord: word,
                character: character,
              ),
            );
          case Direction.down:
            b.characters.updateValue(
              word.location.downOffset(idx),
              (b) => b.rebuild((bInner) => bInner.downWord.replace(word)),
              ifAbsent: () => CrosswordCharacter.character(
                downWord: word,
                character: character,
              ),
            );
        }
      }
    }
  }

  String prettyPrintCrossword() {
    final grid = List.generate(
      height,
      (_) => List.generate(width, (_) => '░'),
    );

    for (final entry in characters.entries) {
      final x = entry.key.x;
      final y = entry.key.y;
      if (x >= 0 && x < width && y >= 0 && y < height) {
        grid[y][x] = entry.value.character;
      }
    }

    final buffer = StringBuffer();
    for (final row in grid) {
      buffer.writeln(row.join());
    }
    return buffer.toString();
  }

  factory Crossword.crossword({
    required int width,
    required int height,
    Iterable<CrosswordWord>? words,
  }) {
    return Crossword((b) {
      b
        ..width = width
        ..height = height;
      if (words != null) {
        b.words.addAll(words);
      }
    });
  }

  int get width;
  int get height;
  BuiltList<CrosswordWord> get words;
  BuiltMap<Location, CrosswordCharacter> get characters;

  factory Crossword([void Function(CrosswordBuilder)? updates]) = _$Crossword;
  Crossword._();
}

/// Cola de trabajo: el crucigrama actual, las ubicaciones que falta probar,
/// las ubicaciones que ya fallaron y las palabras que todavía se pueden usar.
abstract class WorkQueue implements Built<WorkQueue, WorkQueueBuilder> {
  static Serializer<WorkQueue> get serializer => _$workQueueSerializer;

  Crossword get crossword;
  BuiltMap<Location, Direction> get locationsToTry;
  BuiltSet<Location> get badLocations;
  BuiltSet<String> get candidateWords;

  bool get isCompleted => locationsToTry.isEmpty || candidateWords.isEmpty;

  static WorkQueue from({
    required Crossword crossword,
    required Iterable<String> candidateWords,
    required Location startLocation,
  }) =>
      WorkQueue((b) {
        if (crossword.words.isEmpty) {
          // Crucigrama vacío: descartamos palabras que no entran a lo ancho
          // y arrancamos desde startLocation.
          b.candidateWords.addAll(
            candidateWords.where(
              (word) => word.characters.length <= crossword.width,
            ),
          );
          b.crossword.replace(crossword);
          b.locationsToTry.addAll({startLocation: Direction.across});
        } else {
          // Sacamos las palabras que ya están usadas.
          b.candidateWords.addAll(
            candidateWords.toBuiltSet().rebuild(
                  (b) => b.removeAll(crossword.words.map((word) => word.word)),
                ),
          );
          b.crossword.replace(crossword);

          // Buscamos celdas donde se pueda cruzar una palabra nueva.
          crossword.characters
              .rebuild(
                (b) => b.removeWhere((location, character) {
                  // Ya es parte de dos palabras.
                  if (character.acrossWord != null &&
                      character.downWord != null) {
                    return true;
                  }
                  // Tiene vecinos que bloquean una palabra perpendicular.
                  final left = crossword.characters[location.left];
                  if (left != null && left.downWord != null) return true;
                  final right = crossword.characters[location.right];
                  if (right != null && right.downWord != null) return true;
                  final up = crossword.characters[location.up];
                  if (up != null && up.acrossWord != null) return true;
                  final down = crossword.characters[location.down];
                  if (down != null && down.acrossWord != null) return true;
                  return false;
                }),
              )
              .forEach((location, character) {
            b.locationsToTry.addAll({
              location: switch ((character.acrossWord, character.downWord)) {
                (null, null) =>
                  throw StateError('Character is not part of a word'),
                (null, _) => Direction.across,
                (_, null) => Direction.down,
                (_, _) => throw StateError('Character is part of two words'),
              },
            });
          });
        }
      });

  /// Marca una ubicación como mala y la saca de la cola.
  WorkQueue remove(Location location) => rebuild(
        (b) => b
          ..locationsToTry.remove(location)
          ..badLocations.add(location),
      );

  /// Actualiza la cola a partir de un crucigrama nuevo, sin olvidar
  /// las ubicaciones que ya fallaron.
  WorkQueue updateFrom(Crossword crossword) => WorkQueue.from(
        crossword: crossword,
        candidateWords: candidateWords,
        startLocation: Location.at(0, 0),
      ).rebuild(
        (b) => b
          ..badLocations.addAll(badLocations)
          ..locationsToTry.removeWhere(
            (location, _) => badLocations.contains(location),
          ),
      );

  factory WorkQueue([void Function(WorkQueueBuilder)? updates]) = _$WorkQueue;
  WorkQueue._();
}

/// Estadísticas para mostrar en pantalla.
abstract class DisplayInfo implements Built<DisplayInfo, DisplayInfoBuilder> {
  static Serializer<DisplayInfo> get serializer => _$displayInfoSerializer;

  String get wordsInGridCount;
  String get candidateWordsCount;
  String get locationsToExploreCount;
  String get knownBadLocationsCount;
  String get gridFilledPercentage;

  factory DisplayInfo.from({required WorkQueue workQueue}) {
    final gridFilled = workQueue.crossword.characters.length /
        (workQueue.crossword.width * workQueue.crossword.height);
    final fmt = NumberFormat.decimalPattern();

    return DisplayInfo(
      (b) => b
        ..wordsInGridCount = fmt.format(workQueue.crossword.words.length)
        ..candidateWordsCount = fmt.format(workQueue.candidateWords.length)
        ..locationsToExploreCount = fmt.format(workQueue.locationsToTry.length)
        ..knownBadLocationsCount = fmt.format(workQueue.badLocations.length)
        ..gridFilledPercentage = '${(gridFilled * 100).toStringAsFixed(2)}%',
    );
  }

  static DisplayInfo get empty => DisplayInfo(
        (b) => b
          ..wordsInGridCount = '0'
          ..candidateWordsCount = '0'
          ..locationsToExploreCount = '0'
          ..knownBadLocationsCount = '0'
          ..gridFilledPercentage = '0%',
      );

  factory DisplayInfo([void Function(DisplayInfoBuilder)? updates]) =
      _$DisplayInfo;
  DisplayInfo._();
}

@SerializersFor([
  Location,
  Crossword,
  CrosswordWord,
  CrosswordCharacter,
  WorkQueue,
  DisplayInfo,
])
final Serializers serializers = _$serializers;