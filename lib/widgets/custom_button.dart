import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: color != null
            ? ElevatedButton.styleFrom(backgroundColor: color)
            : null, // Relies on the main AppStyle.theme if color is null
        child: Text(text),
      ),
    );
  }
}
