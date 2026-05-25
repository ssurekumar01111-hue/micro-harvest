// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PendingActionAdapter extends TypeAdapter<PendingAction> {
  @override
  final int typeId = 0;

  @override
  PendingAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingAction(
      actionType: fields[0] as String,
      data: (fields[1] as Map).cast<String, dynamic>(),
      createdAt: fields[2] as DateTime,
      retries: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, PendingAction obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.actionType)
      ..writeByte(1)
      ..write(obj.data)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.retries);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PendingUploadAdapter extends TypeAdapter<PendingUpload> {
  @override
  final int typeId = 1;

  @override
  PendingUpload read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingUpload(
      filePath: fields[0] as String,
      storagePath: fields[1] as String,
      hash: fields[2] as String,
      createdAt: fields[3] as DateTime,
      isCompleted: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PendingUpload obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.filePath)
      ..writeByte(1)
      ..write(obj.storagePath)
      ..writeByte(2)
      ..write(obj.hash)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingUploadAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
