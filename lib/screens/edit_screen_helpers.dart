import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/ingredient.dart';
import '../models/instruction.dart';

abstract class ListItem {
  final String id;
  ListItem() : id = const Uuid().v4();
  Key get key => ValueKey(id);
}

class HeaderItem extends ListItem {
  String name;
  HeaderItem(this.name);
}

class IngredientItem extends ListItem {
  String name;
  String amount;
  IngredientItem({required this.name, required this.amount});
}

class InstructionItem extends ListItem {
  String description;
  String? photoPath;
  InstructionItem({required this.description, this.photoPath});
}
