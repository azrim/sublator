// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) =>
      Setting(key: key ?? this.key, value: value ?? this.value);
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GlossaryEntryTable extends GlossaryEntry
    with TableInfo<$GlossaryEntryTable, GlossaryEntryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GlossaryEntryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<String> target = GeneratedColumn<String>(
    'target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caseSensitiveMeta = const VerificationMeta(
    'caseSensitive',
  );
  @override
  late final GeneratedColumn<bool> caseSensitive = GeneratedColumn<bool>(
    'case_sensitive',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("case_sensitive" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, source, target, caseSensitive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'glossary_entry';
  @override
  VerificationContext validateIntegrity(
    Insertable<GlossaryEntryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('target')) {
      context.handle(
        _targetMeta,
        target.isAcceptableOrUnknown(data['target']!, _targetMeta),
      );
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('case_sensitive')) {
      context.handle(
        _caseSensitiveMeta,
        caseSensitive.isAcceptableOrUnknown(
          data['case_sensitive']!,
          _caseSensitiveMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GlossaryEntryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GlossaryEntryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      target: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target'],
      )!,
      caseSensitive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}case_sensitive'],
      )!,
    );
  }

  @override
  $GlossaryEntryTable createAlias(String alias) {
    return $GlossaryEntryTable(attachedDatabase, alias);
  }
}

class GlossaryEntryData extends DataClass
    implements Insertable<GlossaryEntryData> {
  final int id;
  final String source;
  final String target;
  final bool caseSensitive;
  const GlossaryEntryData({
    required this.id,
    required this.source,
    required this.target,
    required this.caseSensitive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    map['target'] = Variable<String>(target);
    map['case_sensitive'] = Variable<bool>(caseSensitive);
    return map;
  }

  GlossaryEntryCompanion toCompanion(bool nullToAbsent) {
    return GlossaryEntryCompanion(
      id: Value(id),
      source: Value(source),
      target: Value(target),
      caseSensitive: Value(caseSensitive),
    );
  }

  factory GlossaryEntryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GlossaryEntryData(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      target: serializer.fromJson<String>(json['target']),
      caseSensitive: serializer.fromJson<bool>(json['caseSensitive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'target': serializer.toJson<String>(target),
      'caseSensitive': serializer.toJson<bool>(caseSensitive),
    };
  }

  GlossaryEntryData copyWith({
    int? id,
    String? source,
    String? target,
    bool? caseSensitive,
  }) => GlossaryEntryData(
    id: id ?? this.id,
    source: source ?? this.source,
    target: target ?? this.target,
    caseSensitive: caseSensitive ?? this.caseSensitive,
  );
  GlossaryEntryData copyWithCompanion(GlossaryEntryCompanion data) {
    return GlossaryEntryData(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      target: data.target.present ? data.target.value : this.target,
      caseSensitive: data.caseSensitive.present
          ? data.caseSensitive.value
          : this.caseSensitive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GlossaryEntryData(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('target: $target, ')
          ..write('caseSensitive: $caseSensitive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, source, target, caseSensitive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlossaryEntryData &&
          other.id == this.id &&
          other.source == this.source &&
          other.target == this.target &&
          other.caseSensitive == this.caseSensitive);
}

class GlossaryEntryCompanion extends UpdateCompanion<GlossaryEntryData> {
  final Value<int> id;
  final Value<String> source;
  final Value<String> target;
  final Value<bool> caseSensitive;
  const GlossaryEntryCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.target = const Value.absent(),
    this.caseSensitive = const Value.absent(),
  });
  GlossaryEntryCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    required String target,
    this.caseSensitive = const Value.absent(),
  }) : source = Value(source),
       target = Value(target);
  static Insertable<GlossaryEntryData> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? target,
    Expression<bool>? caseSensitive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (target != null) 'target': target,
      if (caseSensitive != null) 'case_sensitive': caseSensitive,
    });
  }

  GlossaryEntryCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String>? target,
    Value<bool>? caseSensitive,
  }) {
    return GlossaryEntryCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      target: target ?? this.target,
      caseSensitive: caseSensitive ?? this.caseSensitive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (target.present) {
      map['target'] = Variable<String>(target.value);
    }
    if (caseSensitive.present) {
      map['case_sensitive'] = Variable<bool>(caseSensitive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GlossaryEntryCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('target: $target, ')
          ..write('caseSensitive: $caseSensitive')
          ..write(')'))
        .toString();
  }
}

