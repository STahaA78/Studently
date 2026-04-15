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
      course: fields[1] as Course,
      type: fields[2] as String,
      year: fields[3] as int,
      semester: fields[4] as String,
      isSolved: fields[5] as bool?,
      midNumber: fields[6] as int?,
      fileUrl: fields[7] as String,
      uploadedAt: fields[8] as DateTime,
      uploadedBy: fields[9] as String,
      approved: fields[10] as bool,
      localFilePath: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ResourceItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.course)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.year)
      ..writeByte(4)
      ..write(obj.semester)
      ..writeByte(5)
      ..write(obj.isSolved)
      ..writeByte(6)
      ..write(obj.midNumber)
      ..writeByte(7)
      ..write(obj.fileUrl)
      ..writeByte(8)
      ..write(obj.uploadedAt)
      ..writeByte(9)
      ..write(obj.uploadedBy)
      ..writeByte(10)
      ..write(obj.approved)
      ..writeByte(11)
      ..write(obj.localFilePath);
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
