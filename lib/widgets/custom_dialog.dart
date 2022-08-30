import 'package:flutter/material.dart';

class CustomDialog extends StatefulWidget {
  const CustomDialog({
    Key? key,
    required Widget title,
    required List<Widget> content,
    required List<Widget> actions,
  })  : _title = title,
        _content = content,
        _actions = actions,
        super(key: key);

  final Widget _title;
  final List<Widget> _content;
  final List<Widget> _actions;

  @override
  State<CustomDialog> createState() => _CustomDialogState();
}

class _CustomDialogState extends State<CustomDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.brown,
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
      contentTextStyle: const TextStyle(color: Colors.white),
      title: widget._title,
      content: SingleChildScrollView(
        child: ListBody(children: widget._content),
      ),
      actions: widget._actions,
    );
  }
}
