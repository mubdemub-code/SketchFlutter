import 'package:flutter/material.dart';

import '../../../models/logic_block.dart';

class ShowSnackbarBlock {
  static void execute(LogicBlock block, BuildContext context) {
    final message = block.getStringParameter('message') ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}