class $SystemPromptTable extends SystemPrompt
    with TableInfo<$SystemPromptTable, SystemPromptData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SystemPromptTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, content, isActive];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'system_prompt';
  @override
  VerificationContext validateIntegrity(
    Insertable<SystemPromptData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SystemPromptData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SystemPromptData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $SystemPromptTable createAlias(String alias) {
    return $SystemPromptTable(attachedDatabase, alias);
  }
}

class SystemPromptData extends DataClass
    implements Insertable<SystemPromptData> {
  final int id;
  final String name;
  final String content;
  final bool isActive;
  const SystemPromptData({
    required this.id,
    required this.name,
    required this.content,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['content'] = Variable<String>(content);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  SystemPromptCompanion toCompanion(bool nullToAbsent) {
    return SystemPromptCompanion(
      id: Value(id),
      name: Value(name),
      content: Value(content),
      isActive: Value(isActive),
    );
  }

  factory SystemPromptData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SystemPromptData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      content: serializer.fromJson<String>(json['content']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'content': serializer.toJson<String>(content),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  SystemPromptData copyWith({
    int? id,
    String? name,
    String? content,
    bool? isActive,
  }) => SystemPromptData(
    id: id ?? this.id,
    name: name ?? this.name,
    content: content ?? this.content,
    isActive: isActive ?? this.isActive,
  );
  SystemPromptData copyWithCompanion(SystemPromptCompanion data) {
    return SystemPromptData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      content: data.content.present ? data.content.value : this.content,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SystemPromptData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, content, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SystemPromptData &&
          other.id == this.id &&
          other.name == this.name &&
          other.content == this.content &&
          other.isActive == this.isActive);
}

class SystemPromptCompanion extends UpdateCompanion<SystemPromptData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> content;
  final Value<bool> isActive;
  const SystemPromptCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.content = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  SystemPromptCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String content,
    this.isActive = const Value.absent(),
  }) : name = Value(name),
       content = Value(content);
  static Insertable<SystemPromptData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? content,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (content != null) 'content': content,
      if (isActive != null) 'is_active': isActive,
    });
  }

  SystemPromptCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? content,
    Value<bool>? isActive,
  }) {
    return SystemPromptCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SystemPromptCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('content: $content, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $TranslationHistoryTable extends TranslationHistory
    with TableInfo<$TranslationHistoryTable, TranslationHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TranslationHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceLanguageMeta = const VerificationMeta(
    'sourceLanguage',
  );
  @override
  late final GeneratedColumn<String> sourceLanguage = GeneratedColumn<String>(
    'source_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetLanguageMeta = const VerificationMeta(
    'targetLanguage',
  );
  @override
  late final GeneratedColumn<String> targetLanguage = GeneratedColumn<String>(
    'target_language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalContentMeta = const VerificationMeta(
    'originalContent',
  );
  @override
  late final GeneratedColumn<String> originalContent = GeneratedColumn<String>(
    'original_content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translatedContentMeta = const VerificationMeta(
    'translatedContent',
  );
  @override
  late final GeneratedColumn<String> translatedContent =
      GeneratedColumn<String>(
        'translated_content',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileName,
    sourceLanguage,
    targetLanguage,
    status,
    originalContent,
    translatedContent,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'translation_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<TranslationHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('source_language')) {
      context.handle(
        _sourceLanguageMeta,
        sourceLanguage.isAcceptableOrUnknown(
          data['source_language']!,
          _sourceLanguageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceLanguageMeta);
    }
    if (data.containsKey('target_language')) {
      context.handle(
        _targetLanguageMeta,
        targetLanguage.isAcceptableOrUnknown(
          data['target_language']!,
          _targetLanguageMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetLanguageMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('original_content')) {
      context.handle(
        _originalContentMeta,
        originalContent.isAcceptableOrUnknown(
          data['original_content']!,
          _originalContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalContentMeta);
    }
    if (data.containsKey('translated_content')) {
      context.handle(
        _translatedContentMeta,
        translatedContent.isAcceptableOrUnknown(
          data['translated_content']!,
          _translatedContentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_translatedContentMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TranslationHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TranslationHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      sourceLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_language'],
      )!,
      targetLanguage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_language'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      originalContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_content'],
      )!,
      translatedContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translated_content'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TranslationHistoryTable createAlias(String alias) {
    return $TranslationHistoryTable(attachedDatabase, alias);
  }
}

class TranslationHistoryData extends DataClass
    implements Insertable<TranslationHistoryData> {
  final int id;
  final String fileName;
  final String sourceLanguage;
  final String targetLanguage;
  final String status;
  final String originalContent;
  final String translatedContent;
  final DateTime createdAt;
  const TranslationHistoryData({
    required this.id,
    required this.fileName,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.status,
    required this.originalContent,
    required this.translatedContent,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_name'] = Variable<String>(fileName);
    map['source_language'] = Variable<String>(sourceLanguage);
    map['target_language'] = Variable<String>(targetLanguage);
    map['status'] = Variable<String>(status);
    map['original_content'] = Variable<String>(originalContent);
    map['translated_content'] = Variable<String>(translatedContent);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TranslationHistoryCompanion toCompanion(bool nullToAbsent) {
    return TranslationHistoryCompanion(
      id: Value(id),
      fileName: Value(fileName),
      sourceLanguage: Value(sourceLanguage),
      targetLanguage: Value(targetLanguage),
      status: Value(status),
      originalContent: Value(originalContent),
      translatedContent: Value(translatedContent),
      createdAt: Value(createdAt),
    );
  }

  factory TranslationHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TranslationHistoryData(
      id: serializer.fromJson<int>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sourceLanguage: serializer.fromJson<String>(json['sourceLanguage']),
      targetLanguage: serializer.fromJson<String>(json['targetLanguage']),
      status: serializer.fromJson<String>(json['status']),
      originalContent: serializer.fromJson<String>(json['originalContent']),
      translatedContent: serializer.fromJson<String>(json['translatedContent']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileName': serializer.toJson<String>(fileName),
      'sourceLanguage': serializer.toJson<String>(sourceLanguage),
      'targetLanguage': serializer.toJson<String>(targetLanguage),
      'status': serializer.toJson<String>(status),
      'originalContent': serializer.toJson<String>(originalContent),
      'translatedContent': serializer.toJson<String>(translatedContent),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TranslationHistoryData copyWith({
    int? id,
    String? fileName,
    String? sourceLanguage,
    String? targetLanguage,
    String? status,
    String? originalContent,
    String? translatedContent,
    DateTime? createdAt,
  }) => TranslationHistoryData(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    sourceLanguage: sourceLanguage ?? this.sourceLanguage,
    targetLanguage: targetLanguage ?? this.targetLanguage,
    status: status ?? this.status,
    originalContent: originalContent ?? this.originalContent,
    translatedContent: translatedContent ?? this.translatedContent,
    createdAt: createdAt ?? this.createdAt,
  );
  TranslationHistoryData copyWithCompanion(TranslationHistoryCompanion data) {
    return TranslationHistoryData(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sourceLanguage: data.sourceLanguage.present
          ? data.sourceLanguage.value
          : this.sourceLanguage,
      targetLanguage: data.targetLanguage.present
          ? data.targetLanguage.value
          : this.targetLanguage,
      status: data.status.present ? data.status.value : this.status,
      originalContent: data.originalContent.present
          ? data.originalContent.value
          : this.originalContent,
      translatedContent: data.translatedContent.present
          ? data.translatedContent.value
          : this.translatedContent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TranslationHistoryData(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('sourceLanguage: $sourceLanguage, ')
          ..write('targetLanguage: $targetLanguage, ')
          ..write('status: $status, ')
          ..write('originalContent: $originalContent, ')
          ..write('translatedContent: $translatedContent, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileName,
    sourceLanguage,
    targetLanguage,
    status,
    originalContent,
    translatedContent,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TranslationHistoryData &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.sourceLanguage == this.sourceLanguage &&
          other.targetLanguage == this.targetLanguage &&
          other.status == this.status &&
          other.originalContent == this.originalContent &&
          other.translatedContent == this.translatedContent &&
          other.createdAt == this.createdAt);
}

class TranslationHistoryCompanion
    extends UpdateCompanion<TranslationHistoryData> {
  final Value<int> id;
  final Value<String> fileName;
  final Value<String> sourceLanguage;
  final Value<String> targetLanguage;
  final Value<String> status;
  final Value<String> originalContent;
  final Value<String> translatedContent;
  final Value<DateTime> createdAt;
  const TranslationHistoryCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sourceLanguage = const Value.absent(),
    this.targetLanguage = const Value.absent(),
    this.status = const Value.absent(),
    this.originalContent = const Value.absent(),
    this.translatedContent = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TranslationHistoryCompanion.insert({
    this.id = const Value.absent(),
    required String fileName,
    required String sourceLanguage,
    required String targetLanguage,
    required String status,
    required String originalContent,
    required String translatedContent,
    required DateTime createdAt,
  }) : fileName = Value(fileName),
       sourceLanguage = Value(sourceLanguage),
       targetLanguage = Value(targetLanguage),
       status = Value(status),
       originalContent = Value(originalContent),
       translatedContent = Value(translatedContent),
       createdAt = Value(createdAt);
  static Insertable<TranslationHistoryData> custom({
    Expression<int>? id,
    Expression<String>? fileName,
    Expression<String>? sourceLanguage,
    Expression<String>? targetLanguage,
    Expression<String>? status,
    Expression<String>? originalContent,
    Expression<String>? translatedContent,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (sourceLanguage != null) 'source_language': sourceLanguage,
      if (targetLanguage != null) 'target_language': targetLanguage,
      if (status != null) 'status': status,
      if (originalContent != null) 'original_content': originalContent,
      if (translatedContent != null) 'translated_content': translatedContent,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TranslationHistoryCompanion copyWith({
    Value<int>? id,
    Value<String>? fileName,
    Value<String>? sourceLanguage,
    Value<String>? targetLanguage,
    Value<String>? status,
    Value<String>? originalContent,
    Value<String>? translatedContent,
    Value<DateTime>? createdAt,
  }) {
    return TranslationHistoryCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      status: status ?? this.status,
      originalContent: originalContent ?? this.originalContent,
      translatedContent: translatedContent ?? this.translatedContent,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sourceLanguage.present) {
      map['source_language'] = Variable<String>(sourceLanguage.value);
    }
    if (targetLanguage.present) {
      map['target_language'] = Variable<String>(targetLanguage.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (originalContent.present) {
      map['original_content'] = Variable<String>(originalContent.value);
    }
    if (translatedContent.present) {
      map['translated_content'] = Variable<String>(translatedContent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TranslationHistoryCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('sourceLanguage: $sourceLanguage, ')
          ..write('targetLanguage: $targetLanguage, ')
          ..write('status: $status, ')
          ..write('originalContent: $originalContent, ')
          ..write('translatedContent: $translatedContent, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $GlossaryEntryTable glossaryEntry = $GlossaryEntryTable(this);
  late final $SystemPromptTable systemPrompt = $SystemPromptTable(this);
  late final $TranslationHistoryTable translationHistory =
      $TranslationHistoryTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    glossaryEntry,
    systemPrompt,
    translationHistory,
  ];
}

typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$GlossaryEntryTableCreateCompanionBuilder =
    GlossaryEntryCompanion Function({
      Value<int> id,
      required String source,
      required String target,
      Value<bool> caseSensitive,
    });
typedef $$GlossaryEntryTableUpdateCompanionBuilder =
    GlossaryEntryCompanion Function({
      Value<int> id,
      Value<String> source,
      Value<String> target,
      Value<bool> caseSensitive,
    });

class $$GlossaryEntryTableFilterComposer
    extends Composer<_$AppDatabase, $GlossaryEntryTable> {
  $$GlossaryEntryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get caseSensitive => $composableBuilder(
    column: $table.caseSensitive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GlossaryEntryTableOrderingComposer
    extends Composer<_$AppDatabase, $GlossaryEntryTable> {
  $$GlossaryEntryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get target => $composableBuilder(
    column: $table.target,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get caseSensitive => $composableBuilder(
    column: $table.caseSensitive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GlossaryEntryTableAnnotationComposer
    extends Composer<_$AppDatabase, $GlossaryEntryTable> {
  $$GlossaryEntryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<bool> get caseSensitive => $composableBuilder(
    column: $table.caseSensitive,
    builder: (column) => column,
  );
}

class $$GlossaryEntryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GlossaryEntryTable,
          GlossaryEntryData,
          $$GlossaryEntryTableFilterComposer,
          $$GlossaryEntryTableOrderingComposer,
          $$GlossaryEntryTableAnnotationComposer,
          $$GlossaryEntryTableCreateCompanionBuilder,
          $$GlossaryEntryTableUpdateCompanionBuilder,
          (
            GlossaryEntryData,
            BaseReferences<
              _$AppDatabase,
              $GlossaryEntryTable,
              GlossaryEntryData
            >,
          ),
          GlossaryEntryData,
          PrefetchHooks Function()
        > {
  $$GlossaryEntryTableTableManager(_$AppDatabase db, $GlossaryEntryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GlossaryEntryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GlossaryEntryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GlossaryEntryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> target = const Value.absent(),
                Value<bool> caseSensitive = const Value.absent(),
              }) => GlossaryEntryCompanion(
                id: id,
                source: source,
                target: target,
                caseSensitive: caseSensitive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                required String target,
                Value<bool> caseSensitive = const Value.absent(),
              }) => GlossaryEntryCompanion.insert(
                id: id,
                source: source,
                target: target,
                caseSensitive: caseSensitive,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GlossaryEntryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GlossaryEntryTable,
      GlossaryEntryData,
      $$GlossaryEntryTableFilterComposer,
      $$GlossaryEntryTableOrderingComposer,
      $$GlossaryEntryTableAnnotationComposer,
      $$GlossaryEntryTableCreateCompanionBuilder,
      $$GlossaryEntryTableUpdateCompanionBuilder,
      (
        GlossaryEntryData,
        BaseReferences<_$AppDatabase, $GlossaryEntryTable, GlossaryEntryData>,
      ),
      GlossaryEntryData,
      PrefetchHooks Function()
    >;
typedef $$SystemPromptTableCreateCompanionBuilder =
    SystemPromptCompanion Function({
      Value<int> id,
      required String name,
      required String content,
      Value<bool> isActive,
    });
typedef $$SystemPromptTableUpdateCompanionBuilder =
    SystemPromptCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> content,
      Value<bool> isActive,
    });

class $$SystemPromptTableFilterComposer
    extends Composer<_$AppDatabase, $SystemPromptTable> {
  $$SystemPromptTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SystemPromptTableOrderingComposer
    extends Composer<_$AppDatabase, $SystemPromptTable> {
  $$SystemPromptTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SystemPromptTableAnnotationComposer
    extends Composer<_$AppDatabase, $SystemPromptTable> {
  $$SystemPromptTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$SystemPromptTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SystemPromptTable,
          SystemPromptData,
          $$SystemPromptTableFilterComposer,
          $$SystemPromptTableOrderingComposer,
          $$SystemPromptTableAnnotationComposer,
          $$SystemPromptTableCreateCompanionBuilder,
          $$SystemPromptTableUpdateCompanionBuilder,
          (
            SystemPromptData,
            BaseReferences<_$AppDatabase, $SystemPromptTable, SystemPromptData>,
          ),
          SystemPromptData,
          PrefetchHooks Function()
        > {
  $$SystemPromptTableTableManager(_$AppDatabase db, $SystemPromptTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SystemPromptTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SystemPromptTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SystemPromptTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => SystemPromptCompanion(
                id: id,
                name: name,
                content: content,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String content,
                Value<bool> isActive = const Value.absent(),
              }) => SystemPromptCompanion.insert(
                id: id,
                name: name,
                content: content,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SystemPromptTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SystemPromptTable,
      SystemPromptData,
      $$SystemPromptTableFilterComposer,
      $$SystemPromptTableOrderingComposer,
      $$SystemPromptTableAnnotationComposer,
      $$SystemPromptTableCreateCompanionBuilder,
      $$SystemPromptTableUpdateCompanionBuilder,
      (
        SystemPromptData,
        BaseReferences<_$AppDatabase, $SystemPromptTable, SystemPromptData>,
      ),
      SystemPromptData,
      PrefetchHooks Function()
    >;
typedef $$TranslationHistoryTableCreateCompanionBuilder =
    TranslationHistoryCompanion Function({
      Value<int> id,
      required String fileName,
      required String sourceLanguage,
      required String targetLanguage,
      required String status,
      required String originalContent,
      required String translatedContent,
      required DateTime createdAt,
    });
typedef $$TranslationHistoryTableUpdateCompanionBuilder =
    TranslationHistoryCompanion Function({
      Value<int> id,
      Value<String> fileName,
      Value<String> sourceLanguage,
      Value<String> targetLanguage,
      Value<String> status,
      Value<String> originalContent,
      Value<String> translatedContent,
      Value<DateTime> createdAt,
    });

class $$TranslationHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $TranslationHistoryTable> {
  $$TranslationHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLanguage => $composableBuilder(
    column: $table.sourceLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalContent => $composableBuilder(
    column: $table.originalContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translatedContent => $composableBuilder(
    column: $table.translatedContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TranslationHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $TranslationHistoryTable> {
  $$TranslationHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLanguage => $composableBuilder(
    column: $table.sourceLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalContent => $composableBuilder(
    column: $table.originalContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translatedContent => $composableBuilder(
    column: $table.translatedContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TranslationHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $TranslationHistoryTable> {
  $$TranslationHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get sourceLanguage => $composableBuilder(
    column: $table.sourceLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetLanguage => $composableBuilder(
    column: $table.targetLanguage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get originalContent => $composableBuilder(
    column: $table.originalContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get translatedContent => $composableBuilder(
    column: $table.translatedContent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$TranslationHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TranslationHistoryTable,
          TranslationHistoryData,
          $$TranslationHistoryTableFilterComposer,
          $$TranslationHistoryTableOrderingComposer,
          $$TranslationHistoryTableAnnotationComposer,
          $$TranslationHistoryTableCreateCompanionBuilder,
          $$TranslationHistoryTableUpdateCompanionBuilder,
          (
            TranslationHistoryData,
            BaseReferences<
              _$AppDatabase,
              $TranslationHistoryTable,
              TranslationHistoryData
            >,
          ),
          TranslationHistoryData,
          PrefetchHooks Function()
        > {
  $$TranslationHistoryTableTableManager(
    _$AppDatabase db,
    $TranslationHistoryTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TranslationHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TranslationHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TranslationHistoryTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> sourceLanguage = const Value.absent(),
                Value<String> targetLanguage = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> originalContent = const Value.absent(),
                Value<String> translatedContent = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TranslationHistoryCompanion(
                id: id,
                fileName: fileName,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                status: status,
                originalContent: originalContent,
                translatedContent: translatedContent,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fileName,
                required String sourceLanguage,
                required String targetLanguage,
                required String status,
                required String originalContent,
                required String translatedContent,
                required DateTime createdAt,
              }) => TranslationHistoryCompanion.insert(
                id: id,
                fileName: fileName,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                status: status,
                originalContent: originalContent,
                translatedContent: translatedContent,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TranslationHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TranslationHistoryTable,
      TranslationHistoryData,
      $$TranslationHistoryTableFilterComposer,
      $$TranslationHistoryTableOrderingComposer,
      $$TranslationHistoryTableAnnotationComposer,
      $$TranslationHistoryTableCreateCompanionBuilder,
      $$TranslationHistoryTableUpdateCompanionBuilder,
      (
        TranslationHistoryData,
        BaseReferences<
          _$AppDatabase,
          $TranslationHistoryTable,
          TranslationHistoryData
        >,
      ),
      TranslationHistoryData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$GlossaryEntryTableTableManager get glossaryEntry =>
      $$GlossaryEntryTableTableManager(_db, _db.glossaryEntry);
  $$SystemPromptTableTableManager get systemPrompt =>
      $$SystemPromptTableTableManager(_db, _db.systemPrompt);
  $$TranslationHistoryTableTableManager get translationHistory =>
      $$TranslationHistoryTableTableManager(_db, _db.translationHistory);
}
