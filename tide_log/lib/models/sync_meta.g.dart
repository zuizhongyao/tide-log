// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_meta.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetSyncMetaCollection on Isar {
  IsarCollection<SyncMeta> get syncMetas => this.collection();
}

const SyncMetaSchema = CollectionSchema(
  name: r'SyncMeta',
  id: 7779218425528899915,
  properties: {
    r'lastLocalChangeAt': PropertySchema(
      id: 0,
      name: r'lastLocalChangeAt',
      type: IsarType.dateTime,
    ),
    r'lastRemoteStamp': PropertySchema(
      id: 1,
      name: r'lastRemoteStamp',
      type: IsarType.string,
    ),
    r'lastSyncedAt': PropertySchema(
      id: 2,
      name: r'lastSyncedAt',
      type: IsarType.dateTime,
    ),
  },

  estimateSize: _syncMetaEstimateSize,
  serialize: _syncMetaSerialize,
  deserialize: _syncMetaDeserialize,
  deserializeProp: _syncMetaDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},

  getId: _syncMetaGetId,
  getLinks: _syncMetaGetLinks,
  attach: _syncMetaAttach,
  version: '3.4.1',
);

int _syncMetaEstimateSize(
  SyncMeta object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.lastRemoteStamp;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _syncMetaSerialize(
  SyncMeta object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.lastLocalChangeAt);
  writer.writeString(offsets[1], object.lastRemoteStamp);
  writer.writeDateTime(offsets[2], object.lastSyncedAt);
}

SyncMeta _syncMetaDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SyncMeta();
  object.id = id;
  object.lastLocalChangeAt = reader.readDateTimeOrNull(offsets[0]);
  object.lastRemoteStamp = reader.readStringOrNull(offsets[1]);
  object.lastSyncedAt = reader.readDateTimeOrNull(offsets[2]);
  return object;
}

P _syncMetaDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readDateTimeOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _syncMetaGetId(SyncMeta object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _syncMetaGetLinks(SyncMeta object) {
  return [];
}

void _syncMetaAttach(IsarCollection<dynamic> col, Id id, SyncMeta object) {
  object.id = id;
}

extension SyncMetaQueryWhereSort on QueryBuilder<SyncMeta, SyncMeta, QWhere> {
  QueryBuilder<SyncMeta, SyncMeta, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SyncMetaQueryWhere on QueryBuilder<SyncMeta, SyncMeta, QWhereClause> {
  QueryBuilder<SyncMeta, SyncMeta, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SyncMetaQueryFilter
    on QueryBuilder<SyncMeta, SyncMeta, QFilterCondition> {
  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastLocalChangeAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastLocalChangeAt'),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastLocalChangeAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastLocalChangeAt'),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastLocalChangeAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastLocalChangeAt', value: value),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastLocalChangeAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastLocalChangeAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastLocalChangeAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastLocalChangeAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastLocalChangeAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastLocalChangeAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastRemoteStamp'),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastRemoteStamp'),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lastRemoteStamp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastRemoteStamp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastRemoteStamp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastRemoteStamp',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'lastRemoteStamp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'lastRemoteStamp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'lastRemoteStamp',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'lastRemoteStamp',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastRemoteStamp', value: ''),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastRemoteStampIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'lastRemoteStamp', value: ''),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition> lastSyncedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastSyncedAt'),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastSyncedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastSyncedAt'),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition> lastSyncedAtEqualTo(
    DateTime? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSyncedAt', value: value),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition>
  lastSyncedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSyncedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition> lastSyncedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSyncedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterFilterCondition> lastSyncedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSyncedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SyncMetaQueryObject
    on QueryBuilder<SyncMeta, SyncMeta, QFilterCondition> {}

extension SyncMetaQueryLinks
    on QueryBuilder<SyncMeta, SyncMeta, QFilterCondition> {}

extension SyncMetaQuerySortBy on QueryBuilder<SyncMeta, SyncMeta, QSortBy> {
  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> sortByLastLocalChangeAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalChangeAt', Sort.asc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> sortByLastLocalChangeAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalChangeAt', Sort.desc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> sortByLastRemoteStamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastRemoteStamp', Sort.asc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> sortByLastRemoteStampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastRemoteStamp', Sort.desc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> sortByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.asc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> sortByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.desc);
    });
  }
}

extension SyncMetaQuerySortThenBy
    on QueryBuilder<SyncMeta, SyncMeta, QSortThenBy> {
  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> thenByLastLocalChangeAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalChangeAt', Sort.asc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> thenByLastLocalChangeAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalChangeAt', Sort.desc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> thenByLastRemoteStamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastRemoteStamp', Sort.asc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> thenByLastRemoteStampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastRemoteStamp', Sort.desc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> thenByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.asc);
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QAfterSortBy> thenByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.desc);
    });
  }
}

extension SyncMetaQueryWhereDistinct
    on QueryBuilder<SyncMeta, SyncMeta, QDistinct> {
  QueryBuilder<SyncMeta, SyncMeta, QDistinct> distinctByLastLocalChangeAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastLocalChangeAt');
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QDistinct> distinctByLastRemoteStamp({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'lastRemoteStamp',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SyncMeta, SyncMeta, QDistinct> distinctByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncedAt');
    });
  }
}

extension SyncMetaQueryProperty
    on QueryBuilder<SyncMeta, SyncMeta, QQueryProperty> {
  QueryBuilder<SyncMeta, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SyncMeta, DateTime?, QQueryOperations>
  lastLocalChangeAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastLocalChangeAt');
    });
  }

  QueryBuilder<SyncMeta, String?, QQueryOperations> lastRemoteStampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastRemoteStamp');
    });
  }

  QueryBuilder<SyncMeta, DateTime?, QQueryOperations> lastSyncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncedAt');
    });
  }
}
