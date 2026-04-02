// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_hub.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 0;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Course(
      code: fields[0] as String,
      name: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.code)
      ..writeByte(1)
      ..write(obj.name);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ResourceItemAdapter extends TypeAdapter<ResourceItem> {
  @override
  final int typeId = 1;

  @override
  ResourceItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ResourceItem(
      id: fields[0] as String,
      year: fields[1] as int,
      semester: fields[2] as String,
      instructorName: fields[3] as String?,
      quizNumber: fields[4] as int?,
      isSolved: fields[5] as bool?,
      filePath: fields[6] as String,
      uploadedAt: fields[7] as DateTime,
      localFilePath: fields[8] as String?,
      type: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ResourceItem obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.year)
      ..writeByte(2)
      ..write(obj.semester)
      ..writeByte(3)
      ..write(obj.instructorName)
      ..writeByte(4)
      ..write(obj.quizNumber)
      ..writeByte(5)
      ..write(obj.isSolved)
      ..writeByte(6)
      ..write(obj.filePath)
      ..writeByte(7)
      ..write(obj.uploadedAt)
      ..writeByte(8)
      ..write(obj.localFilePath)
      ..writeByte(9)
      ..write(obj.type);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
