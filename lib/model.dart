import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:characters/characters.dart';

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

@SerializersFor([Location, Crossword, CrosswordWord, CrosswordCharacter])
final Serializers serializers = _$serializers;