import 'package:logger/logger.dart';

// global instance 
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0, // Number of method calls to display
    errorMethodCount: 8, // Number of method calls if stacktrace is provided
    lineLength: 120, // Width of the output
    colors: true, // Colorful log messages
    printEmojis: true, // Print an emoji for each log message
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);